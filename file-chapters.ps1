<#
.SYNOPSIS
Extracts chapter timestamps and names from an MKV file using mkvinfo.

.DESCRIPTION
This script requires MKVToolNix to be installed and mkvinfo.exe to be accessible
via the system's PATH or by providing a direct path to the executable.
It parses the output of mkvinfo to list all chapters found in the specified MKV file.

.PARAMETER FilePath
The full path to the MKV file.

.PARAMETER MkvInfoPath
(Optional) The full path to the mkvinfo.exe executable.
If not provided, the script assumes 'mkvinfo' is in the system PATH.

.EXAMPLE
.\Get-MkvChapters_MkvInfo.ps1 -FilePath "C:\MyVideos\MyMovie.mkv"

.EXAMPLE
.\Get-MkvChapters_MkvInfo.ps1 -FilePath ".\Another Movie.mkv" -MkvInfoPath "C:\Program Files\MKVToolNix\mkvinfo.exe"

.NOTES
Requires MKVToolNix. Download from https://mkvtoolnix.download/
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FilePath,

    [Parameter(Mandatory = $false)]
    [string]$MkvInfoPath = "mkvinfo" # Default assumption: mkvinfo is in PATH
)

# Verify the MKV file exists
if (-not (Test-Path $FilePath -PathType Leaf)) {
    Write-Error "File not found: '$FilePath'"
    return
}

# Check if mkvinfo can be found
$mkvinfoExe = Get-Command $MkvInfoPath -ErrorAction SilentlyContinue
if (-not $mkvinfoExe) {
    Write-Error "Cannot find '$MkvInfoPath'. Make sure MKVToolNix is installed and '$MkvInfoPath' is correct (either in PATH or specified via -MkvInfoPath parameter)."
    return
}

Write-Verbose "Using mkvinfo at: $($mkvinfoExe.Source)"
Write-Host "Analyzing '$FilePath' with mkvinfo..."

# Run mkvinfo and capture output
try {
    $mkvinfoOutput = & $MkvInfoPath $FilePath 2>&1 # Capture stdout and stderr
}
catch {
    Write-Error "Error running mkvinfo: $_"
    return
}

# Check if mkvinfo reported an error (e.g., file invalid)
if ($LASTEXITCODE -ne 0 -or $mkvinfoOutput -match "Error:") {
    Write-Error "mkvinfo encountered an error processing the file:`n$($mkvinfoOutput -join "`n")"
    return
}

# Parse the output
$chapters = @()
$currentTimestamp = $null

# Split output into lines for processing
$mkvinfoOutput -split '\r?\n' | ForEach-Object {
    $line = $_

    # Match the chapter start time line
    # Example: | + Chapter time start: 00:01:35.568000000
    if ($line -match 'Chapter time start:\s*([\d:.]+)') {
        # Store the timestamp (potentially with nanoseconds, usually not needed for display)
        $currentTimestamp = $Matches[1]
    }
    # Match the chapter string line *after* a timestamp was found
    # Example: |  + Chapter string: Chapter 02
    elseif (($line -match 'Chapter string:\s*(.+)') -and ($null -ne $currentTimestamp)) {
        $chapterName = $Matches[1].Trim()

        # Add the found chapter to our list
        $chapters += [PSCustomObject]@{
            Timestamp = $currentTimestamp
            Name      = $chapterName
        }
        # Reset timestamp to wait for the next 'Chapter time start'
        $currentTimestamp = $null
    }
}

# Display results
if ($chapters.Count -eq 0) {
    Write-Warning "No chapter information found in the mkvinfo output for '$FilePath'."
}
else {
    Write-Host "`nChapters found:"
    $chapters | Format-Table -AutoSize
}
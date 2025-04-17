<#
.SYNOPSIS
Extracts chapter timestamps and names from all MKV files in a directory (recursively) using mkvinfo.

.DESCRIPTION
This script requires MKVToolNix to be installed and mkvinfo.exe to be accessible
via the system's PATH or by providing a direct path to the executable.
It parses the output of mkvinfo to list all chapters found in the MKV files.

.PARAMETER DirectoryPath
The directory to search for MKV files.

.PARAMETER MkvInfoPath
(Optional) The full path to the mkvinfo.exe executable.
If not provided, the script assumes 'mkvinfo' is in the system PATH.

.EXAMPLE
.\Get-MkvChapters_MkvInfo.ps1 -DirectoryPath "C:\MyVideos"

.EXAMPLE
.\Get-MkvChapters_MkvInfo.ps1 -DirectoryPath ".\Movies" -MkvInfoPath "C:\Program Files\MKVToolNix\mkvinfo.exe"

.NOTES
Requires MKVToolNix. Download from https://mkvtoolnix.download/
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DirectoryPath,

    [Parameter(Mandatory = $false)]
    [string]$MkvInfoPath = "mkvinfo" # Default assumption: mkvinfo is in PATH
)

# Verify the directory exists
if (-not (Test-Path $DirectoryPath -PathType Container)) {
    Write-Error "Directory not found: '$DirectoryPath'"
    return
}

# Check if mkvinfo can be found
$mkvinfoExe = Get-Command $MkvInfoPath -ErrorAction SilentlyContinue
if (-not $mkvinfoExe) {
    Write-Error "Cannot find '$MkvInfoPath'. Make sure MKVToolNix is installed and '$MkvInfoPath' is correct (either in PATH or specified via -MkvInfoPath parameter)."
    return
}

Write-Verbose "Using mkvinfo at: $($mkvinfoExe.Source)"
Write-Host "Searching for MKV files in '$DirectoryPath'..."

# Get all MKV files in the directory and subdirectories
$mkvFiles = Get-ChildItem -Path $DirectoryPath -Recurse -Filter "*.mkv"
if ($mkvFiles.Count -eq 0) {
    Write-Warning "No MKV files found in '$DirectoryPath'."
    return
}

# Process each MKV file
foreach ($file in $mkvFiles) {
    Write-Host "`nAnalyzing '$($file.FullName)' with mkvinfo..."

    # Run mkvinfo and capture output
    try {
        $mkvinfoOutput = & $MkvInfoPath $file.FullName 2>&1 # Capture stdout and stderr
    }
    catch {
        Write-Error "Error running mkvinfo on '$($file.FullName)': $_"
        continue
    }

    # Check if mkvinfo reported an error (e.g., file invalid)
    if ($LASTEXITCODE -ne 0 -or $mkvinfoOutput -match "Error:") {
        Write-Error "mkvinfo encountered an error processing the file:`n$($mkvinfoOutput -join "`n")"
        continue
    }

    # Parse the output
    $chapters = @()
    $currentTimestamp = $null

    # Split output into lines for processing
    $mkvinfoOutput -split '\r?\n' | ForEach-Object {
        $line = $_

        # Match the chapter start time line
        if ($line -match 'Chapter time start:\s*([\d:.]+)') {
            $currentTimestamp = $Matches[1]
        }
        # Match the chapter string line *after* a timestamp was found
        elseif (($line -match 'Chapter string:\s*(.+)') -and ($null -ne $currentTimestamp)) {
            $chapterName = $Matches[1].Trim()

            # Add the found chapter to our list
            $chapters += [PSCustomObject]@{
                Timestamp = $currentTimestamp
                Name      = $chapterName
            }
            $currentTimestamp = $null
        }
    }

    # Display results for the current file
    if ($chapters.Count -eq 0) {
        Write-Warning "No chapter information found in the mkvinfo output for '$($file.FullName)'."
    }
    else {
        Write-Host "`nChapters found in '$($file.FullName)':"
        $chapters | Format-Table -AutoSize
    }
}
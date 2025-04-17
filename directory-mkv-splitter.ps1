<#
.SYNOPSIS
Finds MKV files with multiple chapters in a directory (recursively) and splits them
into separate files per chapter using MKVToolNix.

.DESCRIPTION
This script requires MKVToolNix to be installed. It uses mkvinfo.exe to identify
files with more than one chapter and then uses mkvmerge.exe to perform the splitting.
Both executables need to be accessible via the system's PATH or by providing direct
paths using the parameters.

The split files will be saved in the same directory as the original file, with names
like "OriginalName-chapter-01.mkv", "OriginalName-chapter-02.mkv", etc.

.PARAMETER DirectoryPath
The directory to search for MKV files. The search is recursive.

.PARAMETER MkvInfoPath
(Optional) The full path to the mkvinfo.exe executable.
If not provided, the script assumes 'mkvinfo' is in the system PATH.

.PARAMETER MkvMergePath
(Optional) The full path to the mkvmerge.exe executable.
If not provided, the script assumes 'mkvmerge' is in the system PATH.

.EXAMPLE
.\Split-MkvChapters.ps1 -DirectoryPath "C:\MyVideos"

.EXAMPLE
.\Split-MkvChapters.ps1 -DirectoryPath "D:\MoviesToProcess" -MkvInfoPath "C:\Program Files\MKVToolNix\mkvinfo.exe" -MkvMergePath "C:\Program Files\MKVToolNix\mkvmerge.exe"

.NOTES
Requires MKVToolNix. Download from https://mkvtoolnix.download/
Original files are NOT deleted or modified. New files are created for the split chapters.
Ensure you have enough disk space for the new files.
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DirectoryPath,

    [Parameter(Mandatory = $false)]
    [string]$MkvInfoPath = "mkvinfo", # Default assumption: mkvinfo is in PATH

    [Parameter(Mandatory = $false)]
    [string]$MkvMergePath = "mkvmerge" # Default assumption: mkvmerge is in PATH
)

# Verify the directory exists
if (-not (Test-Path $DirectoryPath -PathType Container)) {
    Write-Error "Directory not found: '$DirectoryPath'"
    return
}

# --- Verify Tools ---
$mkvinfoExe = Get-Command $MkvInfoPath -ErrorAction SilentlyContinue
if (-not $mkvinfoExe) {
    Write-Error "Cannot find '$MkvInfoPath'. Make sure MKVToolNix is installed and '$MkvInfoPath' is correct (either in PATH or specified via -MkvInfoPath parameter)."
    return
}
Write-Verbose "Using mkvinfo at: $($mkvinfoExe.Source)"

$mkvmergeExe = Get-Command $MkvMergePath -ErrorAction SilentlyContinue
if (-not $mkvmergeExe) {
    Write-Error "Cannot find '$MkvMergePath'. Make sure MKVToolNix is installed and '$MkvMergePath' is correct (either in PATH or specified via -MkvMergePath parameter)."
    return
}
Write-Verbose "Using mkvmerge at: $($mkvmergeExe.Source)"
# --- End Verify Tools ---

Write-Host "Searching for MKV files in '$DirectoryPath'..."

# Get all MKV files in the directory and subdirectories
$mkvFiles = Get-ChildItem -Path $DirectoryPath -Recurse -Filter "*.mkv"
if ($mkvFiles.Count -eq 0) {
    Write-Warning "No MKV files found in '$DirectoryPath'."
    return
}

# Process each MKV file
foreach ($file in $mkvFiles) {
    Write-Host "`n--- Processing '$($file.FullName)' ---"

    # === Step 1: Analyze chapters using mkvinfo ===
    Write-Verbose "Running mkvinfo..."
    $chapters = @() # Reset chapters for each file
    try {
        # Run mkvinfo and capture output
        $mkvinfoOutput = & $MkvInfoPath $file.FullName 2>&1 # Capture stdout and stderr

        # Check if mkvinfo reported an error (e.g., file invalid)
        if ($LASTEXITCODE -ne 0 -or $mkvinfoOutput -match "Error:") {
             Write-Warning "mkvinfo encountered an error or issue processing '$($file.Name)':`n$($mkvinfoOutput -join "`n")"
             continue # Skip to the next file
        }

        # Parse the output for chapters
        $currentTimestamp = $null
        $mkvinfoOutput -split '\r?\n' | ForEach-Object {
            $line = $_
            if ($line -match 'Chapter time start:\s*([\d:.]+)') {
                $currentTimestamp = $Matches[1]
            }
            elseif (($line -match 'Chapter string:\s*(.+)') -and ($null -ne $currentTimestamp)) {
                $chapters += [PSCustomObject]@{
                    Timestamp = $currentTimestamp
                    Name      = $Matches[1].Trim()
                }
                $currentTimestamp = $null # Reset for the next potential chapter pair
            }
         }
    }
    catch {
        Write-Error "Error running mkvinfo on '$($file.FullName)': $_"
        continue # Skip to the next file
    }

    # === Step 2: Decide whether to split based on chapter count ===
    $chapterCount = $chapters.Count
    Write-Host "Found $chapterCount chapter(s) in '$($file.Name)'."

    if ($chapterCount -le 1) {
        Write-Host "Skipping splitting as file has 0 or 1 chapter."
        continue # Skip to the next file
    }

    # === Step 3: Split the file using mkvmerge ===
    Write-Host "File has multiple chapters. Proceeding with split..."

    # Construct the output filename pattern
    $baseName = $file.BaseName # Name without extension
    $extension = $file.Extension # Extension (e.g., ".mkv")
    # Output pattern for mkvmerge: places files in the same directory as the original
    # %02d ensures chapter numbers are like 01, 02, 03...
    $outputPattern = Join-Path -Path $file.DirectoryName -ChildPath "$($baseName)-chapter-%02d$($extension)"

    Write-Verbose "Output pattern: $outputPattern"

    # Prepare arguments for mkvmerge
    $mkvmergeArgs = @(
        "-o", # Output file specifier
        $outputPattern,
        "--split", # Split mode activation
        "chapters:all", # Split based on all chapter start times
        $file.FullName # The input file
    )

    Write-Host "Running mkvmerge to split '$($file.Name)'..."
    Write-Verbose "Executing: $MkvMergePath $mkvmergeArgs"

    try {
        # Execute mkvmerge
        $mkvmergeOutput = & $MkvMergePath $mkvmergeArgs 2>&1 # Capture stdout and stderr

        # Check exit code and output for errors
        if ($LASTEXITCODE -ne 0 -or $mkvmergeOutput -match "Error:") {
            Write-Error "mkvmerge failed to split '$($file.FullName)'. Exit code: $LASTEXITCODE"
            Write-Error "mkvmerge output:`n$($mkvmergeOutput -join "`n")"
            # Optional: Could attempt cleanup of partially created files here if needed
        } else {
            Write-Host "Successfully split '$($file.Name)' based on chapters."
            Write-Verbose "mkvmerge output:`n$($mkvmergeOutput -join "`n")"
        }
    }
    catch {
        Write-Error "An exception occurred while running mkvmerge on '$($file.FullName)': $_"
    }
}

Write-Host "`n--- Script finished ---"
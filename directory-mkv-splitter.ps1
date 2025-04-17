<#
.SYNOPSIS
Recursively finds MKV files and splits those with multiple chapters into separate files, one per chapter.

.DESCRIPTION
This script searches a specified directory and its subdirectories for MKV files (*.mkv).
For each MKV file found, it uses 'mkvmerge.exe' (from the MKVToolNix suite) to check
if the file contains more than one chapter. If it does, the script splits the MKV
into multiple output files, each containing a single chapter. The original multi-chapter
file is kept intact.

Requires MKVToolNix to be installed and 'mkvmerge.exe' to be accessible in the system PATH.

.PARAMETER InputPath
The starting directory path to search for MKV files recursively.

.PARAMETER MkvMergePath
(Optional) The full path to the 'mkvmerge.exe' executable if it's not in the system PATH.

.EXAMPLE
.\Split-MkvByChapter.ps1 -InputPath "D:\MyRippedDVDs"

Searches D:\MyRippedDVDs and its subfolders for MKV files and splits multi-chapter ones.

.EXAMPLE
.\Split-MkvByChapter.ps1 -InputPath "C:\Users\Me\Videos\Temp" -MkvMergePath "C:\Program Files\MKVToolNix\mkvmerge.exe"

Uses a specific path for mkvmerge.exe while searching the Temp folder.

.NOTES
Author: AI Assistant
Date:   2025-04-16
Requires: MKVToolNix (mkvmerge.exe)
Ensure you have enough disk space, as splitting creates new files.
The original files are NOT deleted. Test on a small sample first!
Output files are named like: OriginalName-chapter##.mkv (e.g., Show_S01E01E02-chapter01.mkv)
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $false)]
    [string]$MkvMergePath = "mkvmerge.exe" # Default assumes it's in PATH
)

# --- Configuration ---
$VerbosePreference = 'Continue' # Show detailed messages

# --- Validate Input Path ---
if (-not (Test-Path -Path $InputPath -PathType Container)) {
    Write-Error "Input path '$InputPath' not found or is not a directory."
    return
}
Write-Verbose "Starting search in directory: $InputPath"

# --- Check for mkvmerge ---
$mkvmerge = Get-Command $MkvMergePath -ErrorAction SilentlyContinue
if (-not $mkvmerge) {
    Write-Error "Could not find '$MkvMergePath'. Make sure MKVToolNix is installed and '$MkvMergePath' is correct or in your system PATH."
    return
}
Write-Verbose "Using mkvmerge found at: $($mkvmerge.Source)"

# --- Find MKV Files Recursively ---
Write-Verbose "Searching for MKV files..."
$mkvFiles = Get-ChildItem -Path $InputPath -Filter *.mkv -Recurse -File

if ($mkvFiles.Count -eq 0) {
    Write-Warning "No MKV files found in '$InputPath' or its subdirectories."
    return
}
Write-Verbose "Found $($mkvFiles.Count) MKV files."

# --- Process Each MKV File ---
foreach ($file in $mkvFiles) {
    Write-Host "`nProcessing file: $($file.FullName)"

    # Get file information, specifically looking for chapters, in JSON format
    $jsonInfo = ""
    try {
        Write-Verbose "Checking chapters for '$($file.Name)'..."
        # Use -J for JSON output, easier to parse
        $jsonInfo = & $MkvMergePath -J $file.FullName | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get info for '$($file.FullName)'. Error: $($_.Exception.Message). Skipping file."
        continue # Skip to the next file
    }

    # Check if chapters exist and count them
    $chapterCount = 0
    if ($jsonInfo.PSObject.Properties.Name -contains 'chapters') {
        $chapterCount = $jsonInfo.chapters.Count
    }

    Write-Verbose "Chapter count: $chapterCount"

    # --- Split if more than one chapter ---
    if ($chapterCount -gt 1) {
        Write-Host "  File has $chapterCount chapters. Splitting..."

        # Construct the output filename pattern
        # Example: "MyVideo.mkv" -> "MyVideo-chapter%02d.mkv" -> MyVideo-chapter01.mkv, MyVideo-chapter02.mkv
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $directory = $file.DirectoryName
        # Use %02d for two-digit chapter numbers with leading zeros
        $outputPattern = Join-Path -Path $directory -ChildPath "$baseName-chapter%02d.mkv"

        # Construct the mkvmerge command for splitting
        $splitArgs = @(
            '-o', "`"$outputPattern`"", # Output pattern (needs quotes if path has spaces)
            '--split', 'chapters:all',
            "`"$($file.FullName)`""    # Input file (needs quotes if path has spaces)
        )

        Write-Verbose "Executing: $MkvMergePath $($splitArgs -join ' ')"

        # Execute the split command
        try {
            # Using Start-Process and Wait might be more robust for long operations
            $process = Start-Process -FilePath $MkvMergePath -ArgumentList $splitArgs -Wait -NoNewWindow -PassThru
            if ($process.ExitCode -ne 0) {
                throw "mkvmerge exited with code $($process.ExitCode)"
            }
            Write-Host "  Successfully split '$($file.Name)' based on chapters."
            Write-Verbose "  Output files should be in: $directory"
        }
        catch {
            Write-Warning "Failed to split '$($file.FullName)'. Error: $($_.Exception.Message)"
            Write-Warning "  mkvmerge command might have failed. Check MKVToolNix GUI or command line output for details if possible."
        }

    }
    else {
        Write-Host "  Skipping file (0 or 1 chapter found)."
    }
}

Write-Host "`nScript finished."
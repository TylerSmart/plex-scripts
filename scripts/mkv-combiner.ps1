<#
.SYNOPSIS
Interactively prompts the user to enter the full paths of MKV files one by one,
then combines them in the order entered into a single output file using MKVToolNix.

.DESCRIPTION
This script requires MKVToolNix to be installed and mkvmerge.exe to be accessible.
It repeatedly prompts the user to enter the full path of an MKV file. Entering an
empty path signals the end of input. The script requires at least two files to be
entered. The user must specify the output file path using the -OutputPath parameter.
Finally, mkvmerge.exe is used to append the entered files in the specified order.

.PARAMETER OutputPath
(Mandatory) The full path for the combined output MKV file.

.PARAMETER MkvMergePath
(Optional) The full path to the mkvmerge.exe executable.
If not provided, the script assumes 'mkvmerge' is in the system PATH.

.EXAMPLE
.\Combine-MkvFiles-Interactive.ps1 -OutputPath "C:\Combined\ShowEpisode.mkv"
# The script will then prompt:
# Enter full path for the next MKV file (or press Enter to finish): C:\Temp\Part1.mkv
# Enter full path for the next MKV file (or press Enter to finish): C:\Temp\Part2.mkv
# Enter full path for the next MKV file (or press Enter to finish): [User presses Enter]
# ... (combining process starts)

.EXAMPLE
.\Combine-MkvFiles-Interactive.ps1 -OutputPath "D:\Movies\FinalCut.mkv" -MkvMergePath "C:\MKVToolNix\mkvmerge.exe"

.NOTES
Requires MKVToolNix. Download from https://mkvtoolnix.download/
The original input files are NOT deleted or modified.
Ensure you have enough disk space for the new combined file.
The order files are entered determines the final file's playback sequence.
You must provide the full path to each input file.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$MkvMergePath = "mkvmerge" # Default assumption: mkvmerge is in PATH
)

# Get the current date and time for logging or other purposes if needed
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Verbose "Script started at $currentDateTime"
Write-Verbose "Current Location: $PSScriptRoot" # Or use (Get-Location).Path

# --- Verify Tools ---
$mkvmergeExe = Get-Command $MkvMergePath -ErrorAction SilentlyContinue
if (-not $mkvmergeExe) {
    Write-Error "Cannot find '$MkvMergePath'. Make sure MKVToolNix is installed and '$MkvMergePath' is correct (either in PATH or specified via -MkvMergePath parameter)."
    return
}
Write-Verbose "Using mkvmerge at: $($mkvmergeExe.Source)"
# --- End Verify Tools ---

# --- Get User Input Files Interactively ---
$selectedFilePaths = [System.Collections.Generic.List[string]]::new()
Write-Host "Enter the full paths for the MKV files to combine, one per line."
Write-Host "Press Enter on an empty line when you have entered all files."

while ($true) {
    $promptMessage = "Enter full path for the next MKV file (or press Enter to finish)"
    $userInputPath = Read-Host $promptMessage

    if ([string]::IsNullOrWhiteSpace($userInputPath)) {
        # User pressed Enter on an empty line, signaling completion
        if ($selectedFilePaths.Count -lt 2) {
            Write-Warning "You must enter at least two files to combine. Operation cancelled."
            return
        }
        else {
            Write-Host "Finished collecting file paths."
            break # Exit the loop
        }
    }

    # Validate the entered path
    $isValid = $true
    $resolvedInputPath = $null
    try {
        # Resolve the path to handle relative paths and check existence
        $resolvedInputPath = Resolve-Path -Path $userInputPath -ErrorAction Stop
    }
    catch {
        Write-Warning "Error resolving path '$userInputPath': $($_.Exception.Message)"
        $isValid = $false
    }

    if ($isValid) {
        if (-not (Test-Path $resolvedInputPath -PathType Leaf)) {
            Write-Warning "Path '$resolvedInputPath' is not a valid file or does not exist. Please try again."
            $isValid = $false
        }
        elseif ($resolvedInputPath.Path.ToLower() -notlike '*.mkv') {
            Write-Warning "File '$($resolvedInputPath.Path)' does not appear to be an MKV file (expected .mkv extension). Please try again."
            $isValid = $false
        }
    }

    if ($isValid) {
        # Add the validated, resolved full path to the list
        $selectedFilePaths.Add($resolvedInputPath.Path)
        Write-Host " -> Added: $($resolvedInputPath.Path)" -ForegroundColor Green
    }
    else {
        # Input was invalid, loop continues to prompt again
        Write-Host " -> Path rejected. Please try again." -ForegroundColor Yellow
    }
} # End while loop for collecting paths

# --- Confirm Selection and Order ---
Write-Host "`nWill combine the following files in this order:"
$orderCounter = 1
foreach ($filePath in $selectedFilePaths) {
    Write-Host " ($orderCounter) $filePath"
    $orderCounter++
}
Write-Host "" # Newline for clarity

# --- Validate Output File Path ---
$outputFullPath = $null
try {
    # 1. Basic Name/Type Check
    $outputLeaf = Split-Path -Path $OutputPath -Leaf
    if ([string]::IsNullOrWhiteSpace($outputLeaf) -or $OutputPath.EndsWith('\') -or $OutputPath.EndsWith('/')) {
        throw "The specified OutputPath ('$OutputPath') appears to be a directory or invalid. Please provide a full file path including the filename (e.g., 'C:\MyOutput\File.mkv')."
    }

    # 2. Check Parent Directory Existence
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir) {
        # If a parent directory is specified in the path...
        if (-not (Test-Path $outputDir -PathType Container)) {
            throw "The directory for the specified OutputPath ('$outputDir') does not exist. Please create it or check the path."
        }
        # If the directory exists, proceed to resolve the full path.
    }
    else {
        # No directory specified, implies current directory. Check if current location is valid.
        if (-not (Test-Path (Get-Location).Path -PathType Container)) {
            throw "Could not verify the current location ('$(Get-Location)') as a valid directory for the output file."
        }
    }

    # 3. Construct the Full Absolute Path (without requiring the file to exist)
    # Use .NET methods for robust path handling across platforms/versions
    if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        # Path is already absolute, just normalize it (e.g., fix slashes D:/ -> D:\)
        $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
    }
    else {
        # Path is relative, combine with current directory and normalize
        $currentDir = (Get-Location).Path
        $outputFullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($currentDir, $OutputPath))
    }
    Write-Verbose "Resolved absolute output path: $outputFullPath"

    # Check if the leaf name is still valid after normalization (edge case)
    if ([string]::IsNullOrWhiteSpace((Split-Path -Path $outputFullPath -Leaf))) {
        throw "Failed to determine a valid filename from the provided OutputPath after normalization: '$outputFullPath'"
    }

}
catch {
    Write-Error "Invalid Output Path '$OutputPath': $($_.Exception.Message)"
    return # Stop script execution if output path is invalid
}

# --- Continue with checks using the resolved $outputFullPath ---

# Check if output file might overwrite an input file
if ($selectedFilePaths -contains $outputFullPath) {
    Write-Error "Output path '$outputFullPath' matches one of the input files. To avoid data loss, please choose a different output name. Operation cancelled."
    return
}

# Check if file exists and ask for confirmation to overwrite
# Use the resolved $outputFullPath here
if (Test-Path $outputFullPath -PathType Leaf) {
    $overwriteConfirm = Read-Host "Output file '$outputFullPath' already exists. Overwrite? (y/N)"
    if ($overwriteConfirm.Trim().ToLower() -ne 'y') {
        Write-Host "Operation cancelled by user. Output file will not be overwritten."
        return
    }
}

# --- Construct mkvmerge Command ---
# Use an ArrayList for easier adding of arguments
$mkvmergeArgsList = [System.Collections.ArrayList]::new()
$mkvmergeArgsList.Add("-o") # Output file specifier
$mkvmergeArgsList.Add("`"$outputFullPath`"") # Enclose in quotes

# Add the first file
$mkvmergeArgsList.Add("`"$($selectedFilePaths[0])`"") # Enclose in quotes

# Add subsequent files prefixed with '+' for appending
for ($i = 1; $i -lt $selectedFilePaths.Count; $i++) {
    $mkvmergeArgsList.Add("+") # Append operator
    $mkvmergeArgsList.Add("`"$($selectedFilePaths[$i])`"") # Enclose in quotes
}

# Convert ArrayList to a string array for execution if needed, or join for Invoke-Expression
$mkvmergeArgs = $mkvmergeArgsList.ToArray()

# --- Execute mkvmerge ---
Write-Host "`nCombining files into '$outputFullPath'..."
$commandString = "& `"$($mkvmergeExe.Source)`" $($mkvmergeArgs -join ' ')"
Write-Verbose "Executing command: $commandString"


try {
    # Using Invoke-Expression as it handles the '+' syntax reliably when part of the string
    $mkvmergeOutput = Invoke-Expression $commandString 2>&1 # Capture stdout and stderr

    # Check exit code and output for errors (heuristic approach)
    # $LASTEXITCODE might be $null or 0 even on failure with Invoke-Expression sometimes
    $success = $true
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "mkvmerge process exited with code: $LASTEXITCODE (non-zero may indicate an issue)."
        # Don't immediately assume failure based only on exit code with Invoke-Expression
    }

    # Check stderr/output for common error indicators
    $errorDetected = $false
    if ($mkvmergeOutput -match "Error:|encountered a problem|failed") {
        $errorDetected = $true
    }

    if ($errorDetected) {
        Write-Error "mkvmerge likely failed to combine files."
        Write-Error "mkvmerge output:`n$($mkvmergeOutput -join "`n")"
        $success = $false
    }
    elseif (-not (Test-Path $outputFullPath -PathType Leaf)) {
        # If no explicit error text, but the output file wasn't created, it failed.
        Write-Error "mkvmerge process completed, but the output file '$outputFullPath' was not found. Combination likely failed."
        Write-Error "mkvmerge output:`n$($mkvmergeOutput -join "`n")"
        $success = $false
    }


    if ($success) {
        Write-Host "Successfully combined files into '$outputFullPath'." -ForegroundColor Green
        Write-Verbose "mkvmerge output:`n$($mkvmergeOutput -join "`n")"
    }

}
catch {
    Write-Error "An exception occurred while running mkvmerge: $_"
    Write-Error "Attempted command: $commandString"
}

Write-Host "`n--- Script finished ---"
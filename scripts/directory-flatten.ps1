<#
.SYNOPSIS
Moves all files from subdirectories into the specified parent directory (flattens the structure).

.DESCRIPTION
This script recursively finds all files within the subdirectories of the specified DirectoryPath
and moves them directly into the DirectoryPath itself. It helps to "flatten" a directory structure.

WARNING:
- This operation is irreversible. BACK UP YOUR DATA before running this script.
- If files with the same name exist in different subdirectories, only the first one encountered
  will be moved. Subsequent files with the same name will be skipped to prevent data loss,
  and a warning will be generated. Filenames are NOT changed.
- By default, the script will attempt to remove any subdirectories that become empty after
  the files are moved. Use the -RemoveEmptySubdirectories $false switch to prevent this.

.PARAMETER DirectoryPath
The full path to the main directory you want to flatten. This parameter is mandatory.

.PARAMETER RemoveEmptySubdirectories
(Optional) A boolean switch ($true or $false) indicating whether to attempt removal
of empty subdirectories after moving files. Defaults to $true (meaning empty folders will be removed).

.EXAMPLE
.\Flatten-Directory.ps1 -DirectoryPath "C:\Users\YourName\Documents\ToSort"
Description: Flattens the 'ToSort' directory and removes empty subfolders afterwards.

.EXAMPLE
.\Flatten-Directory.ps1 -DirectoryPath "D:\Downloads\Projects" -RemoveEmptySubdirectories $false
Description: Flattens the 'Projects' directory but leaves the (now empty) subfolder structure intact.

.NOTES
Ensure you have the necessary read/write/delete permissions for all files and folders involved.
Run PowerShell as an administrator if you encounter permission issues.
It is highly recommended to test this script on a copy of your data first.
#>
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Enter the full path to the directory you want to flatten.")]
    [string]$DirectoryPath,

    [Parameter(Mandatory = $false)]
    [bool]$RemoveEmptySubdirectories = $true
)

# --- Script Logic ---

# Validate the target directory exists and is a directory
if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
    Write-Error "The specified directory path does not exist or is not a directory: '$DirectoryPath'"
    # Stop script execution if the directory is invalid
    return
}

# Resolve the path to ensure it's absolute and clean for comparisons
$ResolvedDirectoryPath = Resolve-Path -Path $DirectoryPath

Write-Host "Starting directory flattening process for: '$ResolvedDirectoryPath'"
Write-Host "Files will be moved to the root. Name collisions will prevent moves."
if ($RemoveEmptySubdirectories) {
    Write-Host "Empty subdirectories WILL be removed afterwards."
}
else {
    Write-Host "Empty subdirectories will NOT be removed."
}
Write-Warning "Ensure you have a backup before proceeding! This action is irreversible."
# Optional: Add a pause for confirmation if desired
# Read-Host "Press Enter to continue, or Ctrl+C to cancel..."

# Get all files recursively, excluding files already in the target directory root
Write-Host "Searching for files to move..."
# Use $ResolvedDirectoryPath.Path for accurate string comparison
$filesToMove = Get-ChildItem -Path $ResolvedDirectoryPath -Recurse -File | Where-Object { $_.DirectoryName -ne $ResolvedDirectoryPath.Path }

if ($filesToMove.Count -eq 0) {
    Write-Host "No files found in subdirectories to move."
}
else {
    Write-Host "Found $($filesToMove.Count) files in subdirectories. Starting move process..."

    foreach ($file in $filesToMove) {
        # Construct destination path using the resolved base path
        $destinationPath = Join-Path -Path $ResolvedDirectoryPath.Path -ChildPath $file.Name

        # Check for name collision in the target directory
        if (Test-Path -Path $destinationPath -PathType Leaf) {
            # Use -PathType Leaf to ensure it's a file
            Write-Warning "Skipping move for '$($file.FullName)'. A file named '$($file.Name)' already exists in '$($ResolvedDirectoryPath.Path)'."
        }
        else {
            Write-Host "Moving '$($file.FullName)' to '$($ResolvedDirectoryPath.Path)'"
            try {
                Move-Item -Path $file.FullName -Destination $ResolvedDirectoryPath.Path -ErrorAction Stop
            }
            catch {
                Write-Error "Failed to move '$($file.FullName)'. Error: $($_.Exception.Message)"
                # Optional: Add more detailed error handling if needed
            }
        }
    }
    Write-Host "File moving process completed."
}


# --- Optional: Remove Empty Subdirectories ---
if ($RemoveEmptySubdirectories) {
    Write-Host "Attempting to remove empty subdirectories..."

    # Get all directories within the target path, sort by length DESCENDING (to remove deepest first)
    try {
        Get-ChildItem -Path $ResolvedDirectoryPath.Path -Recurse -Directory | Sort-Object -Property { $_.FullName.Length } -Descending | ForEach-Object {
            $directory = $_
            # Check if the directory is empty (contains no files or subdirectories)
            # Use -Force to check for hidden items that might prevent removal
            if ((Get-ChildItem -Path $directory.FullName -Force).Count -eq 0) {
                Write-Host "Removing empty directory: $($directory.FullName)"
                try {
                    Remove-Item -Path $directory.FullName -Recurse -Force -ErrorAction Stop
                }
                catch {
                    # Catch errors during removal (e.g., permissions, directory not *truly* empty due to hidden/system files not caught)
                    Write-Warning "Could not remove directory '$($directory.FullName)'. It might not be completely empty or there could be a permissions issue. Error: $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        Write-Error "An error occurred while trying to list or sort directories for removal: $($_.Exception.Message)"
    }
    Write-Host "Empty directory removal process completed."
}

Write-Host "Directory flattening script finished for '$($ResolvedDirectoryPath.Path)'."
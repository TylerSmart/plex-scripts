# Installing MKVToolNix to PATH

Run as an administrator in PowerShell:

```PowerShell
cd C:\Program Files\MKVToolNix

$dirToAdd = $PWD.Path; $targetScope = [System.EnvironmentVariableTarget]::User; $scopeName = 'User'; Write-Host "Attempting to add '$dirToAdd' to the $scopeName PATH."; try { $currentPath = [System.Environment]::GetEnvironmentVariable('Path', $targetScope); $pathEntries = $currentPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }; if ($pathEntries -contains $dirToAdd) { Write-Host "'$dirToAdd' is already in the $scopeName PATH." -ForegroundColor Yellow } else { $newPath = ($pathEntries + $dirToAdd) -join ';'; [System.Environment]::SetEnvironmentVariable('Path', $newPath, $targetScope); $env:Path = $newPath; Write-Host "'$dirToAdd' added to $scopeName PATH (persistent & current session)." -ForegroundColor Green } } catch { Write-Error "Failed to get or set $scopeName PATH. Error: $_" }
```

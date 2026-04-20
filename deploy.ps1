# deploy.ps1 — Windows equivalent of deploy.sh.
# Copies the plugin folder to MuseScore's plugin directory.
# The plugin/ directory is self-contained — no assembly required.
#
# Usage:
#   .\deploy.ps1           — one-shot deploy
#   .\deploy.ps1 -Watch    — auto-deploy on file changes
#
# Requires PowerShell 5+ (shipped with Windows 10/11).

param(
    [switch]$Watch
)

$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dest = Join-Path $env:USERPROFILE "Documents\MuseScore4\Plugins\chordlibrary"

function Deploy-Plugin {
    if (-not (Test-Path $Dest)) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }
    # Preserve user-created files: settings.json and cached voicing files
    $excludes = @("settings.json", "*-voicings.json")
    robocopy "$Repo\plugin" $Dest /MIR /XF $excludes /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    Write-Host ("{0} Deployed to {1}" -f (Get-Date -Format "HH:mm:ss"), $Dest)
}

if ($Watch) {
    Deploy-Plugin
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = Join-Path $Repo "plugin"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    Write-Host "Watching $($watcher.Path) for changes... (Ctrl+C to stop)"
    $action = { Deploy-Plugin }
    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action | Out-Null
    try { while ($true) { Start-Sleep -Seconds 1 } } finally { $watcher.Dispose() }
} else {
    Deploy-Plugin
    Write-Host "Done. Restart MuseScore to pick up changes."
}

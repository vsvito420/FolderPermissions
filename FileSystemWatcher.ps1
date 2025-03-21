# FileSystemWatcher-Dienst fuer Ordnerberechtigungen
$folderToWatch = 'C:\ueberordner'
$scriptToRun = 'C:\Users\Administrator\Documents\GitHub\FolderPermissions\PermissionUpdater-Wrapper.ps1'
$logFile = Join-Path $PSScriptRoot "file_watcher_log.txt"
$lastRunTime = [DateTime]::MinValue
$minimumInterval = [TimeSpan]::FromMinutes(15)

# Hilfsfunktion zum Protokollieren
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}

Write-Log "FileSystemWatcher-Dienst wird gestartet - ueberwache: $folderToWatch"

# Pruefe, ob der zu ueberwachende Ordner existiert
if (-not (Test-Path $folderToWatch)) {
    Write-Log "FEHLER: Der zu ueberwachende Ordner existiert nicht: $folderToWatch"
    exit 1
}

# Erstelle und konfiguriere den FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $folderToWatch
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

# Definiere Ereignisbehandlung fuer verschiedene Dateioperationen
$action = {
    $path = $event.SourceEventArgs.FullPath
    $changeType = $event.SourceEventArgs.ChangeType
    $timestamp = $event.TimeGenerated
    
    Write-Log "aenderung erkannt: $changeType auf $path"
    
    # Pruefe, ob genuegend Zeit seit der letzten Ausfuehrung vergangen ist
    $currentTime = Get-Date
    $timeSinceLastRun = $currentTime - $lastRunTime
    
    if ($timeSinceLastRun -ge $minimumInterval) {
        Write-Log "Fuehre Berechtigungsskript aus..."
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptToRun
            $lastRunTime = Get-Date
            Write-Log "Skriptausfuehrung abgeschlossen"
        }
        catch {
            Write-Log "FEHLER: $_"
        }
    }
    else {
        $minutesToWait = ($minimumInterval - $timeSinceLastRun).TotalMinutes
        Write-Log "Zu kurze Zeit seit letzter Ausfuehrung. Naechste Ausfuehrung in $minutesToWait Minuten moeglich."
    }
}

# Registriere Ereignisbehandlung fuer verschiedene Ereignistypen
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Renamed" -Action $action | Out-Null

Write-Log "FileSystemWatcher aktiv. Druecken Sie CTRL+C zum Beenden."

# Halte das Skript aktiv
try {
    while ($true) { Start-Sleep -Seconds 5 }
}
catch {
    Write-Log "FileSystemWatcher-Dienst wird beendet: $_"
    # Bereinigen
    $watcher.Dispose()
}
finally {
    Write-Log "FileSystemWatcher-Dienst beendet"
}

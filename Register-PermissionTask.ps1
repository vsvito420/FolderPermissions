# Register-PermissionTask.ps1
# Skript zum Registrieren des Berechtigungsskripts als geplante Aufgabe
# Dieses Skript muss mit Administratorrechten ausgefuehrt werden

# Pruefe Admin-Rechte
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Dieses Skript benoetigt Administrator-Rechte. Bitte als Administrator ausfuehren." -ForegroundColor Red
    exit 1
}

# Konfigurierbare Parameter
$taskName = "BerechtigungenAktualisieren"
$taskDescription = "Aktualisiert Berechtigungen fuer Zeichnungsordner gemaess Konfiguration"
$scheduledTaskName = "BerechtigungenAktualisieren_Zeitplan"
$scheduledTaskDescription = "Aktualisiert Berechtigungen zeitgesteuert"
$fileWatcherTaskName = "BerechtigungenAktualisieren_FileWatcher"
$fileWatcherTaskDescription = "Dienst zur ueberwachung von Ordneraenderungen"
$scriptPath = Join-Path $PSScriptRoot "PermissionUpdater-Wrapper.ps1"
$executionTimeLimit = (New-TimeSpan -Hours 1)
$restartCount = 3
$restartInterval = (New-TimeSpan -Minutes 5)
# Intervall fuer zeitgesteuerte Ausfuehrung (in Stunden)
$scheduleIntervalHours = 2
# Minimale Zeit zwischen Ausfuehrungen bei aenderungen (in Minuten)
$repeatMinutes = 30

# Pruefe, ob das Skript existiert
if (-not (Test-Path $scriptPath)) {
    Write-Host "Fehler: Das Skript wurde nicht gefunden: $scriptPath" -ForegroundColor Red
    exit 1
}

# Erstelle FileSystemWatcher-Dienst als Skript
function Create-FileWatcherService {
    param([string]$BasePath, [string]$ServiceScriptPath)
    
    # Pfad zum Watcher-Skript
    $watcherScriptContent = @"
# FileSystemWatcher-Dienst fuer Ordnerberechtigungen
`$folderToWatch = '$BasePath'
`$scriptToRun = '$scriptPath'
`$logFile = Join-Path `$PSScriptRoot "file_watcher_log.txt"
`$lastRunTime = [DateTime]::MinValue
`$minimumInterval = [TimeSpan]::FromMinutes($repeatMinutes)

# Hilfsfunktion zum Protokollieren
function Write-Log {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logEntry = "[`$timestamp] `$Message"
    Add-Content -Path `$logFile -Value `$logEntry
    Write-Host `$logEntry
}

Write-Log "FileSystemWatcher-Dienst wird gestartet - ueberwache: `$folderToWatch"

# Pruefe, ob der zu ueberwachende Ordner existiert
if (-not (Test-Path `$folderToWatch)) {
    Write-Log "FEHLER: Der zu ueberwachende Ordner existiert nicht: `$folderToWatch"
    exit 1
}

# Erstelle und konfiguriere den FileSystemWatcher
`$watcher = New-Object System.IO.FileSystemWatcher
`$watcher.Path = `$folderToWatch
`$watcher.IncludeSubdirectories = `$true
`$watcher.EnableRaisingEvents = `$true

# Definiere Ereignisbehandlung fuer verschiedene Dateioperationen
`$action = {
    `$path = `$event.SourceEventArgs.FullPath
    `$changeType = `$event.SourceEventArgs.ChangeType
    `$timestamp = `$event.TimeGenerated
    
    Write-Log "aenderung erkannt: `$changeType auf `$path"
    
    # Pruefe, ob genuegend Zeit seit der letzten Ausfuehrung vergangen ist
    `$currentTime = Get-Date
    `$timeSinceLastRun = `$currentTime - `$lastRunTime
    
    if (`$timeSinceLastRun -ge `$minimumInterval) {
        Write-Log "Fuehre Berechtigungsskript aus..."
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `$scriptToRun
            `$lastRunTime = Get-Date
            Write-Log "Skriptausfuehrung abgeschlossen"
        }
        catch {
            Write-Log "FEHLER: `$_"
        }
    }
    else {
        `$minutesToWait = (`$minimumInterval - `$timeSinceLastRun).TotalMinutes
        Write-Log "Zu kurze Zeit seit letzter Ausfuehrung. Naechste Ausfuehrung in `$minutesToWait Minuten moeglich."
    }
}

# Registriere Ereignisbehandlung fuer verschiedene Ereignistypen
Register-ObjectEvent `$watcher "Created" -Action `$action | Out-Null
Register-ObjectEvent `$watcher "Changed" -Action `$action | Out-Null
Register-ObjectEvent `$watcher "Renamed" -Action `$action | Out-Null

Write-Log "FileSystemWatcher aktiv. Druecken Sie CTRL+C zum Beenden."

# Halte das Skript aktiv
try {
    while (`$true) { Start-Sleep -Seconds 5 }
}
catch {
    Write-Log "FileSystemWatcher-Dienst wird beendet: `$_"
    # Bereinigen
    `$watcher.Dispose()
}
finally {
    Write-Log "FileSystemWatcher-Dienst beendet"
}
"@
    
    # Schreibe Inhalt in das Skript
    $watcherScriptContent | Out-File -FilePath $ServiceScriptPath -Encoding utf8
    Write-Host "FileSystem-Watcher-Skript wurde erstellt: $ServiceScriptPath" -ForegroundColor Green
}

try {
    # Pfad zum PowerShell-Interpreter
    $powerShellPath = (Get-Command powershell).Source

    # Lade Einstellungen um Basispfad zu ermitteln
    $settingsFile = Join-Path $PSScriptRoot "settings.json"
    if (Test-Path $settingsFile) {
        $settings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
        $basePath = $settings.BasePath
    } else {
        $basePath = "C:\ueberordner" # Standardwert falls keine Einstellungen vorhanden
    }
    
    Write-Host "Basispfad fuer Ordnerueberwachung: $basePath" -ForegroundColor Cyan
    
    # Erstelle Aktion fuer die Skriptausfuehrung
    $action = New-ScheduledTaskAction -Execute $powerShellPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Erstelle FileSystemWatcher-Skript
    $watcherScriptPath = Join-Path $PSScriptRoot "FileSystemWatcher.ps1"
    Create-FileWatcherService -BasePath $basePath -ServiceScriptPath $watcherScriptPath
    
    # Erstelle Aktion fuer den FileSystemWatcher-Dienst
    $watcherAction = New-ScheduledTaskAction -Execute $powerShellPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$watcherScriptPath`""
    
    # --- ZEITGESTEUERTE AUFGABE (alle paar Stunden) ---
    $scheduleTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours $scheduleIntervalHours) -RepetitionDuration ([TimeSpan]::MaxValue)
    
    # Aufgabeneinstellungen
    $taskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit $executionTimeLimit -RestartCount $restartCount -RestartInterval $restartInterval
    
    # Konfiguriere Principal (Systemkonto mit hoechsten Rechten)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Entferne bestehende Aufgaben, falls sie existieren
    $existingTask = Get-ScheduledTask -TaskName $scheduledTaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Die Aufgabe '$scheduledTaskName' existiert bereits und wird entfernt..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $scheduledTaskName -Confirm:$false
    }
    
    $existingWatcher = Get-ScheduledTask -TaskName $fileWatcherTaskName -ErrorAction SilentlyContinue
    if ($existingWatcher) {
        Write-Host "Die Aufgabe '$fileWatcherTaskName' existiert bereits und wird entfernt..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $fileWatcherTaskName -Confirm:$false
    }
    
    # Registriere die zeitgesteuerte Aufgabe
    $scheduledTask = Register-ScheduledTask -Action $action -Trigger $scheduleTrigger -Settings $taskSettings -Principal $principal -TaskName $scheduledTaskName -Description $scheduledTaskDescription
    
    # --- FILE WATCHER AUFGABE (immer aktiv im Hintergrund) ---
    # Watcher-Aufgabe mit Trigger "Bei Start"
    $watcherTrigger = New-ScheduledTaskTrigger -AtStartup
    
    # Registriere die FileWatcher-Aufgabe
    $watcherTask = Register-ScheduledTask -Action $watcherAction -Trigger $watcherTrigger -Settings $taskSettings -Principal $principal -TaskName $fileWatcherTaskName -Description $fileWatcherTaskDescription
    
    # Erfolgsmeldung
    Write-Host "`nDie geplanten Aufgaben wurden erfolgreich erstellt:" -ForegroundColor Green
    Write-Host "1. Zeitgesteuerte Ausfuehrung:" -ForegroundColor Green
    Write-Host "   - Aufgabenname: $scheduledTaskName" -ForegroundColor Cyan
    Write-Host "   - Ausfuehrung: Alle $scheduleIntervalHours Stunden" -ForegroundColor Cyan
    Write-Host "2. Ereignisgesteuerte Ausfuehrung (FileSystemWatcher):" -ForegroundColor Green
    Write-Host "   - Aufgabenname: $fileWatcherTaskName" -ForegroundColor Cyan
    Write-Host "   - Ausfuehrung: Bei Systemstart als ueberwachungsdienst" -ForegroundColor Cyan
    Write-Host "   - Minimale Zeit zwischen Ausfuehrungen: $repeatMinutes Minuten" -ForegroundColor Cyan
    
    Write-Host "`nBeide Aufgaben:" -ForegroundColor White
    Write-Host "- Skriptpfad: $scriptPath" -ForegroundColor Cyan
    Write-Host "- Ausfuehrung als: SYSTEM-Konto" -ForegroundColor Cyan
    Write-Host "- Wiederholungsversuche bei Fehler: $restartCount (alle $($restartInterval.Minutes) Minuten)" -ForegroundColor Cyan
    Write-Host "- Zeitlimit: $($executionTimeLimit.Hours) Stunde(n)" -ForegroundColor Cyan
    
    Write-Host "`nSie koennen die Aufgaben in der Aufgabenplanung einsehen und bei Bedarf anpassen." -ForegroundColor White
    Write-Host "Die FileWatcher-Aufgabe sollte nach dem naechsten Neustart automatisch aktiv sein." -ForegroundColor White
    Write-Host "Alternativ koennen Sie sie manuell ueber die Aufgabenplanung starten." -ForegroundColor White
}
catch {
    Write-Host "Fehler beim Erstellen der geplanten Aufgabe: $_" -ForegroundColor Red
    exit 1
}

# Zusaetzliche Informationen
Write-Host "`nHinweise zur Konfiguration:" -ForegroundColor Yellow
Write-Host "1. Stellen Sie sicher, dass eine gueltige settings.json-Datei existiert." -ForegroundColor White
Write-Host "2. Fuer die korrekte Ausfuehrung muss das NTFSSecurity-Modul systemweit installiert sein." -ForegroundColor White
Write-Host "   Verwenden Sie dazu: Install-Module -Name NTFSSecurity -Scope AllUsers -Force" -ForegroundColor White
Write-Host "3. Die Logdateien werden im selben Verzeichnis wie die Skripte gespeichert." -ForegroundColor White
Write-Host "4. Fuer E-Mail-Benachrichtigungen bearbeiten Sie die Send-EmailNotification-Funktion im Wrapper-Skript." -ForegroundColor White

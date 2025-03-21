# Register-PermissionTask.ps1
# Skript zum Registrieren des Berechtigungsskripts als geplante Aufgabe
# Dieses Skript muss mit Administratorrechten ausgeführt werden

# Prüfe Admin-Rechte
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Dieses Skript benötigt Administrator-Rechte. Bitte als Administrator ausführen." -ForegroundColor Red
    exit 1
}

# Konfigurierbare Parameter
$taskName = "BerechtigungenAktualisieren"
$taskDescription = "Aktualisiert Berechtigungen für Zeichnungsordner gemäß Konfiguration"
$scriptPath = Join-Path $PSScriptRoot "PermissionUpdater-Wrapper.ps1"
$startTime = "03:00" # 3 Uhr morgens
$executionTimeLimit = (New-TimeSpan -Hours 1)
$restartCount = 3
$restartInterval = (New-TimeSpan -Minutes 5)

# Prüfe, ob das Skript existiert
if (-not (Test-Path $scriptPath)) {
    Write-Host "Fehler: Das Skript wurde nicht gefunden: $scriptPath" -ForegroundColor Red
    exit 1
}

try {
    # Pfad zum PowerShell-Interpreter
    $powerShellPath = (Get-Command powershell).Source

    # Erstelle Aktion für die Aufgabe
    $action = New-ScheduledTaskAction -Execute $powerShellPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Erstelle Trigger (täglich um die konfigurierte Zeit)
    $trigger = New-ScheduledTaskTrigger -Daily -At $startTime
    
    # Konfiguriere Aufgabeneinstellungen
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit $executionTimeLimit -RestartCount $restartCount -RestartInterval $restartInterval
    
    # Konfiguriere Principal (Systemkonto mit höchsten Rechten)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Lösche die Aufgabe, falls sie bereits existiert
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Die Aufgabe '$taskName' existiert bereits und wird entfernt..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    # Registriere die Aufgabe
    $task = Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -TaskName $taskName -Description $taskDescription
    
    # Erfolgsmeldung
    Write-Host "`nDie geplante Aufgabe '$taskName' wurde erfolgreich erstellt:" -ForegroundColor Green
    Write-Host "- Ausführung: Täglich um $startTime Uhr" -ForegroundColor Cyan
    Write-Host "- Skriptpfad: $scriptPath" -ForegroundColor Cyan
    Write-Host "- Ausführung als: SYSTEM-Konto" -ForegroundColor Cyan
    Write-Host "- Wiederholungsversuche bei Fehler: $restartCount (alle $($restartInterval.Minutes) Minuten)" -ForegroundColor Cyan
    Write-Host "- Zeitlimit: $($executionTimeLimit.Hours) Stunde(n)" -ForegroundColor Cyan
    
    Write-Host "`nSie können die Aufgabe in der Aufgabenplanung unter dem Namen '$taskName' einsehen und bei Bedarf anpassen." -ForegroundColor White
}
catch {
    Write-Host "Fehler beim Erstellen der geplanten Aufgabe: $_" -ForegroundColor Red
    exit 1
}

# Zusätzliche Informationen
Write-Host "`nHinweise zur Konfiguration:" -ForegroundColor Yellow
Write-Host "1. Stellen Sie sicher, dass eine gültige settings.json-Datei existiert." -ForegroundColor White
Write-Host "2. Für die korrekte Ausführung muss das NTFSSecurity-Modul systemweit installiert sein." -ForegroundColor White
Write-Host "   Verwenden Sie dazu: Install-Module -Name NTFSSecurity -Scope AllUsers -Force" -ForegroundColor White
Write-Host "3. Die Logdateien werden im selben Verzeichnis wie die Skripte gespeichert." -ForegroundColor White
Write-Host "4. Für E-Mail-Benachrichtigungen bearbeiten Sie die Send-EmailNotification-Funktion im Wrapper-Skript." -ForegroundColor White

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
$taskDescription = "Aktualisiert Berechtigungen fuer Zeichnungsordner gemaess Konfiguration bei Aenderungen"
$scriptPath = Join-Path $PSScriptRoot "PermissionUpdater-Wrapper.ps1"
$executionTimeLimit = (New-TimeSpan -Hours 1)
$restartCount = 3
$restartInterval = (New-TimeSpan -Minutes 5)
# Minimale Zeit zwischen Ausfuehrungen
$repeatMinutes = 30

# Pruefe, ob das Skript existiert
if (-not (Test-Path $scriptPath)) {
    Write-Host "Fehler: Das Skript wurde nicht gefunden: $scriptPath" -ForegroundColor Red
    exit 1
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
    
    Write-Host "Basispfad für Ordnerüberwachung: $basePath" -ForegroundColor Cyan
    
    # Erstelle Aktion fuer die Aufgabe
    $action = New-ScheduledTaskAction -Execute $powerShellPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Erstelle Event-Trigger für Dateiänderungen
    $triggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
    $trigger = New-CimInstance -CimClass $triggerClass -ClientOnly
    
    # Event-Filter für Datei/Ordner-Änderungen (Erstellen, Ändern, Umbenennen)
    $trigger.Subscription = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-Ntfs/Operational">
    <Select Path="Microsoft-Windows-Ntfs/Operational">*[EventData[Data[@Name='FilePath']]]</Select>
  </Query>
</QueryList>
"@
    
    # Wiederholungseinstellungen - Aufgabe nicht zu oft ausführen
    $repetition = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $repeatMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)
    $trigger.Repetition = $repetition.Repetition
    
    # Konfiguriere Aufgabeneinstellungen
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit $executionTimeLimit -RestartCount $restartCount -RestartInterval $restartInterval
    
    # Konfiguriere Principal (Systemkonto mit hoechsten Rechten)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Loesche die Aufgabe, falls sie bereits existiert
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Die Aufgabe '$taskName' existiert bereits und wird entfernt..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    # Registriere die Aufgabe
    $task = Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -TaskName $taskName -Description $taskDescription
    
    # Erfolgsmeldung
    Write-Host "`nDie geplante Aufgabe '$taskName' wurde erfolgreich erstellt:" -ForegroundColor Green
    Write-Host "- Ausfuehrung: Bei Dateiänderungen im überwachten Ordner (mind. alle $repeatMinutes Minuten)" -ForegroundColor Cyan
    Write-Host "- Skriptpfad: $scriptPath" -ForegroundColor Cyan
    Write-Host "- Ausfuehrung als: SYSTEM-Konto" -ForegroundColor Cyan
    Write-Host "- Wiederholungsversuche bei Fehler: $restartCount (alle $($restartInterval.Minutes) Minuten)" -ForegroundColor Cyan
    Write-Host "- Zeitlimit: $($executionTimeLimit.Hours) Stunde(n)" -ForegroundColor Cyan
    
    Write-Host "`nSie koennen die Aufgabe in der Aufgabenplanung unter dem Namen '$taskName' einsehen und bei Bedarf anpassen." -ForegroundColor White
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

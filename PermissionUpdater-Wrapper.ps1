# PermissionUpdater-Wrapper.ps1
# Wrapper-Skript für die automatisierte Ausführung des Berechtigungsskripts als geplante Aufgabe
# Dieses Skript bietet erweiterte Fehlerbehandlung und Logging

$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "FolderPermissionUpdater.ps1"
$logFile = Join-Path $PSScriptRoot "wrapper-log.txt"
$exitCode = 0

# Funktion zum Protokollieren
function Write-WrapperLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # In Logdatei schreiben
    Add-Content -Path $logFile -Value $logMessage
    
    # Farbige Konsolenausgabe
    $color = @{INFO = 'White'; ERROR = 'Red'; WARNING = 'Yellow'; SUCCESS = 'Green'}[$Level]
    Write-Host -ForegroundColor $color $logMessage
}

# Funktion zum Senden von E-Mail-Benachrichtigungen (optional aktivieren)
function Send-EmailNotification {
    param(
        [string]$Subject,
        [string]$Body
    )
    
    # Diese Funktion aktivieren und konfigurieren, wenn E-Mail-Benachrichtigungen gewünscht sind
    <#
    $smtpServer = "smtp.ihredomain.de"
    $smtpPort = 25
    $sender = "berechtigungsskript@ihredomain.de"
    $recipients = @("admin@ihredomain.de", "it@ihredomain.de")
    
    try {
        Send-MailMessage -SmtpServer $smtpServer -Port $smtpPort -From $sender -To $recipients -Subject $Subject -Body $Body
        Write-WrapperLog "E-Mail-Benachrichtigung gesendet: $Subject" -Level INFO
    }
    catch {
        Write-WrapperLog "Fehler beim Senden der E-Mail-Benachrichtigung: $_" -Level ERROR
    }
    #>
}

# Hauptprogramm
try {
    Write-WrapperLog "Wrapper-Skript wird gestartet..." -Level INFO
    
    # Prüfe, ob das Hauptskript existiert
    if (-not (Test-Path $scriptPath)) {
        throw "Hauptskript nicht gefunden: $scriptPath"
    }
    
    # Prüfe, ob das NTFSSecurity-Modul verfügbar ist
    if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
        throw "NTFSSecurity-Modul nicht installiert. Bitte installieren Sie es mit: Install-Module -Name NTFSSecurity -Force"
    }
    
    # Hauptskript ausführen
    Write-WrapperLog "Führe Berechtigungsskript aus: $scriptPath" -Level INFO
    & $scriptPath
    
    # Prüfe Exit-Code
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
        throw "Skript wurde mit Fehlercode $LASTEXITCODE beendet."
    }
    
    # Erfolgreiche Ausführung
    Write-WrapperLog "Berechtigungsskript wurde erfolgreich ausgeführt" -Level SUCCESS
    
    # Optional: Erfolgsbenachrichtigung senden
    # Send-EmailNotification -Subject "Berechtigungsaktualisierung erfolgreich" -Body "Die Berechtigungen wurden erfolgreich aktualisiert. Details siehe Logdatei."
}
catch {
    $exitCode = if ($exitCode -eq 0) { 1 } else { $exitCode }
    $errorMessage = "Fehler beim Ausführen des Berechtigungsskripts: $_"
    Write-WrapperLog $errorMessage -Level ERROR
    
    # Fehlerbenachrichtigung senden
    # Send-EmailNotification -Subject "FEHLER: Berechtigungsaktualisierung fehlgeschlagen" -Body $errorMessage
}
finally {
    Write-WrapperLog "Wrapper-Skript beendet mit Exit-Code: $exitCode" -Level INFO
    
    # Exit-Code zurückgeben
    exit $exitCode
}

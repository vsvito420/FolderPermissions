# Test-PermissionUpdater.ps1
# Einfaches Skript zum Testen des FolderPermissionUpdaters mit Log-Ausgabe
# Dieses Skript kann manuell gestartet werden, um zu pruefen, ob das Hauptskript korrekt funktioniert

$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "FolderPermissionUpdater.ps1"
$logFile = Join-Path $PSScriptRoot "testrun-log.txt"

# Banner fuer die Konsole
function Show-Banner {
    Write-Host "`n=================================================" -ForegroundColor Cyan
    Write-Host "   TEST DES FOLDER PERMISSION UPDATERS" -ForegroundColor Cyan
    Write-Host "=================================================`n" -ForegroundColor Cyan
}

# Funktion zum Protokollieren
function Write-TestLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # In Logdatei schreiben
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
    
    # Farbige Konsolenausgabe
    $color = @{INFO = 'White'; ERROR = 'Red'; WARNING = 'Yellow'; SUCCESS = 'Green'}[$Level]
    Write-Host -ForegroundColor $color $logMessage
}

# Hauptprogramm
try {
    Show-Banner
    Write-TestLog "Test-PermissionUpdater wird gestartet..." -Level INFO
    
    # Zeit messen
    $startTime = Get-Date
    
    # Pruefe, ob das Hauptskript existiert
    if (-not (Test-Path $scriptPath)) {
        throw "Hauptskript nicht gefunden: $scriptPath"
    }
    
    # Pruefe, ob das NTFSSecurity-Modul verfuegbar ist
    if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
        Write-TestLog "WARNUNG: NTFSSecurity-Modul nicht installiert." -Level WARNING
        $installModule = Read-Host "NTFSSecurity-Modul installieren? (J/N)"
        
        if ($installModule -eq "J") {
            Write-TestLog "Installiere NTFSSecurity-Modul..." -Level INFO
            Install-Module -Name NTFSSecurity -Force -Scope CurrentUser
            Write-TestLog "NTFSSecurity-Modul wurde installiert." -Level SUCCESS
        } else {
            Write-TestLog "Das Skript wird ohne das NTFSSecurity-Modul wahrscheinlich fehlschlagen." -Level WARNING
        }
    } else {
        Write-TestLog "NTFSSecurity-Modul ist installiert." -Level SUCCESS
    }
    
    # Hauptskript ausfuehren
    Write-TestLog "Starte Berechtigungsskript: $scriptPath" -Level INFO
    
    # PowerShell-Aufruf mit Weitergabe der Fehler und Ausgaben
    & $scriptPath
    $exitCode = $LASTEXITCODE
    
    # Dauer berechnen
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    # Pruefe Exit-Code
    if ($exitCode -ne 0) {
        Write-TestLog "Skript wurde mit Fehlercode $exitCode beendet (nach $duration Sekunden)." -Level ERROR
    } else {
        Write-TestLog "Berechtigungsskript wurde erfolgreich ausgefuehrt (Dauer: $duration Sekunden)" -Level SUCCESS
    }
    
    # Zeige Hinweis auf Log-Dateien
    Write-Host "`nLog-Dateien:" -ForegroundColor Cyan
    Write-Host "- Dieses Test-Log: $logFile" -ForegroundColor White
    $mainLogFile = Join-Path $PSScriptRoot "log.txt"
    if (Test-Path $mainLogFile) {
        Write-Host "- Hauptskript-Log: $mainLogFile" -ForegroundColor White
    }
}
catch {
    Write-TestLog "Fehler beim Test: $_" -Level ERROR
}
finally {
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "   TEST ABGESCHLOSSEN" -ForegroundColor Cyan
    Write-Host "==================================================`n" -ForegroundColor Cyan
}

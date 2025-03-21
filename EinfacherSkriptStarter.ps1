# EinfacherSkriptStarter.ps1
# Ein sehr einfaches Skript zum Testen des FolderPermissionUpdaters

# Banner anzeigen
Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host "     FOLDER PERMISSION UPDATER - TEST" -ForegroundColor Cyan
Write-Host "===================================================`n" -ForegroundColor Cyan

# Pruefe, ob das Hauptskript existiert
$scriptPath = Join-Path $PSScriptRoot "FolderPermissionUpdater.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Host "FEHLER: Hauptskript nicht gefunden: $scriptPath" -ForegroundColor Red
    exit 1
}

# Pruefe, ob das NTFSSecurity-Modul verfuegbar ist
if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
    Write-Host "WARNUNG: NTFSSecurity-Modul nicht installiert." -ForegroundColor Yellow
    $installModule = Read-Host "NTFSSecurity-Modul installieren? (J/N)"
    
    if ($installModule -eq "J") {
        Write-Host "Installiere NTFSSecurity-Modul..." -ForegroundColor White
        Install-Module -Name NTFSSecurity -Force -Scope CurrentUser
        Write-Host "NTFSSecurity-Modul wurde installiert." -ForegroundColor Green
    } else {
        Write-Host "Das Skript wird ohne das NTFSSecurity-Modul wahrscheinlich fehlschlagen." -ForegroundColor Yellow
    }
} else {
    Write-Host "NTFSSecurity-Modul ist installiert." -ForegroundColor Green
}

# Bestaetigung vom Benutzer holen
Write-Host "`nDas Skript 'FolderPermissionUpdater.ps1' wird jetzt gestartet." -ForegroundColor White
$confirm = Read-Host "Fortfahren? (J/N)"

if ($confirm -eq "J") {
    Write-Host "`nStarte FolderPermissionUpdater.ps1..." -ForegroundColor Cyan
    
    # Zeit messen
    $startTime = Get-Date
    
    # Skript ausfuehren
    & $scriptPath
    $exitCode = $LASTEXITCODE
    
    # Dauer berechnen
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    # Ergebnis anzeigen
    Write-Host "`n---------------------------------------------------" -ForegroundColor Cyan
    if ($exitCode -ne 0) {
        Write-Host "Skript wurde mit Fehlercode $exitCode beendet." -ForegroundColor Red
    } else {
        Write-Host "Skript wurde erfolgreich ausgefuehrt." -ForegroundColor Green
    }
    Write-Host "Ausfuehrungsdauer: $([math]::Round($duration, 2)) Sekunden" -ForegroundColor White
    
    # Hinweis auf Logdateien
    Write-Host "`nLogdateien pruefen:" -ForegroundColor Cyan
    $logFile = Join-Path $PSScriptRoot "log.txt"
    if (Test-Path $logFile) {
        Write-Host "- $logFile" -ForegroundColor White
    }
    
    $backupPattern = Join-Path $PSScriptRoot "acl_backup_*.json"
    $backupFiles = Get-ChildItem -Path $backupPattern -ErrorAction SilentlyContinue
    if ($backupFiles) {
        Write-Host "- Backup-Dateien:" -ForegroundColor White
        foreach ($file in $backupFiles) {
            Write-Host "  - $($file.FullName)" -ForegroundColor White
        }
    }
} else {
    Write-Host "Vorgang abgebrochen." -ForegroundColor Yellow
}

# Warten auf Benutzer-Eingabe zum Beenden
Write-Host "`n====================================================" -ForegroundColor Cyan
Read-Host "Druecken Sie Enter zum Beenden"

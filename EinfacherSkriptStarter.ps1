# EinfacherSkriptStarter.ps1
# Ein sehr einfaches Skript zum Testen des FolderPermissionUpdaters

# Funktion zum Anzeigen von Windows-Benachrichtigungen
function Show-WindowsNotification {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [string]$Type = "Info"
    )
    
    try {
        # Methode 1: BurntToast-Modul (falls installiert)
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast
            
            # Passe die Parameter entsprechend des Typs an
            $splat = @{
                Text = $Title, $Message
            }
            
            if ($Type -eq "Error") {
                $splat.Sound = 'Windows.Media.Audio.AudioCategory.Other'
            }
            
            New-BurntToastNotification @splat
            return
        }
        
        # Methode 2: Windows Forms (Fallback)
        Add-Type -AssemblyName System.Windows.Forms
        
        # In einem Hintergrund-Job ausfuehren, um UI-Elemente zu ermoeglichen
        Start-Job -ScriptBlock {
            param($title, $message)
            Add-Type -AssemblyName System.Windows.Forms
            $global:balloon = New-Object System.Windows.Forms.NotifyIcon
            $path = (Get-Process -id $pid).Path
            $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
            $balloon.BalloonTipIcon = if ($args[2] -eq "Error") {"Error"} else {"Info"}
            $balloon.BalloonTipTitle = $title
            $balloon.BalloonTipText = $message
            $balloon.Visible = $true
            $balloon.ShowBalloonTip(5000)
            Start-Sleep -Seconds 6  # Zeit zum Anzeigen der Benachrichtigung
            $balloon.Dispose()
        } -ArgumentList $Title, $Message, $Type | Wait-Job -Timeout 1 | Remove-Job
    }
    catch {
        Write-Host "Fehler beim Anzeigen der Windows-Benachrichtigung: $_" -ForegroundColor Yellow
    }
}

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
    
    # Benachrichtigung anzeigen
    Show-WindowsNotification -Title "Berechtigungsskript" -Message "Das Berechtigungsskript wird ausgefuehrt..." -Type "Info"
    
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
        # Fehlerbenachrichtigung
        Show-WindowsNotification -Title "FEHLER: Berechtigungsskript" -Message "Das Berechtigungsskript ist mit Fehlercode $exitCode fehlgeschlagen." -Type "Error"
    } else {
        Write-Host "Skript wurde erfolgreich ausgefuehrt." -ForegroundColor Green
        # Erfolgsbenachrichtigung
        Show-WindowsNotification -Title "Berechtigungsskript erfolgreich" -Message "Die Berechtigungen wurden erfolgreich aktualisiert." -Type "Info"
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

# EinfacherSkriptStarter.ps1
# Ein sehr einfaches Skript zum Testen des FolderPermissionUpdaters

# Name dieses Skripts für die Protokollierung
$currentScriptName = "EinfacherSkriptStarter.ps1"

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

# Pruefe, ob die Aufgaben in der Aufgabenplanung existieren
$taskNames = @(
    "BerechtigungenAktualisieren_Zeitplan",
    "BerechtigungenAktualisieren_FileWatcher"
)
$tasksExist = $true
foreach ($taskName in $taskNames) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
        $tasksExist = $false
        Write-Host "Geplante Aufgabe '$taskName' nicht gefunden." -ForegroundColor Yellow
    }
}

if (-not $tasksExist) {
    Write-Host "`nMindestens eine geplante Aufgabe fehlt." -ForegroundColor Yellow
    $setupTasks = Read-Host "Geplante Aufgaben jetzt einrichten? (J/N)"
    
    if ($setupTasks -eq "J") {
        Write-Host "Richte geplante Aufgaben ein..." -ForegroundColor Cyan
        $registerTaskPath = Join-Path $PSScriptRoot "Register-PermissionTask.ps1"
        
        if (Test-Path $registerTaskPath) {
            # Pruefe Admin-Rechte
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin) {
                Write-Host "Die Einrichtung der Aufgaben benoetigt Administrator-Rechte." -ForegroundColor Yellow
                Write-Host "Bitte starten Sie dieses Skript neu als Administrator." -ForegroundColor Yellow
                Read-Host "Druecken Sie Enter zum Beenden"
                exit 1
            }
            
            # Fuehre Register-PermissionTask.ps1 aus
            Write-Host "`n>>> RICHTE GEPLANTE AUFGABEN EIN <<<`n" -ForegroundColor Magenta -BackgroundColor Black
            & $registerTaskPath
            
            # Prüfe, ob die Aufgaben jetzt existieren
            $tasksExistNow = $true
            foreach ($taskName in $taskNames) {
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                if (-not $task) {
                    $tasksExistNow = $false
                    Write-Host "Aufgabe '$taskName' konnte nicht eingerichtet werden." -ForegroundColor Red
                }
            }
            
            if ($tasksExistNow) {
                Write-Host "`nGeplante Aufgaben wurden erfolgreich eingerichtet." -ForegroundColor Green
            } else {
                Write-Host "`nFehler bei der Einrichtung einiger Aufgaben." -ForegroundColor Red
                $continue = Read-Host "Trotzdem mit der Skriptausfuehrung fortfahren? (J/N)"
                if ($continue -ne "J") {
                    exit 1
                }
            }
        } else {
            Write-Host "FEHLER: Register-PermissionTask.ps1 nicht gefunden: $registerTaskPath" -ForegroundColor Red
            $continue = Read-Host "Trotzdem mit der Skriptausfuehrung fortfahren? (J/N)"
            if ($continue -ne "J") {
                exit 1
            }
        }
    }
}

# Pruefe, ob das NTFSSecurity-Modul verfuegbar ist
if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
    Write-Host "`nWARNUNG: NTFSSecurity-Modul nicht installiert." -ForegroundColor Yellow
    $installModule = Read-Host "NTFSSecurity-Modul installieren? (J/N)"
    
    if ($installModule -eq "J") {
        Write-Host "Installiere NTFSSecurity-Modul..." -ForegroundColor White
        Install-Module -Name NTFSSecurity -Force -Scope CurrentUser
        Write-Host "NTFSSecurity-Modul wurde installiert." -ForegroundColor Green
    } else {
        Write-Host "Das Skript wird ohne das NTFSSecurity-Modul wahrscheinlich fehlschlagen." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nNTFSSecurity-Modul ist installiert." -ForegroundColor Green
}

# Bestaetigung vom Benutzer holen
Write-Host "`nDas Skript 'FolderPermissionUpdater.ps1' wird jetzt gestartet." -ForegroundColor White
$confirm = Read-Host "Fortfahren? (J/N)"

if ($confirm -eq "J") {
    Write-Host "`nStarte FolderPermissionUpdater.ps1..." -ForegroundColor Cyan
    
    # Skript-Ausführungshinweis
    Write-Host "`n>>> SKRIPT-AUSFÜHRUNG: $currentScriptName <<<`n" -ForegroundColor Magenta -BackgroundColor Black
    
    # Benachrichtigung anzeigen
    Show-WindowsNotification -Title "Berechtigungsskript" -Message "Skript '$currentScriptName' startet FolderPermissionUpdater.ps1..." -Type "Info"
    
    # Zeit messen
    $startTime = Get-Date
    
    # Skript ausfuehren
    Write-Host "`n>>> STARTE HAUPTSKRIPT: $scriptPath <<<`n" -ForegroundColor Magenta -BackgroundColor Black
    & $scriptPath
    $exitCode = $LASTEXITCODE
    Write-Host "`n>>> HAUPTSKRIPT BEENDET <<<`n" -ForegroundColor Magenta -BackgroundColor Black
    
    # Dauer berechnen
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    # Ergebnis anzeigen
    Write-Host "`n---------------------------------------------------" -ForegroundColor Cyan
    
    # Prüfe, ob das Skript erfolgreich war, indem wir die Logdatei analysieren
    $success = $true
    $logFile = Join-Path $PSScriptRoot "log.txt"
    
    if (Test-Path $logFile) {
        $errorCount = 0
        $logContent = Get-Content $logFile
        foreach ($line in $logContent) {
            if ($line -match "\[ERROR\]") { 
                $errorCount++ 
                $success = $false
            }
        }
        
        if ($errorCount -gt 0) {
            Write-Host "Skript wurde mit $errorCount Fehlern in der Logdatei beendet." -ForegroundColor Red
        }
    }
    
    if ($exitCode -ne 0 -and $exitCode -ne $null) {
        Write-Host "Skript wurde mit Fehlercode $exitCode beendet." -ForegroundColor Red
        # Fehlerbenachrichtigung
        Show-WindowsNotification -Title "FEHLER: Berechtigungsskript" -Message "FolderPermissionUpdater.ps1 ist mit Fehlercode $exitCode fehlgeschlagen." -Type "Error"
    } elseif ($success) {
        Write-Host "Skript wurde erfolgreich ausgefuehrt." -ForegroundColor Green
        # Erfolgsbenachrichtigung
        Show-WindowsNotification -Title "Berechtigungsskript erfolgreich" -Message "FolderPermissionUpdater.ps1 wurde erfolgreich ausgefuehrt." -Type "Info"
    } else {
        Write-Host "Skript wurde mit Warnungen oder Fehlern beendet. Siehe Logdatei fuer Details." -ForegroundColor Yellow
        # Warnungsbenachrichtigung
        Show-WindowsNotification -Title "Berechtigungsskript mit Warnungen" -Message "FolderPermissionUpdater.ps1 wurde mit Warnungen oder Fehlern ausgefuehrt. Siehe Logdatei fuer Details." -Type "Info"
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

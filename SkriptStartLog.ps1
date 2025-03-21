# SkriptStartLog.ps1
# Einfaches Monitoring-Tool fuer den FolderPermissionUpdater-Dienst
# Zeigt den Status der Aufgaben und die neuesten Logs an

# Farb-Definitionen fuer die Ausgabe
$colors = @{
    Titel = "Cyan"
    OK = "Green"
    Fehler = "Red"
    Warnung = "Yellow"
    Info = "White"
}

# Banner anzeigen
function Show-Banner {
    Clear-Host
    Write-Host "`n===================================================" -ForegroundColor $colors["Titel"]
    Write-Host "   FOLDER PERMISSION UPDATER - STATUS MONITOR" -ForegroundColor $colors["Titel"]
    Write-Host "===================================================`n" -ForegroundColor $colors["Titel"]
    Write-Host "Zeitpunkt der Abfrage: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor $colors["Info"]
}

# Status der geplanten Aufgaben pruefen
function Check-ScheduledTasks {
    Write-Host "GEPLANTE AUFGABEN" -ForegroundColor $colors["Titel"]
    Write-Host "---------------------------------------------------" -ForegroundColor $colors["Titel"]
    
    try {
        # Aufgaben abfragen
        $zeitplanTask = Get-ScheduledTaskInfo -TaskName "BerechtigungenAktualisieren_Zeitplan" -ErrorAction SilentlyContinue
        $watcherTask = Get-ScheduledTaskInfo -TaskName "BerechtigungenAktualisieren_FileWatcher" -ErrorAction SilentlyContinue
        
        # Zeitplan-Task
        if ($zeitplanTask) {
            $lastRunStatus = if ($zeitplanTask.LastTaskResult -eq 0) { "Erfolgreich" } else { "Fehler (Code: $($zeitplanTask.LastTaskResult))" }
            $lastRunColor = if ($zeitplanTask.LastTaskResult -eq 0) { $colors["OK"] } else { $colors["Fehler"] }
            
            Write-Host "Zeitgesteuerter Dienst:" -ForegroundColor $colors["Info"]
            Write-Host "  Letzte Ausfuehrung: $($zeitplanTask.LastRunTime)" -ForegroundColor $colors["Info"]
            Write-Host "  Status: " -ForegroundColor $colors["Info"] -NoNewline
            Write-Host $lastRunStatus -ForegroundColor $lastRunColor
            Write-Host "  Naechste Ausfuehrung: $($zeitplanTask.NextRunTime)" -ForegroundColor $colors["Info"]
        } else {
            Write-Host "Zeitgesteuerter Dienst: Nicht gefunden!" -ForegroundColor $colors["Fehler"]
        }
        
        # FileWatcher-Task
        if ($watcherTask) {
            $lastRunStatus = if ($watcherTask.LastTaskResult -eq 0) { "Erfolgreich" } else { "Fehler (Code: $($watcherTask.LastTaskResult))" }
            $lastRunColor = if ($watcherTask.LastTaskResult -eq 0) { $colors["OK"] } else { $colors["Fehler"] }
            
            Write-Host "`nFileSystemWatcher-Dienst:" -ForegroundColor $colors["Info"]
            Write-Host "  Letzte Ausfuehrung: $($watcherTask.LastRunTime)" -ForegroundColor $colors["Info"]
            Write-Host "  Status: " -ForegroundColor $colors["Info"] -NoNewline
            Write-Host $lastRunStatus -ForegroundColor $lastRunColor
        } else {
            Write-Host "`nFileSystemWatcher-Dienst: Nicht gefunden!" -ForegroundColor $colors["Fehler"]
        }
    } catch {
        Write-Host "Fehler beim Abfragen der geplanten Aufgaben: $_" -ForegroundColor $colors["Fehler"]
    }
}

# Letzte Eintraege aus den Logdateien anzeigen
function Show-LastLogs {
    param(
        [int]$Lines = 5
    )
    
    Write-Host "`nLOGFILES (letzte $Lines Eintraege)" -ForegroundColor $colors["Titel"]
    Write-Host "---------------------------------------------------" -ForegroundColor $colors["Titel"]
    
    # Pfade zu den Logdateien
    $logPaths = @{
        "Wrapper-Log" = Join-Path $PSScriptRoot "wrapper-log.txt"
        "Hauptskript-Log" = Join-Path $PSScriptRoot "log.txt"
        "FileWatcher-Log" = Join-Path $PSScriptRoot "file_watcher_log.txt"
    }
    
    # Fuer jede Logdatei die letzten Zeilen anzeigen
    foreach ($logName in $logPaths.Keys) {
        $logPath = $logPaths[$logName]
        
        Write-Host "`n$logName:" -ForegroundColor $colors["Titel"]
        
        if (Test-Path $logPath) {
            $logEntries = Get-Content -Path $logPath -Tail $Lines
            
            foreach ($entry in $logEntries) {
                $entryColor = $colors["Info"]
                
                # Farbige Anzeige je nach Loglevel
                if ($entry -match "\[ERROR\]") {
                    $entryColor = $colors["Fehler"]
                } elseif ($entry -match "\[WARNING\]") {
                    $entryColor = $colors["Warnung"]
                } elseif ($entry -match "\[SUCCESS\]") {
                    $entryColor = $colors["OK"]
                }
                
                Write-Host "  $entry" -ForegroundColor $entryColor
            }
        } else {
            Write-Host "  Datei nicht gefunden" -ForegroundColor $colors["Warnung"]
        }
    }
}

# Modul-Status pruefen
function Check-NTFSSecurityModule {
    Write-Host "`nMODUL-STATUS" -ForegroundColor $colors["Titel"]
    Write-Host "---------------------------------------------------" -ForegroundColor $colors["Titel"]
    
    $moduleInstalled = Get-Module -ListAvailable -Name NTFSSecurity
    
    if ($moduleInstalled) {
        Write-Host "NTFSSecurity-Modul: " -ForegroundColor $colors["Info"] -NoNewline
        Write-Host "Installiert (Version: $($moduleInstalled.Version))" -ForegroundColor $colors["OK"]
    } else {
        Write-Host "NTFSSecurity-Modul: " -ForegroundColor $colors["Info"] -NoNewline
        Write-Host "NICHT INSTALLIERT" -ForegroundColor $colors["Fehler"]
        Write-Host "  Installation mit: Install-Module -Name NTFSSecurity -Force" -ForegroundColor $colors["Info"]
    }
}

# Aktionen-Menue anzeigen
function Show-ActionMenu {
    Write-Host "`nAKTIONEN" -ForegroundColor $colors["Titel"]
    Write-Host "---------------------------------------------------" -ForegroundColor $colors["Titel"]
    Write-Host "1. Skript jetzt manuell ausfuehren (Test-PermissionUpdater.ps1)" -ForegroundColor $colors["Info"]
    Write-Host "2. Alle Logdateien anzeigen" -ForegroundColor $colors["Info"]
    Write-Host "3. Status aktualisieren" -ForegroundColor $colors["Info"]
    Write-Host "4. Beenden`n" -ForegroundColor $colors["Info"]
    
    $action = Read-Host "Aktion waehlen (1-4)"
    
    switch ($action) {
        "1" {
            $testScript = Join-Path $PSScriptRoot "Test-PermissionUpdater.ps1"
            if (Test-Path $testScript) {
                Write-Host "`nStarte Test-PermissionUpdater.ps1...`n" -ForegroundColor $colors["Titel"]
                & $testScript
                Read-Host "`nDruecken Sie Enter, um zum Hauptmenue zurueckzukehren"
            } else {
                Write-Host "`nTest-Skript nicht gefunden!" -ForegroundColor $colors["Fehler"]
                Read-Host "Druecken Sie Enter, um fortzufahren"
            }
            Main-Menu
        }
        "2" {
            Show-AllLogs
            Main-Menu
        }
        "3" {
            Main-Menu
        }
        "4" {
            Write-Host "`nMonitor wird beendet..." -ForegroundColor $colors["Titel"]
            exit
        }
        default {
            Write-Host "`nUngueltige Eingabe. Bitte 1-4 waehlen." -ForegroundColor $colors["Warnung"]
            Read-Host "Druecken Sie Enter, um fortzufahren"
            Main-Menu
        }
    }
}

# Alle Logs vollstaendig anzeigen
function Show-AllLogs {
    param(
        [int]$MaxLines = 50
    )
    
    Clear-Host
    Write-Host "`n===================================================" -ForegroundColor $colors["Titel"]
    Write-Host "   VOLLSTAENDIGE LOGDATEIEN" -ForegroundColor $colors["Titel"]
    Write-Host "===================================================`n" -ForegroundColor $colors["Titel"]
    
    # Pfade zu den Logdateien
    $logPaths = @{
        "Wrapper-Log" = Join-Path $PSScriptRoot "wrapper-log.txt"
        "Hauptskript-Log" = Join-Path $PSScriptRoot "log.txt"
        "FileWatcher-Log" = Join-Path $PSScriptRoot "file_watcher_log.txt"
        "Testrun-Log" = Join-Path $PSScriptRoot "testrun-log.txt"
    }
    
    # Fuer jede Logdatei die Inhalte anzeigen
    foreach ($logName in $logPaths.Keys) {
        $logPath = $logPaths[$logName]
        
        Write-Host "`n$logName:" -ForegroundColor $colors["Titel"]
        Write-Host "---------------------------------------------------" -ForegroundColor $colors["Titel"]
        
        if (Test-Path $logPath) {
            $logContent = Get-Content -Path $logPath
            
            if ($logContent.Count -gt $MaxLines) {
                Write-Host "  (Zeige die letzten $MaxLines von $($logContent.Count) Zeilen)" -ForegroundColor $colors["Info"]
                $logContent = $logContent | Select-Object -Last $MaxLines
            }
            
            foreach ($entry in $logContent) {
                $entryColor = $colors["Info"]
                
                # Farbige Anzeige je nach Loglevel
                if ($entry -match "\[ERROR\]") {
                    $entryColor = $colors["Fehler"]
                } elseif ($entry -match "\[WARNING\]") {
                    $entryColor = $colors["Warnung"]
                } elseif ($entry -match "\[SUCCESS\]") {
                    $entryColor = $colors["OK"]
                }
                
                Write-Host "  $entry" -ForegroundColor $entryColor
            }
        } else {
            Write-Host "  Datei nicht gefunden" -ForegroundColor $colors["Warnung"]
        }
    }
    
    Read-Host "`nDruecken Sie Enter, um zum Hauptmenue zurueckzukehren"
}

# Hauptmenue
function Main-Menu {
    Show-Banner
    Check-ScheduledTasks
    Check-NTFSSecurityModule
    Show-LastLogs -Lines 5
    Show-ActionMenu
}

# Starte das Hauptmenue
Main-Menu

# Check-PermissionUpdater.ps1
# Ueberwachungsskript fuer das Berechtigungsaktualisierungs-Skript
# Prueft den Status der letzten Ausfuehrung und zeigt relevante Logdaten an

# Konfiguration
$taskNames = @(
    "BerechtigungenAktualisieren_Zeitplan",  # Name der zeitgesteuerten Aufgabe
    "BerechtigungenAktualisieren_FileWatcher" # Name der FileWatcher-Aufgabe
)
$mainLogFile = Join-Path $PSScriptRoot "log.txt"  # Hauptlogdatei des Skripts
$wrapperLogFile = Join-Path $PSScriptRoot "wrapper-log.txt"  # Logdatei des Wrappers
$fileWatcherLogFile = Join-Path $PSScriptRoot "file_watcher_log.txt"  # Logdatei des FileWatchers
$maxLogEntries = 10  # Maximale Anzahl der anzuzeigenden Logeintraege
$errorLevelKeywords = @("ERROR", "FEHLER", "KRITISCH")  # Schluesselwoerter fuer Fehlersuche
$warningLevelKeywords = @("WARNING", "WARNUNG")  # Schluesselwoerter fuer Warnungen

function Show-TaskInfo {
    param(
        [string]$TaskName
    )
    
    try {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
        
        Write-Host "`nGEPLANTE AUFGABE INFORMATIONEN`:" -ForegroundColor Cyan
        Write-Host "------------------------------" -ForegroundColor Cyan
        Write-Host "Name`:" $TaskName -ForegroundColor White
        Write-Host "Status`:" $($task.State) -ForegroundColor White
        
        if ($taskInfo.LastRunTime) {
            Write-Host "Letzte Ausfuehrung`:" $($taskInfo.LastRunTime) -ForegroundColor White
            
            # Interpretiere den Ergebniscode
            $resultText = switch ($taskInfo.LastTaskResult) {
                0 { "Erfolgreich (0)" }
                1 { "Inkorrekte Funktion (1)" }
                2 { "System konnte den angegebenen Pfad nicht finden (2)" }
                10 { "Die Umgebung ist falsch (10)" }
                0x41306 { "Aufgabe ist derzeit ausgefuehrt (267014)" }
                0x41301 { "Aufgabe wird bereits ausgefuehrt (267009)" }
                0x41303 { "Aufgabe konnte nicht gestartet werden (267011)" }
                0x800704DD { "Der Dienst ist bereits gestartet (0x800704DD)" }
                default { "Code`:" + $($taskInfo.LastTaskResult) + " - Siehe Windows-Ereignisprotokoll fuer Details" }
            }
            
            $resultColor = if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" }
            Write-Host "Letztes Ergebnis`:" $resultText -ForegroundColor $resultColor
            
            if ($taskInfo.LastRunTime -lt (Get-Date).AddDays(-1)) {
                Write-Host "WARNUNG`: Die letzte Ausfuehrung war vor mehr als einem Tag!" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Letzte Ausfuehrung`: Noch nie ausgefuehrt" -ForegroundColor Yellow
        }
        
        if ($taskInfo.NextRunTime) {
            Write-Host "Naechste geplante Ausfuehrung`:" $($taskInfo.NextRunTime) -ForegroundColor White
        } else {
            Write-Host "Naechste geplante Ausfuehrung`: Nicht geplant" -ForegroundColor Yellow
        }
        
        return $true
    }
    catch {
        Write-Host "`nFEHLER`: Konnte keine Informationen zur Aufgabe '$TaskName' abrufen`:" -ForegroundColor Red
        Write-Host $_ -ForegroundColor Red
        Write-Host "Pruefen Sie, ob die Aufgabe existiert und Sie ausreichende Berechtigungen haben." -ForegroundColor Yellow
        return $false
    }
}

function Show-LogEntries {
    param(
        [string]$LogFile,
        [string]$Title,
        [int]$MaxEntries = $maxLogEntries
    )
    
    if (Test-Path $LogFile) {
        Write-Host "`n$Title`:" -ForegroundColor Cyan
        Write-Host "------------------------------" -ForegroundColor Cyan
        
        $logContent = Get-Content $LogFile -Tail $MaxEntries
        
        if ($logContent) {
            foreach ($line in $logContent) {
                # Bestimme Farbe basierend auf Inhalt
                $lineColor = "White"
                
                foreach ($keyword in $errorLevelKeywords) {
                    if ($line -match $keyword) {
                        $lineColor = "Red"
                        break
                    }
                }
                
                if ($lineColor -eq "White") {
                    foreach ($keyword in $warningLevelKeywords) {
                        if ($line -match $keyword) {
                            $lineColor = "Yellow"
                            break
                        }
                    }
                }
                
                if ($line -match "SUCCESS") {
                    $lineColor = "Green"
                }
                
                Write-Host $line -ForegroundColor $lineColor
            }
        } else {
            Write-Host "Keine Logeintraege gefunden." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n$Title`:" -ForegroundColor Cyan
        Write-Host "------------------------------" -ForegroundColor Cyan
        Write-Host "Logdatei nicht gefunden`:" $LogFile -ForegroundColor Yellow
    }
}

function Show-Summary {
    if (Test-Path $mainLogFile) {
        $logStats = @{
            Erfolge = 0
            Warnungen = 0
            Fehler = 0
        }
        
        $logContent = Get-Content $mainLogFile
        foreach ($line in $logContent) {
            if ($line -match "\[SUCCESS\]") { $logStats.Erfolge++ }
            foreach ($keyword in $warningLevelKeywords) {
                if ($line -match "\[$keyword\]") { $logStats.Warnungen++ }
            }
            foreach ($keyword in $errorLevelKeywords) {
                if ($line -match "\[$keyword\]") { $logStats.Fehler++ }
            }
        }
        
        Write-Host "`nZUSAMMENFASSUNG`:" -ForegroundColor Cyan
        Write-Host "------------------------------" -ForegroundColor Cyan
        Write-Host "Erfolge`:" $($logStats.Erfolge) -ForegroundColor Green
        Write-Host "Warnungen`:" $($logStats.Warnungen) -ForegroundColor Yellow
        Write-Host "Fehler`:" $($logStats.Fehler) -ForegroundColor Red
    }
}

# Hauptprogramm
Clear-Host
Write-Host "BERECHTIGUNGSAKTUALISIERUNG - STATUS CHECK" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Zeige Aufgabeninformationen für beide Aufgaben
$tasksChecked = 0
$tasksFailed = 0

foreach ($task in $taskNames) {
    $result = Show-TaskInfo -TaskName $task
    if (-not $result) {
        $tasksFailed++
    } else {
        $tasksChecked++
    }
}

# Zeige Logs
Show-LogEntries -LogFile $wrapperLogFile -Title "WRAPPER-LOG (LETZTE $maxLogEntries EINTRAEGE)"
Show-LogEntries -LogFile $mainLogFile -Title "HAUPTSKRIPT-LOG (LETZTE $maxLogEntries EINTRAEGE)"

# FileWatcher-Log anzeigen, falls vorhanden
if (Test-Path $fileWatcherLogFile) {
    Show-LogEntries -LogFile $fileWatcherLogFile -Title "FILEWATCHER-LOG (LETZTE $maxLogEntries EINTRAEGE)"
}

# Zeige Zusammenfassung
Show-Summary

# Abschluss-Bericht
Write-Host "`nSTATUS-ZUSAMMENFASSUNG:" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Cyan
Write-Host "Geplante Aufgaben geprueft: $tasksChecked" -ForegroundColor $(if ($tasksChecked -gt 0) {"Green"} else {"Yellow"})
if ($tasksFailed -gt 0) {
    Write-Host "Aufgaben mit Fehlern: $tasksFailed" -ForegroundColor Red
    Write-Host "Pruefen Sie die Aufgabenplanung und stellen Sie sicher, dass beide Aufgaben existieren." -ForegroundColor Yellow
}

Write-Host "`nStatus-Check abgeschlossen." -ForegroundColor Cyan

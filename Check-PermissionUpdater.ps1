# Check-PermissionUpdater.ps1
# Überwachungsskript für das Berechtigungsaktualisierungs-Skript
# Prüft den Status der letzten Ausführung und zeigt relevante Logdaten an

# Konfiguration
$taskName = "BerechtigungenAktualisieren"  # Name der geplanten Aufgabe
$mainLogFile = Join-Path $PSScriptRoot "log.txt"  # Hauptlogdatei des Skripts
$wrapperLogFile = Join-Path $PSScriptRoot "wrapper-log.txt"  # Logdatei des Wrappers
$maxLogEntries = 10  # Maximale Anzahl der anzuzeigenden Logeinträge
$errorLevelKeywords = @("ERROR", "FEHLER", "KRITISCH")  # Schlüsselwörter für Fehlersuche
$warningLevelKeywords = @("WARNING", "WARNUNG")  # Schlüsselwörter für Warnungen

function Show-TaskInfo {
    try {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        
        Write-Host "GEPLANTE AUFGABE INFORMATIONEN`:" -ForegroundColor Cyan
        Write-Host "------------------------------" -ForegroundColor Cyan
        Write-Host "Name`:" $taskName -ForegroundColor White
        Write-Host "Status`:" $($task.State) -ForegroundColor White
        
        if ($taskInfo.LastRunTime) {
            Write-Host "Letzte Ausführung`:" $($taskInfo.LastRunTime) -ForegroundColor White
            
            # Interpretiere den Ergebniscode
            $resultText = switch ($taskInfo.LastTaskResult) {
                0 { "Erfolgreich (0)" }
                1 { "Inkorrekte Funktion (1)" }
                2 { "System konnte den angegebenen Pfad nicht finden (2)" }
                10 { "Die Umgebung ist falsch (10)" }
                0x41306 { "Aufgabe ist derzeit ausgeführt (267014)" }
                0x41301 { "Aufgabe wird bereits ausgeführt (267009)" }
                0x41303 { "Aufgabe konnte nicht gestartet werden (267011)" }
                0x800704DD { "Der Dienst ist bereits gestartet (0x800704DD)" }
                default { "Code`:" + $($taskInfo.LastTaskResult) + " - Siehe Windows-Ereignisprotokoll für Details" }
            }
            
            $resultColor = if ($taskInfo.LastTaskResult -eq 0) { "Green" } else { "Red" }
            Write-Host "Letztes Ergebnis`:" $resultText -ForegroundColor $resultColor
            
            if ($taskInfo.LastRunTime -lt (Get-Date).AddDays(-1)) {
                Write-Host "WARNUNG`: Die letzte Ausführung war vor mehr als einem Tag!" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Letzte Ausführung`: Noch nie ausgeführt" -ForegroundColor Yellow
        }
        
        if ($taskInfo.NextRunTime) {
            Write-Host "Nächste geplante Ausführung`:" $($taskInfo.NextRunTime) -ForegroundColor White
        } else {
            Write-Host "Nächste geplante Ausführung`: Nicht geplant" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "FEHLER`: Konnte keine Informationen zur Aufgabe '$taskName' abrufen`:" $_ -ForegroundColor Red
        Write-Host "Prüfen Sie, ob die Aufgabe existiert und Sie ausreichende Berechtigungen haben." -ForegroundColor Yellow
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
            Write-Host "Keine Logeinträge gefunden." -ForegroundColor Yellow
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

# Zeige Aufgabeninformationen
Show-TaskInfo

# Zeige Logs
Show-LogEntries -LogFile $wrapperLogFile -Title "WRAPPER-LOG (LETZTE $maxLogEntries EINTRÄGE)"
Show-LogEntries -LogFile $mainLogFile -Title "HAUPTSKRIPT-LOG (LETZTE $maxLogEntries EINTRÄGE)"

# Zeige Zusammenfassung
Show-Summary

Write-Host "`nStatus-Check abgeschlossen." -ForegroundColor Cyan

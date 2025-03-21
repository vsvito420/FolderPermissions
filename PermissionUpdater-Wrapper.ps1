# PermissionUpdater-Wrapper.ps1
# Wrapper-Skript fuer die automatisierte Ausfuehrung des Berechtigungsskripts als geplante Aufgabe
# Dieses Skript bietet erweiterte Fehlerbehandlung und Logging

$ErrorActionPreference = "Stop"

# Name dieses Skripts für die Protokollierung
$currentScriptName = "PermissionUpdater-Wrapper.ps1"

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
        
        # In einem Hintergrund-Job ausführen, um UI-Elemente zu ermöglichen
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
        Write-WrapperLog "Fehler beim Anzeigen der Windows-Benachrichtigung: $_" -Level WARNING
    }
}

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
    $color = @{'INFO' = 'White'; 'ERROR' = 'Red'; 'WARNING' = 'Yellow'; 'SUCCESS' = 'Green'}[$Level]
    Write-Host -ForegroundColor $color $logMessage
}

# Funktion zum Senden von E-Mail-Benachrichtigungen (optional aktivieren)
function Send-EmailNotification {
    param(
        [string]$Subject,
        [string]$Body
    )
    
    # Diese Funktion aktivieren und konfigurieren, wenn E-Mail-Benachrichtigungen gewuenscht sind
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
    Write-WrapperLog "[$currentScriptName] Wrapper-Skript wird gestartet..." -Level INFO
    Show-WindowsNotification -Title "Berechtigungsskript" -Message "Skript '$currentScriptName' wird ausgefuehrt..." -Type "Info"
    
    # Pruefe, ob das Hauptskript existiert
    if (-not (Test-Path $scriptPath)) {
        throw "Hauptskript nicht gefunden: $scriptPath"
    }
    
    # Pruefe, ob das NTFSSecurity-Modul verfuegbar ist
    if (-not (Get-Module -ListAvailable -Name NTFSSecurity)) {
        Write-WrapperLog "NTFSSecurity-Modul nicht installiert. Versuche Installation..." -Level WARNING
        try {
            # Versuche das Modul systemweit zu installieren
            # Hinweis: Im SYSTEM-Kontext koennen Administrator-Rechte erforderlich sein
            Write-WrapperLog "Installiere NTFSSecurity-Modul systemweit (AllUsers)..." -Level INFO
            if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-WrapperLog "Warnung: Installation erfolgt ohne Admin-Rechte und koennte fehlschlagen." -Level WARNING
            }
            
            # PowerShell-Repository vertrauenswuerdig setzen, wenn noetig
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            
            # Modul installieren
            Install-Module -Name NTFSSecurity -Force -Scope AllUsers -ErrorAction Stop
            Write-WrapperLog "NTFSSecurity-Modul erfolgreich installiert." -Level SUCCESS
            
            # Modul sofort laden
            Import-Module NTFSSecurity -Force
        }
        catch {
            throw "NTFSSecurity-Modul konnte nicht installiert werden: $_. Bitte installieren Sie es manuell mit: Install-Module -Name NTFSSecurity -Force -Scope AllUsers"
        }
    }
    else {
        # Stelle sicher, dass das Modul geladen ist
        Import-Module NTFSSecurity -Force -ErrorAction Stop
        Write-WrapperLog "NTFSSecurity-Modul ist verfuegbar und wurde geladen." -Level INFO
    }
    
    # Hauptskript ausfuehren
    Write-WrapperLog "[$currentScriptName] Fuehre Hauptskript aus: $scriptPath" -Level INFO
    Write-Host "`n>>> STARTE HAUPTSKRIPT: $scriptPath <<<`n" -ForegroundColor Magenta -BackgroundColor Black
    & $scriptPath
    Write-Host "`n>>> HAUPTSKRIPT BEENDET <<<`n" -ForegroundColor Magenta -BackgroundColor Black
    
    # Pruefe, ob das Hauptskript erfolgreich war, anhand der Logdatei
    $mainLogFile = Join-Path $PSScriptRoot "log.txt"
    $scriptSuccess = $false
    
    if (Test-Path $mainLogFile) {
        $lastLines = Get-Content -Path $mainLogFile -Tail 5
        foreach ($line in $lastLines) {
            if ($line -match "\[SUCCESS\].*Skript wurde erfolgreich abgeschlossen") {
                $scriptSuccess = $true
                break
            }
        }
    }
    
    # Pruefe zusaetzlich auch den Exit-Code, falls verfuegbar
    if (-not $scriptSuccess -and $LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        $exitCode = $LASTEXITCODE
        throw "Skript wurde mit Fehlercode $LASTEXITCODE beendet."
    }
    
    if (-not $scriptSuccess) {
        throw "Skript hat keinen eindeutigen Erfolgsstatus in der Logdatei hinterlassen."
    }
    
    # Erfolgreiche Ausfuehrung
    Write-WrapperLog "[$currentScriptName] Hauptskript wurde erfolgreich ausgefuehrt" -Level SUCCESS
    
    # Erfolgsbenachrichtigung
    Show-WindowsNotification -Title "Berechtigungsskript erfolgreich" -Message "Skript '$scriptPath' wurde erfolgreich ausgefuehrt." -Type "Info"
    
    # Optional: E-Mail-Erfolgsbenachrichtigung senden
    # Send-EmailNotification -Subject "Berechtigungsaktualisierung erfolgreich" -Body "Die Berechtigungen wurden erfolgreich aktualisiert. Details siehe Logdatei."
}
catch {
    $exitCode = if ($exitCode -eq 0) { 1 } else { $exitCode }
    $errorMessage = "Fehler beim Ausfuehren des Berechtigungsskripts: $_"
    Write-WrapperLog $errorMessage -Level ERROR
    
    # Fehlerbenachrichtigung als Windows-Notification
    Show-WindowsNotification -Title "FEHLER: Berechtigungsskript" -Message "$currentScriptName - Fehler bei Ausfuehrung vom Hauptskript. Details in der Logdatei." -Type "Error"
    
    # Optional: E-Mail-Fehlerbenachrichtigung senden
    # Send-EmailNotification -Subject "FEHLER: Berechtigungsaktualisierung fehlgeschlagen" -Body $errorMessage
}
finally {
    Write-WrapperLog "[$currentScriptName] Wrapper-Skript beendet mit Exit-Code: $exitCode" -Level INFO
    
    # Exit-Code zurueckgeben
    exit $exitCode
}

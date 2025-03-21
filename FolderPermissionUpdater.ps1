<#
.SYNOPSIS
    Setzt Berechtigungen für Zeichnungsordner und erstellt optional Netzwerkfreigaben.

.DESCRIPTION
    Dieses Skript automatisiert die Verwaltung von Berechtigungen für Zeichnungsordner in einer
    vordefinierten Ordnerstruktur. Es durchsucht den angegebenen Basispfad nach Zeichnungsordnern,
    setzt die entsprechenden Berechtigungen für eine Produktionsgruppe und erstellt bei Bedarf
    die notwendigen Netzwerkfreigaben.
    
    Die Einstellungen werden aus einer settings.json Datei gelesen. Falls diese nicht existiert,
    wird sie automatisch erstellt und der Benutzer kann einen Ordner über einen Dialog auswählen.
    
    Diese Version verwendet das NTFSSecurity Modul von Raimund Andree für verbesserte
    Leistung und erweiterte Kontrolle über NTFS-Berechtigungen.

.EXAMPLE
    PS> .\script6.ps1
    Führt das Skript mit den Einstellungen aus der settings.json aus.
    Wenn keine settings.json existiert, wird ein Ordner-Auswahldialog angezeigt.
#>

# NTFSSecurity Modul importieren
Import-Module NTFSSecurity

# Lade Windows.Forms für Verzeichnisauswahl-Dialog
Add-Type -AssemblyName System.Windows.Forms

# Globale Variablen
$script:Stats = @{ErrorCount = 0; WarningCount = 0; SuccessCount = 0}
$SettingsFile = Join-Path $PSScriptRoot "settings.json"
$LogFile = Join-Path $PSScriptRoot "log.txt"
$BackupFile = Join-Path $PSScriptRoot "acl_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')_ntfs.json"
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

# Standard-Einstellungen
$DefaultSettings = @{
    BasePath = "C:\ueberordner"
    ProductionGroup = "produktion"
    TestModus = $true
    SearchPattern = "Zeichnungen*&*cklisten"
}

# Stelle sicher, dass das Encoding für die Ein- und Ausgabe korrekt ist
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Einstellungen laden oder erstellen
function Get-Settings {
    if (Test-Path $SettingsFile) {
        try {
            $settings = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
            # Konvertiere PSCustomObject zu Hashtable
            $settingsHash = @{}
            $settings.PSObject.Properties | ForEach-Object { $settingsHash[$_.Name] = $_.Value }
            return $settingsHash
        }
        catch {
            Write-Log "Fehler beim Laden der Einstellungen: $_" -Level ERROR
            # Statt Dialog: Verwende Standardeinstellungen und protokolliere
            Write-Log "Verwende Standardeinstellungen" -Level WARNING
            return $DefaultSettings
        }
    }
    else {
        # Statt Dialog: Verwende Standardeinstellungen und erstelle settings.json
        Write-Log "Keine Einstellungsdatei gefunden. Erstelle mit Standardeinstellungen." -Level WARNING
        $DefaultSettings | ConvertTo-Json | Out-File -FilePath $SettingsFile -Encoding UTF8
        Write-Log "Neue Einstellungsdatei erstellt: $SettingsFile" -Level INFO
        return $DefaultSettings
    }
}

# Einstellungen speichern
function Save-Settings {
    param([hashtable]$Settings)
    
    $Settings | ConvertTo-Json | Out-File -FilePath $SettingsFile -Encoding UTF8
    Write-Log "Einstellungen gespeichert in: $SettingsFile" -Level SUCCESS
}

# Hilfsfunktionen
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Zähler aktualisieren
    switch ($Level) {
        'ERROR'   { $script:Stats.ErrorCount++ }
        'WARNING' { $script:Stats.WarningCount++ }
        'SUCCESS' { $script:Stats.SuccessCount++ }
    }
    
    # In Logdatei schreiben und Konsole ausgeben
    [System.IO.File]::AppendAllText($LogFile, $logMessage + "`n", $Utf8NoBomEncoding)
    
    # Farbige Konsolenausgabe
    $color = @{INFO = 'White'; ERROR = 'Red'; WARNING = 'Yellow'; SUCCESS = 'Green'}[$Level]
    Write-Host -ForegroundColor $color $logMessage
}

function Test-Prerequisites {
    param([hashtable]$Settings)
    
    $success = $true
    
    # Prüfe Admin-Rechte
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Dieses Skript benötigt Administrator-Rechte." -Level ERROR
        $success = $false
    }
    
    # Prüfe Basispfad
    if (-not (Test-Path $Settings.BasePath)) {
        Write-Log "Basispfad '$($Settings.BasePath)' existiert nicht." -Level ERROR
        $success = $false
    }
    
    # Prüfe Produktionsgruppe und SMB-Funktionalität
    try {
        [ADSI]"WinNT://./$($Settings.ProductionGroup)" | Select-Object -ExpandProperty Name | Out-Null
        Write-Log "Produktionsgruppe '$($Settings.ProductionGroup)' gefunden." -Level SUCCESS
        
        Get-SmbShare -ErrorAction Stop | Out-Null
        Write-Log "SMB-Freigabe-Funktionalität verfügbar." -Level SUCCESS
    }
    catch {
        if ($_.Exception.Message -match "Produktionsgruppe") {
            Write-Log "Die Gruppe '$($Settings.ProductionGroup)' existiert nicht im System." -Level ERROR
        } else {
            Write-Log "SMB-Freigabe-Funktionalität nicht verfügbar: $_" -Level ERROR
        }
        $success = $false
    }
    
    return $success
}

# Verwaltung der Berechtigungen mit NTFSSecurity
function Manage-Permissions {
    param(
        [string]$FolderPath,
        [string]$GroupName,
        [string]$Permission = "ReadAndExecute",
        [bool]$TestOnly = $false
    )
    
    # Im Testmodus nur Aktion protokollieren
    if ($TestOnly) {
        Write-Log "[TEST] Würde Berechtigungen setzen für:" -Level INFO
        Write-Log "[TEST] - Pfad: $FolderPath" -Level INFO
        Write-Log "[TEST] - Gruppe: $GroupName" -Level INFO
        Write-Log "[TEST] - Berechtigung: $Permission" -Level INFO
        return $true
    }
    
    # Berechtigungen sichern und setzen mit NTFSSecurity
    try {
        # Backup erstellen
        $permissions = Get-NTFSAccess -Path $FolderPath
        $owner = Get-NTFSOwner -Path $FolderPath
        
        $backupInfo = @{
            Path = $FolderPath
            Owner = $owner.Owner
            Access = $permissions | Select-Object Account, AccessRights, AccessControlType, IsInherited
        }
        
        # Zum Backup hinzufügen
        $existingBackup = @()
        if (Test-Path $BackupFile) {
            $existingBackup = @(Get-Content $BackupFile -Raw | ConvertFrom-Json)
        }
        $combinedBackup = @($existingBackup) + @($backupInfo)
        $combinedBackup | ConvertTo-Json -Depth 10 | Set-Content -Path $BackupFile -Encoding UTF8
        
        # Prüfe, ob die Berechtigung bereits existiert
        $domainGroup = "$env:COMPUTERNAME\$GroupName"
        $existingRule = Get-NTFSAccess -Path $FolderPath | 
                        Where-Object { $_.Account.AccountName -eq $GroupName -and 
                                     $_.Account.Domain -eq $env:COMPUTERNAME }
        
        if ($existingRule -and $existingRule.AccessRights -eq $Permission) {
            Write-Log "Berechtigung für '$domainGroup' ist bereits korrekt gesetzt." -Level SUCCESS
            return $true
        }
        
        # Setze neue Berechtigung (mit NTFSSecurity)
        Add-NTFSAccess -Path $FolderPath -Account $domainGroup -AccessRights $Permission -AppliesTo ThisFolderSubfoldersAndFiles
        Write-Log "Berechtigungen für '$FolderPath' erfolgreich gesetzt mit NTFSSecurity." -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Fehler beim Setzen der Berechtigungen für '$FolderPath': $_" -Level ERROR
        return $false
    }
}

function Update-SharePermissions {
    param(
        [string]$ShareName,
        [string]$Path,
        [string]$GroupName,
        [bool]$TestOnly = $false
    )
    
    if ($TestOnly) {
        Write-Log "[TEST] Würde Freigabe verwalten:" -Level INFO
        Write-Log "[TEST] - Name: $ShareName" -Level INFO
        Write-Log "[TEST] - Pfad: $Path" -Level INFO
        Write-Log "[TEST] - Gruppe: $GroupName" -Level INFO
        return $true
    }
    
    try {
        $absolutePath = (Resolve-Path $Path).Path
        $existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
        
        if ($existingShare) {
            # Berechtigungen der bestehenden Freigabe aktualisieren
            Grant-SmbShareAccess -Name $ShareName -AccountName "$env:COMPUTERNAME\$GroupName" -AccessRight Read -Force
            
            # Verwende lokale Administrator-Gruppen, die auf dem System existieren
            $adminGroup = Get-LocalGroup | Where-Object { $_.SID.Value -match "-500$" -or $_.Name -match "Administratoren|Administrators" } | Select-Object -First 1
            
            if ($adminGroup) {
                $adminGroupName = "$env:COMPUTERNAME\$($adminGroup.Name)"
                try {
                    Write-Log "Verwende Administrator-Gruppe: $adminGroupName" -Level INFO
                    Grant-SmbShareAccess -Name $ShareName -AccountName $adminGroupName -AccessRight Full -Force
                } catch {
                    Write-Log "Warnung: Konnte Administrator-Berechtigungen nicht setzen: $_" -Level WARNING
                }
            } else {
                Write-Log "Warnung: Konnte keine Administrator-Gruppe finden" -Level WARNING
            }
            Set-SmbShare -Name $ShareName -FolderEnumerationMode AccessBased -Force
            Write-Log "Freigabe '$ShareName' wurde erfolgreich aktualisiert." -Level SUCCESS
        }
        else {
            # Finde lokale Administrator-Gruppe für neue Freigabe
            $adminGroup = Get-LocalGroup | Where-Object { $_.SID.Value -match "-500$" -or $_.Name -match "Administratoren|Administrators" } | Select-Object -First 1
            $adminGroupName = if ($adminGroup) { "$env:COMPUTERNAME\$($adminGroup.Name)" } else { "$env:COMPUTERNAME\Administrators" }
            
            Write-Log "Erstelle Freigabe mit Administrator-Gruppe: $adminGroupName" -Level INFO
            
            # Neue Freigabe erstellen 
            New-SmbShare -Name $ShareName -Path $absolutePath `
                        -FullAccess $adminGroupName -ReadAccess "$env:COMPUTERNAME\$GroupName" `
                        -FolderEnumerationMode AccessBased
            Write-Log "Freigabe '$ShareName' wurde erfolgreich erstellt." -Level SUCCESS
        }
        return $true
    }
    catch {
        Write-Log "Fehler bei der Freigabeverwaltung: $_" -Level ERROR
        return $false
    }
}

# Anzeige von Berechtigungen mit NTFSSecurity
function Show-FolderPermissions {
    param([string]$FolderPath)
    
    try {
        $owner = Get-NTFSOwner -Path $FolderPath
        $permissions = Get-NTFSAccess -Path $FolderPath
        
        Write-Log "Berechtigungen für '$FolderPath':" -Level INFO
        Write-Log "Besitzer: $($owner.Owner)" -Level INFO
        
        foreach ($access in $permissions) {
            $inherited = if ($access.IsInherited) { "Geerbt" } else { "Direkt" }
            Write-Log "  - $($access.Account) ($inherited): $($access.AccessRights)" -Level INFO
        }
    }
    catch {
        Write-Log "Fehler beim Anzeigen der Berechtigungen: $_" -Level ERROR
    }
}

function Show-Summary {
    Write-Host "`n----------------------------------------" -ForegroundColor Cyan
    Write-Host "ZUSAMMENFASSUNG DER AUSFÜHRUNG" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Erfolge: $($script:Stats.SuccessCount)" -ForegroundColor Green
    Write-Host "Warnungen: $($script:Stats.WarningCount)" -ForegroundColor Yellow
    Write-Host "Fehler: $($script:Stats.ErrorCount)" -ForegroundColor Red
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Logdatei: $LogFile" -ForegroundColor White
    if (Test-Path $BackupFile) {
        Write-Host "Backup-Datei: $BackupFile" -ForegroundColor White
    }
    if (Test-Path $SettingsFile) {
        Write-Host "Einstellungsdatei: $SettingsFile" -ForegroundColor White
    }
    Write-Host "----------------------------------------`n" -ForegroundColor Cyan
}

# Hauptprogramm
try {
    Write-Log "Skript wird gestartet mit NTFSSecurity Modul..." -Level INFO
    
    # Einstellungen laden
    $Settings = Get-Settings
    Write-Log "Einstellungen geladen:" -Level INFO
    Write-Log "Basispfad: $($Settings.BasePath) | Produktionsgruppe: $($Settings.ProductionGroup) | Testmodus: $($Settings.TestModus)" -Level INFO
    
    # Prüfe Voraussetzungen
    if (-not (Test-Prerequisites -Settings $Settings)) {
        throw "Voraussetzungen nicht erfüllt."
    }
    
    # Verarbeite Freigabe
    $shareName = Split-Path $Settings.BasePath -Leaf
    Update-SharePermissions -ShareName $shareName -Path $Settings.BasePath -GroupName $Settings.ProductionGroup -TestOnly $Settings.TestModus
    
    # Suche nach relevanten Zeichnungsordnern
    Write-Log "Suche nach Ordnern mit Muster '$($Settings.SearchPattern)'..." -Level INFO
    $drawingFolders = Get-ChildItem -Path $Settings.BasePath -Directory | 
                     ForEach-Object { 
                         Get-ChildItem -Path $_.FullName -Directory | 
                         Where-Object { $_.Name -like $Settings.SearchPattern } 
                     } | 
                     Select-Object -ExpandProperty FullName
    
    $folderCount = ($drawingFolders | Measure-Object).Count
    Write-Log "Gefundene Zielordner: $folderCount" -Level INFO
    
    if ($folderCount -eq 0) {
        Write-Log "Keine Zeichnungsordner gefunden!" -Level WARNING
    }
    else {
        # Zeige aktuelle Berechtigungen und setze neue
        foreach ($folder in $drawingFolders) {
            Show-FolderPermissions -FolderPath $folder
            Manage-Permissions -FolderPath $folder -GroupName $Settings.ProductionGroup -TestOnly $Settings.TestModus
        }
    }
    
    Write-Log "Skript wurde erfolgreich abgeschlossen" -Level SUCCESS
}
catch {
    Write-Log "Kritischer Fehler: $_" -Level ERROR
}
finally {
    Show-Summary
    # Tastaturabfrage für nicht-interaktiven Betrieb entfernt
}

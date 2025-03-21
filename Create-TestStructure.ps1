<#
.SYNOPSIS
    Erstellt eine Test-Ordnerstruktur für das Berechtigungsskript.

.DESCRIPTION
    Dieses Skript erstellt eine Testumgebung mit einer vordefinierten Ordnerstruktur,
    die dem Produktionsumfeld entspricht. Es werden Kundenordner und zugehörige
    Zeichnungsordner angelegt.

.PARAMETER BasePath
    Der Basispfad, in dem die Teststruktur erstellt werden soll.
    Bei Nichtangabe wird ein Auswahldialog angezeigt.

.PARAMETER UseSettingsPath
    Wenn dieser Switch gesetzt ist, wird der Basispfad aus der settings.json verwendet.

.EXAMPLE
    PS> .\Create-TestStructure.ps1
    Zeigt einen Auswahldialog für den Teststruktur-Zielordner an.

.EXAMPLE
    PS> .\Create-TestStructure.ps1 -BasePath "C:\Test\Freigaben"
    Erstellt die Teststruktur im angegebenen Pfad.

.EXAMPLE
    PS> .\Create-TestStructure.ps1 -UseSettingsPath
    Verwendet den Basispfad aus der settings.json für die Teststruktur.

.NOTES
    Dateiname: Create-TestStructure.ps1
    Autor: System Administrator
    Version: 1.1
#>

param(
    [string]$BasePath = "",
    [switch]$UseSettingsPath
)

# Funktion zum Anzeigen des Ordner-Auswahldialogs
function Get-FolderPath {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Wählen Sie den Ordner aus, in dem die Teststruktur erstellt werden soll"
    $FolderBrowser.RootFolder = [System.Environment+SpecialFolder]::Desktop
    
    if ($FolderBrowser.ShowDialog() -eq "OK") {
        return $FolderBrowser.SelectedPath
    }
    else {
        Write-Output "Keine Auswahl getroffen. Das Skript wird beendet."
        exit
    }
}

# Funktion zum Erstellen der Ordnerstruktur
function New-TestStructure {
    param(
        [string]$BasePath,
        [switch]$MatchSettings
    )
    
    # Settings-Datei und Suchpattern
    $settingsFile = Join-Path $PSScriptRoot "settings.json"
    $searchPattern = "Zeichnungen*&*cklisten" # Standard-Pattern
    
    # Wenn der Parameter MatchSettings gesetzt ist, verwenden wir den Basispfad aus der settings.json
    if ($MatchSettings) {
        if (Test-Path $settingsFile) {
            try {
                $settings = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
                $BasePath = $settings.BasePath
                if ($settings.PSObject.Properties['SearchPattern']) {
                    $searchPattern = $settings.SearchPattern
                }
                Write-Output "Verwende Basispfad aus settings.json: $BasePath"
                Write-Output "Verwende Suchmuster: $searchPattern"
            }
            catch {
                Write-Output "Fehler beim Laden der Einstellungen: $_"
                Write-Output "Verwende angegebenen Basispfad: $BasePath"
            }
        }
        else {
            Write-Output "settings.json nicht gefunden. Verwende angegebenen Basispfad: $BasePath"
        }
    }
    
    # Erstelle Hauptverzeichnis falls nicht vorhanden
    if (-not (Test-Path $BasePath)) {
        New-Item -Path $BasePath -ItemType Directory | Out-Null
        Write-Output "Hauptverzeichnis erstellt: $BasePath"
    }
    else {
        Write-Output "Hauptverzeichnis existiert bereits: $BasePath"
    }
    
# Beispiel-Kundenordner
    $kunden = @(
        @{
            Name = "Kunde1"
            HasEmptyFolder = $true
            HasDrawings = $true
            HasOtherFolders = $true
        },
        @{
            Name = "Kunde2"
            HasEmptyFolder = $false
            HasDrawings = $true
            HasOtherFolders = $false
        },
        @{
            Name = "Kunde3"
            HasEmptyFolder = $true
            HasDrawings = $false
            HasOtherFolders = $true
        },
        @{
            Name = "Kunde ohne Ordner"
            HasEmptyFolder = $false
            HasDrawings = $false
            HasOtherFolders = $false
        },
        @{
            Name = "Kunde mit Varianten"
            HasEmptyFolder = $false
            HasDrawings = $true
            HasVariants = $true
            HasOtherFolders = $false
        }
    )
    
    foreach ($kunde in $kunden) {
        $kundenPfad = Join-Path $BasePath $kunde.Name
        
        # Erstelle Kundenordner
        if (-not (Test-Path $kundenPfad)) {
            New-Item -Path $kundenPfad -ItemType Directory | Out-Null
            Write-Output "Kundenordner erstellt: $($kunde.Name)"
            
            # Erstelle Unterordner basierend auf der Konfiguration
            if ($kunde.HasEmptyFolder) {
                New-Item -Path (Join-Path $kundenPfad "Leerer Ordner") -ItemType Directory | Out-Null
                Write-Output "  + Leerer Ordner"
            }
            
            if ($kunde.HasDrawings) {
                # Verwende exakt den Namen, der zum Suchpattern passt
                $drawingFolderName = "Zeichnungen & Stücklisten"
                $drawingPath = Join-Path $kundenPfad $drawingFolderName
                New-Item -Path $drawingPath -ItemType Directory | Out-Null
                Write-Output "  + $drawingFolderName"
                
                # Erstelle einige Beispieldateien
                "Beispielzeichnung 1" | Out-File -FilePath (Join-Path $drawingPath "Zeichnung1.txt") -Encoding UTF8
                "Beispielzeichnung 2" | Out-File -FilePath (Join-Path $drawingPath "Zeichnung2.txt") -Encoding UTF8
                "Stückliste A" | Out-File -FilePath (Join-Path $drawingPath "Stückliste_A.txt") -Encoding UTF8
                
                # Testdatei für die Produktionsgruppe
                "Für Produktions-Freigabe" | Out-File -FilePath (Join-Path $drawingPath "Produktion_Test.txt") -Encoding UTF8
            }
            
            if ($kunde.HasOtherFolders) {
                New-Item -Path (Join-Path $kundenPfad "Dokumente") -ItemType Directory | Out-Null
                New-Item -Path (Join-Path $kundenPfad "Bilder") -ItemType Directory | Out-Null
                Write-Output "  + Zusätzliche Ordner (Dokumente, Bilder)"
            }
            
            # Füge Varianten des Zeichnungsordners hinzu (für umfassenderen Test)
            if ($kunde.PSObject.Properties['HasVariants'] -and $kunde.HasVariants) {
                $variants = @(
                    "Zeichnungen und Stücklisten",   # ohne & mit und
                    "Zeichnungen&Stücklisten",       # ohne Leerzeichen
                    "Zeichnungen_Stücklisten",       # mit Unterstrich
                    "ZeichnungenStücklisten",        # ohne Trennzeichen
                    "Zeichnungen & Stuecklisten"     # ohne Umlaut
                )
                
                $variantPaths = @()
                foreach ($variant in $variants) {
                    $variantPath = Join-Path $kundenPfad $variant
                    New-Item -Path $variantPath -ItemType Directory | Out-Null
                    $variantPaths += $variantPath
                }
                
                Write-Output "  + Varianten von Zeichnungsordnern (5 Varianten)"
                
                # Beispieldateien für die Varianten (in jeder Variante eine Testdatei)
                foreach ($vPath in $variantPaths) {
                    $fileName = "Testdatei_$(Split-Path $vPath -Leaf).txt"
                    "Beispieldatei für $(Split-Path $vPath -Leaf)" | Out-File -FilePath (Join-Path $vPath $fileName) -Encoding UTF8
                }
            }
        }
        else {
            Write-Output "Kundenordner existiert bereits: $($kunde.Name)"
        }
    }
}

# Hauptprogramm
try {
    if ($UseSettingsPath) {
        Write-Output "`nVerwende Pfad aus settings.json..."
        $selectedPath = ""
        New-TestStructure -BasePath $selectedPath -MatchSettings
    }
    elseif ($BasePath -ne "") {
        Write-Output "Verwende angegebenen Pfad: $BasePath"
        New-TestStructure -BasePath $BasePath
    }
    else {
        Write-Output "`nWählen Sie den Zielordner für die Teststruktur..."
        $selectedPath = Get-FolderPath
        Write-Output "Erstelle Teststruktur..."
        Write-Output "Basispfad: $selectedPath`n"
        
        New-TestStructure -BasePath $selectedPath
    }
    
    Write-Output "`nTeststruktur wurde erfolgreich erstellt!"
    Write-Output "Sie können nun das Berechtigungsskript mit dieser Struktur testen."
}
catch {
    Write-Output "`nFehler beim Erstellen der Teststruktur: $_"
}
finally {
    Write-Output "`nSkript beendet."
}

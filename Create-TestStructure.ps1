<#
.SYNOPSIS
    Erstellt eine Test-Ordnerstruktur fuer das Berechtigungsskript.

.DESCRIPTION
    Dieses Skript erstellt eine Testumgebung mit einer vordefinierten Ordnerstruktur,
    die dem Produktionsumfeld entspricht. Es werden Kundenordner und zugehoerige
    Zeichnungsordner angelegt.

.PARAMETER BasePath
    Der Basispfad, in dem die Teststruktur erstellt werden soll.
    Standard: ".\TestFreigaben"

.EXAMPLE
    PS> .\create-test-structure.ps1
    Erstellt die Teststruktur im Standardpfad ".\TestFreigaben"

.EXAMPLE
    PS> .\create-test-structure.ps1 -BasePath "C:\Test\Freigaben"
    Erstellt die Teststruktur im angegebenen Pfad

.NOTES
    Dateiname: create-test-structure.ps1
    Autor: System Administrator
#>

# Funktion zum Anzeigen des Ordner-Auswahldialogs
function Get-FolderPath {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Waehlen Sie den Ordner aus, in dem die Teststruktur erstellt werden soll"
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
        [string]$BasePath
    )
    
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
                $drawingPath = Join-Path $kundenPfad "Zeichnungen & Stuecklisten"
                New-Item -Path $drawingPath -ItemType Directory | Out-Null
                Write-Output "  + Zeichnungen & Stuecklisten"
                
                # Erstelle einige Beispieldateien
                "Beispielzeichnung 1" | Out-File -FilePath (Join-Path $drawingPath "Zeichnung1.txt") -Encoding UTF8
                "Beispielzeichnung 2" | Out-File -FilePath (Join-Path $drawingPath "Zeichnung2.txt") -Encoding UTF8
                "Stueckliste A" | Out-File -FilePath (Join-Path $drawingPath "Stueckliste_A.txt") -Encoding UTF8
            }
            
            if ($kunde.HasOtherFolders) {
                New-Item -Path (Join-Path $kundenPfad "Dokumente") -ItemType Directory | Out-Null
                New-Item -Path (Join-Path $kundenPfad "Bilder") -ItemType Directory | Out-Null
                Write-Output "  + Zusaetzliche Ordner (Dokumente, Bilder)"
            }
        }
        else {
            Write-Output "Kundenordner existiert bereits: $($kunde.Name)"
        }
    }
}

# Hauptprogramm
try {
    Write-Output "`nWaehlen Sie den Zielordner fuer die Teststruktur..."
    $selectedPath = Get-FolderPath
    Write-Output "Erstelle Teststruktur..."
    Write-Output "Basispfad: $selectedPath`n"
    
    New-TestStructure -BasePath $selectedPath
    
    Write-Output "`nTeststruktur wurde erfolgreich erstellt!"
    Write-Output "Sie koennen nun das Berechtigungsskript mit dieser Struktur testen."
}
catch {
    Write-Output "`nFehler beim Erstellen der Teststruktur: $_"
}
finally {
    Write-Output "`nSkript beendet."
}

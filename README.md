# Berechtigungsaktualisierung für Zeichnungsordner

Dieses Projekt enthält PowerShell-Skripte zur automatisierten Verwaltung von Berechtigungen für Zeichnungsordner und zur Einrichtung von Netzwerkfreigaben.

## Übersicht der Skripte

- **FolderPermissionUpdater.ps1** - Hauptskript zur Berechtigungsaktualisierung
- **PermissionUpdater-Wrapper.ps1** - Wrapper-Skript für robuste Fehlerbehandlung
- **Register-PermissionTask.ps1** - Skript zum Einrichten der geplanten Aufgabe
- **Check-PermissionUpdater.ps1** - Überwachungsskript zur Statusüberprüfung
- **settings.json** - Konfigurationsdatei für das Hauptskript

## Voraussetzungen

- Windows Server mit PowerShell 5.1 oder höher
- Administratorrechte
- NTFSSecurity-Modul (wird automatisch geprüft)

### Installation des NTFSSecurity-Moduls

Das NTFSSecurity-Modul kann mit folgendem Befehl installiert werden:

```powershell
Install-Module -Name NTFSSecurity -Scope AllUsers -Force
```

## Einrichtung als geplante Aufgabe

### Methode 1: Automatische Einrichtung

1. Führen Sie das Register-PermissionTask.ps1-Skript als Administrator aus:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Pfad\zum\Register-PermissionTask.ps1"
```

2. Das Skript richtet automatisch zwei geplante Aufgaben ein:

   **Zeitgesteuerte Aufgabe:**
   - Aufgabenname: BerechtigungenAktualisieren_Zeitplan
   - Ausführung: Alle 15 Minuten
   - Ausführung mit SYSTEM-Konto und höchsten Rechten
   - Wiederholungsversuche bei Fehlern: 3 (alle 5 Minuten)
   - Zeitlimit: 1 Stunde

   **Ereignisgesteuerte Aufgabe (FileSystemWatcher):**
   - Aufgabenname: BerechtigungenAktualisieren_FileWatcher
   - Ausführung: Bei Systemstart als Überwachungsdienst
   - Reagiert auf Änderungen im überwachten Ordner
   - Minimale Zeit zwischen Ausführungen: 15 Minuten

### Methode 2: Manuelle Einrichtung in der Aufgabenplanung

#### Zeitgesteuerte Aufgabe:

1. Öffnen Sie die Aufgabenplanung (taskschd.msc)
2. Klicken Sie auf "Aufgabe erstellen..."
3. Allgemein:
   - Name: BerechtigungenAktualisieren_Zeitplan
   - Beschreibung: Aktualisiert Berechtigungen zeitgesteuert
   - Mit höchsten Privilegien ausführen: Aktivieren
   - Ausführen, ob Benutzer angemeldet ist oder nicht: Aktivieren

4. Trigger: 
   - Beginnen: Bei Aufgabenerstellung
   - Alle 15 Minuten wiederholen für unbestimmte Dauer

5. Aktionen:
   - Programm/Skript: powershell.exe
   - Argumente: -NoProfile -ExecutionPolicy Bypass -File "C:\Pfad\zum\PermissionUpdater-Wrapper.ps1"

6. Bedingungen: Wechselstromoptionen deaktivieren

7. Einstellungen:
   - Aufgabe beenden, falls sie länger als 1 Stunde läuft
   - Wenn die Aufgabe fehlschlägt, Neustart versuchen: max. 3 Versuche

#### Ereignisgesteuerte Aufgabe (FileSystemWatcher):

1. Öffnen Sie die Aufgabenplanung (taskschd.msc)
2. Klicken Sie auf "Aufgabe erstellen..."
3. Allgemein:
   - Name: BerechtigungenAktualisieren_FileWatcher
   - Beschreibung: Dienst zur Überwachung von Ordneränderungen
   - Mit höchsten Privilegien ausführen: Aktivieren
   - Ausführen, ob Benutzer angemeldet ist oder nicht: Aktivieren

4. Trigger: Bei Systemstart

5. Aktionen:
   - Programm/Skript: powershell.exe
   - Argumente: -NoProfile -ExecutionPolicy Bypass -File "C:\Pfad\zum\FileSystemWatcher.ps1"

6. Bedingungen: Wechselstromoptionen deaktivieren

7. Einstellungen:
   - Aufgabe beenden, falls sie länger als 1 Stunde läuft
   - Wenn die Aufgabe fehlschlägt, Neustart versuchen: max. 3 Versuche

## Funktionsweise des FileSystemWatchers

Der FileSystemWatcher überwacht kontinuierlich den angegebenen Basispfad auf Änderungen. Sobald eine Datei erstellt, geändert oder umbenannt wird, reagiert das System folgendermaßen:

1. Die Änderung wird erkannt und protokolliert
2. Das System prüft, ob seit der letzten Ausführung mindestens 15 Minuten vergangen sind
3. Falls ja, wird das Berechtigungsskript ausgeführt
4. Falls nein, wird die Ausführung verzögert, um zu häufige Aktualisierungen zu vermeiden

Diese Kombination aus zeitgesteuerter und ereignisgesteuerter Ausführung gewährleistet, dass:
- Änderungen zeitnah erkannt und verarbeitet werden
- Das System nicht durch zu häufige Ausführungen überlastet wird
- Selbst bei Ausfall des FileSystemWatchers eine regelmäßige Aktualisierung erfolgt

## Konfiguration anpassen

Die Konfiguration erfolgt über die settings.json-Datei:

```json
{
    "BasePath": "C:\\ueberordner",
    "ProductionGroup": "produktion",
    "TestModus": false,
    "SearchPattern": "Zeichnungen*&*cklisten"
}
```

- **BasePath**: Der Basispfad, unter dem nach Zeichnungsordnern gesucht wird
- **ProductionGroup**: Die Gruppe, die Berechtigungen für die Zeichnungsordner erhalten soll
- **TestModus**: Wenn true, werden Änderungen nur protokolliert, aber nicht durchgeführt
- **SearchPattern**: Das Muster zur Identifizierung von Zeichnungsordnern

## Überwachung

### Status prüfen

Führen Sie das Check-PermissionUpdater.ps1-Skript aus, um den Status der geplanten Aufgabe und die letzten Logeinträge zu überprüfen:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Pfad\zum\Check-PermissionUpdater.ps1"
```

### Logdateien

Die folgenden Logdateien bieten detaillierte Informationen:

- **log.txt** - Hauptlogdatei des Skripts
- **wrapper-log.txt** - Logdatei des Wrapper-Skripts
- **acl_backup_[Datum]_ntfs.json** - Sicherung der ursprünglichen Berechtigungen

## E-Mail-Benachrichtigungen

Das Wrapper-Skript enthält eine deaktivierte E-Mail-Benachrichtigungsfunktion. Um diese zu aktivieren, bearbeiten Sie den entsprechenden Abschnitt im PermissionUpdater-Wrapper.ps1-Skript.

## Sicherheitshinweise

- Stellen Sie sicher, dass die Skriptdateien und die settings.json-Datei nur von Administratoren geändert werden können.
- Verwenden Sie den TestModus, um Änderungen zu testen, bevor Sie sie in der Produktivumgebung ausführen.
- Überprüfen Sie regelmäßig die Logdateien, um Probleme frühzeitig zu erkennen.

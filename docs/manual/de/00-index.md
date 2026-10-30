# V-OS-Handbuch

V-OS ist ein grafisches Betriebssystem für den Amstrad CPC 6128, von Grund auf in Z80-Assembler geschrieben. Es bietet:

- eine Menüleiste, verschiebbare Fenster, Dialoge und Schaltflächen, bedienbar mit der Tastatur oder einer AMX-Maus
- drei Ansichten für Dateien und Programme (Schreibtisch, Programme, Commander) und die Einstellungen (Optionen)
- sechs Sprachen als Plugins: Englisch, Griechisch, Französisch, Spanisch, Deutsch und Italienisch
- Programme, die nebeneinander laufen und dort weitermachen, wo sie aufgehört haben, ein Zubehörprogramm und Programme im Hintergrund
- Studio, einen Block-Editor im Stil von Scratch, der auf dem CPC selbst läuft
- eine API mit 42 Aufrufen und ein SDK für Programme in Assembler

Dieses Handbuch gibt es auch auf [Griechisch](../00-index.md), [Englisch](../en/00-index.md), [Französisch](../fr/00-index.md), [Spanisch](../es/00-index.md) und [Italienisch](../it/00-index.md).

## Inhalt

| Kapitel | Für wen |
|---|---|
| [1. Erste Schritte](01-getting-started.md): Starten, der Bildschirm, Tasten, Maus | alle |
| [2. Die Ansichten](02-views.md): Schreibtisch, Programme, Commander, Optionen | alle |
| [3. Programme](03-programs.md): Starten, mehrere gleichzeitig, Zubehör, Hintergrund, die Programme auf der Diskette | alle |
| [4. Sprachen](04-languages.md) | alle |
| [5. Studio](05-studio.md): Blockprogramme auf dem CPC, alle Blöcke | alle, die Programme erstellen |
| [6. Blöcke auf dem Computer](06-blocks-web.md): der Web-Editor und `vbc.py` | alle, die Programme erstellen |
| [7. SDK](../../../sdk/README.de.md): Programme in Assembler mit der API | Programmierer |
| [8. V-OS entwickeln](08-development.md): Build, Aufbau, Tests, Speicher | alle, die an V-OS selbst arbeiten |

Derselbe Inhalt steht auch als PDF zur Verfügung, in [`docs/V-OS-de.pdf`](../../V-OS-de.pdf). Es wird mit `make docs` erzeugt.

## Weitere Dokumente

- [`README.md`](../../../README.md): der Stand des Projekts, Meilenstein für Meilenstein, mit dem, was jeweils getestet wurde.
- [`docs/REQUIREMENTS.md`](../../REQUIREMENTS.md): die Anforderungen und der Entwurf, mit den Umsetzungsdetails jedes Meilensteins.
- [`src/api/vos_api.inc`](../../../src/api/vos_api.inc): die API, mit allen Regeln in Kommentaren.

> Diese Dokumentation beschreibt V-OS bis einschließlich M33. Sie wird mit jedem Meilenstein aktualisiert.

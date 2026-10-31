# 3. Programme

## Starten und Beenden

Ein Programm startet auf eine dieser Arten:

- aus der Ansicht Programme: auswählen und RETURN drücken, oder zweimal klicken
- vom Schreibtisch oder aus dem Commander: DATEI > STARTEN
- aus einem anderen Programm, etwa Studio, das alles startet, was du erstellst

Jedes Programm hat sein eigenes Menü neben den gemeinsamen Menüs ANSICHT und HILFE. Es endet über sein Menü (meist BACK oder STOP, CONTROL+Q) und kehrt zu der Ansicht zurück, aus der es gestartet wurde.

## Mehrere Programme gleichzeitig

Es gibt zwei Arten von V-OS-Programmen:

- **Kleine, mit einer Relokationstabelle:** DEMO, MIXED und CLOCK, die Beispiele des Web-Editors (PONG, CATCH, STARCAT, COUNTER) und alles, was das [SDK](../../../sdk/README.de.md) erzeugt. Sie teilen sich 12K Speicher, und so viele, wie hineinpassen, laufen zusammen.
- **Programme, die den ganzen Speicher brauchen:** STUDIO und alles, was Studio erzeugt (CALC, MINES, FLAP, TICKER und deine eigenen). Ohne Speichererweiterung laufen sie nur allein. Läuft schon eines, erscheint „ERST EIN ANDERES PROGRAMM SCHLIESSEN“.

Wenn du zu einer Ansicht wechselst (F1–F4), während ein Programm läuft:

- Ein kleines Programm bleibt im Speicher. Du holst es in der Ansicht Programme (RETURN darauf) oder mit F6 wieder hervor, und es macht genau dort weiter, wo es war.
- Ein Programm, das den ganzen Speicher hat, endet, außer es gibt eine Speichererweiterung.

**F6** (ANSICHT > PROGRAMME) zeigt die Liste der laufenden Programme. Du wählst eines mit den Pfeilen und RETURN. Läuft keines, erscheint „KEIN PROGRAMM LÄUFT“.

**Mit einer Speichererweiterung** (z. B. 512K, die V-OS beim Start von selbst findet) bekommt jedes Programm, das den ganzen Speicher braucht, eine eigene Bank. So können STUDIO, CALC, DEMO und PONG alle zusammen laufen. Seit M43 bekommt jedes Programm auch eine eigene Datenbank von 16K, wenn es sie braucht: was es dort hält, geht nicht verloren, wenn andere Programme oder Ansichten laufen.

## Im Hintergrund

Ein Programm hinter einem anderen oder hinter einer Ansicht **friert** normalerweise **ein** und macht weiter, wenn es wieder nach vorne kommt.

Manche Programme verlangen, auch im Hintergrund **weiterzulaufen**, z. B. TICKER, das die Zeit zählt. Solange sie dort sind, zeichnen sie nicht und spielen keinen Ton. Wenn sie wieder nach vorne kommen, haben sie auch die Zeit mitgezählt, in der sie weg waren.

In Studio wählst du das für dein Programm mit STUDIO > IN BACKGROUND.

## Das Zubehörprogramm (ZUBEHÖR)

Ein kleines Programm wie CLOCK kann sich in einem Fenster **über allem** öffnen: über einer Ansicht oder einem Programm.

1. Wähle in der Ansicht Programme CLOCK aus und dann DATEI > ALS ZUBEHÖR (^A).
2. Ab dann öffnet und schließt **F5** es, wo du auch bist. Auch ESC schließt es.

Solange es offen ist, bekommt es die Tasten und Klicks. Sein Fenster lässt sich an seinem Titel verschieben. Wenn es sich schließt, wird neu gezeichnet, was darunter war.

## Die Programme auf der Diskette

| Programm | Was es ist |
|---|---|
| **STUDIO** | der Block-Editor: Du erstellst Programme auf dem CPC ([Kapitel 5](05-studio.md)) |
| **DEMO** | das erste V-OS-Programm: ein Quadrat, das sich von selbst bewegt. Die Pfeile steuern es, und SPACE ändert seine Farbe |
| **MIXED** | der „gemischte Bildschirm“: ein Streifen mit 16 Farben (Modus 0) zwischen Streifen in Modus 1. Ein Klick zeigt die Koordinaten |
| **CLOCK** | die Zeit seit dem Start von V-OS. Läuft auch als Zubehörprogramm |
| **CALC** | ein Taschenrechner in einem Fenster mit Schaltflächen, erstellt in Studio (es gibt auch `CALC.VBS`) |
| **MINES** | ein Minesweeper mit 8×6 Feldern und 8 Minen, erstellt in Studio. Ein Klick deckt ein Feld auf, und NEW startet ein neues Spiel |
| **BRICKS** | Mauerbrechen: ein Schläger mit ←/→, 32 Steine, 3 Leben, Level mit einem immer schnelleren Ball. Bei GAME OVER startet SPACE ein neues Spiel |
| **VROUVES** | Tower Defence, nach dem CPC-Spiel LET'S GO FOR VROUVES: 7 Level, vom Kafenio bis zum Friedhof, mit je 10 Wellen. Es steht auf seiner eigenen Diskette, `vrouves.dsk`: in B:, und TAB im Launcher. Die Pfeile bewegen den Cursor, 1–6 wählt einen Verteidiger, SPACE baut, S verkauft, N holt die nächste Welle, P pausiert. Punkte für jeden Eindringling und für die Dorfbewohner, die am Ende eines Levels übrig sind. Die Diskette speichert `VROUVES.SAV`: CONTINUE beginnt mit dem erreichten Level, HIGH SCORES zeigt die besten fünf mit Namen. Mit dem SDK geschrieben (`myapps/vrouves`) |
| **NOTEPAD** | ein Texteditor in Modus 1, 48×22, für Dateien bis 4K, oder bis 16K mit einer Speichererweiterung: dann hält es etwa 2,5K um den Cursor in seinem Speicher und den Rest in seiner eigenen Datenbank, und SELECT ALL nimmt dieses Stück. NEW, OPEN (nur `.TXT`-Dateien), SAVE, SAVE AS, OTHER DRIVE. Pfeile, DEL, CLR und RETURN; ein Klick setzt den Cursor. Die untere Zeile zeigt Zeile und Spalte. Menü EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT und die Pfeile markieren. Die Zwischenablage (bis 1K) teilen sich alle Programme (`myapps/notepad`) |
| **PAINT** | Malen in Modus 0 mit 16 Farben: ein Bild mit 128×128 (`.PIC`), oder 64×64 mit 2×-Zoom in 3 Ebenen (`.LYR`, NEW LAYERS). Werkzeuge: P Stift, B Pinsel, L Linie, X Rechteck, F Füllen; TAB wechselt die Farbe. Pfeile und COPY malen ohne Maus. Ebenen: 1–3 wählt eine, H blendet sie aus oder ein, U und D schieben sie nach oben und unten, E ist der Radierer. EXPORT .SCR: das Bild (die Ebenen, wie sie zu sehen sind) als CPC-Bildschirm, eine 16K-Datei `NAME.SCR` (Modus 0, in der Mitte, mit der Palette), für BASIC oder andere Programme. In BASIC: `MODE 0:LOAD"NAME.SCR",&C000:FOR I=0 TO 15:INK I,PEEK(&C7D0+I):NEXT:BORDER PEEK(&C7E0)` (`myapps/paint`) |
| **MUSIC** | spielt Songs von Arkos Tracker 3 (`.MUS`, mit `make songs` erzeugt), mit drei Lautstärkebalken. Es steht auf seiner eigenen Diskette, `music.dsk`, in B:. OPEN, SPACE spielt und stoppt. Die Musik läuft hinter anderen Ansichten und Programmen weiter. Studios MUSIC-Block startet es mit einem Lied hinter einem Programm (`myapps/music`) |
| **MARKDOWN** | ein Editor für Markdown-Dateien (`.MD`, bis 6K), wie NOTEPAD. ^P zeigt die Seite: `#`-Überschriften, **fett**, *kursiv*, `Code`, Listen, Zitate, Linien, Codeblöcke und unterstrichene Links, ohne die Zeichen. Aufeinanderfolgende Zeilen werden ein Absatz (zwei Leerzeichen am Ende brechen die Zeile um). Die Pfeile blättern die Seite, RETURN oder ^P führen zurück zum Text. Es steht auf seiner eigenen Diskette, `markdown.dsk`, mit einer `README.MD`. Menü EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT und die Pfeile markieren. Die Zwischenablage (bis 1K) teilen sich alle Programme (`myapps/markdown`) |
| **SYSINFO** | zeigt die Versionen von V-OS und der API, den Speicher (den ganzen und den für Programme freien) und den freien Platz auf den Disketten in A: und B: (^R erneut). Ein Beispiel für `VOS_EXT` (`myapps/sysinfo`) |
| **WEBGET** | lädt Dateien aus dem Web mit der M4-Karte: GET A FILE (^G) fragt nach einer Adresse (HTTP, z. B. `example.com/index.html`) und einem Namen, und die Datei (bis 16K) wird auf dem angezeigten Laufwerk gespeichert (OTHER DRIVE). Es zeigt auch den Netzwerkstatus. Ohne M4-Karte: „NO M4 BOARD“ (`myapps/webget`) |
| **READER** | liest Markdown-Seiten (`.MD`, bis 6K) von der Diskette oder mit der M4-Karte aus dem Web, so dargestellt wie die Vorschau von MARKDOWN. TAB wählt den nächsten Link (invertiert), RETURN öffnet ihn, DEL geht zur vorigen Seite zurück (es merkt sich 4). Ein Link ohne `http://` öffnet sich neben der Seite, auf der Diskette oder auf derselben Website. OPEN A FILE und OPEN AN ADDRESS (^U, HTTP, z. B. `example.com/README.md`). `https://`-Adressen lassen sich nicht öffnen. Es ist auf einer eigenen Diskette, `reader.dsk`, mit `INDEX.MD` und `ABOUT.MD` (`myapps/reader`) |
| **STREETS** | ein Straßenverzeichnis in einer V-OS-Datenbank: tippe die ersten Buchstaben einer Straße und sieh die Straßen, die so beginnen, mit Gebiet und Postleitzahl; DEL löscht einen Buchstaben. ^A fügt eine Straße hinzu, ^D löscht die erste der Liste. Die Straßen sind in `STREETS.VDB` auf seiner Diskette, `streets.dsk`, in B:; beim ersten Mal legt es sie mit Straßen Athens an. Ein Beispiel der Datenbank-API (`myapps/streets`) |
| **PONG** | ein Ball und ein Schläger mit den Pfeilen, Punkte und Leben |
| **CATCH** | fange die fallenden Sterne |
| **STARCAT** | eine Katze mit Kostümen, die läuft, ein Stern, eine Melodie aus einer Liste |
| **COUNTER** | ein Zähler mit den Schaltflächen +1, −1 und 0, in Modus 1 |
| **FLAP** | ein Vogel, der mit den Flügeln schlägt (Kostüme), und ein Stern, der jede Sekunde das Kostüm wechselt |
| **TICKER** | zählt Sekunden und läuft im Hintergrund weiter |

- Blockprogramme sind `.VBN`-Dateien. Sie haben ein Menü PROGRAM > STOP (CONTROL+Q).
- Die, die auch eine `.VBS` haben (CALC, MINES, FLAP, TICKER), lassen sich in Studio öffnen, damit du sie ansehen oder ändern kannst.
- `VBRUN.SYS` ist kein Programm: Es ist der „Player“, den Studio braucht.

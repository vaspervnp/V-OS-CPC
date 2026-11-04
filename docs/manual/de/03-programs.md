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
- **Programme, die den ganzen Speicher brauchen:** STUDIO und alles, was Studio erzeugt (CALC, MINES, FLAP, TICKER und deine eigenen). Ebenso MARKDOWN und READER, die über 12K groß sind. Ohne Speichererweiterung laufen sie nur allein. Läuft schon eines, erscheint „ERST EIN ANDERES PROGRAMM SCHLIESSEN“.

Wenn du zu einer Ansicht wechselst (F1–F4), während ein Programm läuft:

- Ein kleines Programm bleibt im Speicher. Du holst es in der Ansicht Programme (RETURN darauf) oder mit F6 wieder hervor, und es macht genau dort weiter, wo es war.
- Ein Programm, das den ganzen Speicher hat, endet, außer es gibt eine Speichererweiterung.

**F6** (ANSICHT > PROGRAMME) zeigt die Liste der laufenden Programme. Du wählst eines mit den Pfeilen und RETURN. Läuft keines, erscheint „KEIN PROGRAMM LÄUFT“.

**Mit einer Speichererweiterung** (z. B. 512K, die V-OS beim Start von selbst findet) bekommt jedes Programm, das den ganzen Speicher braucht, eine eigene Bank. So können STUDIO, CALC, DEMO und PONG alle zusammen laufen. Seit M43 bekommt jedes Programm auch eine eigene Datenbank von 16K, wenn es sie braucht: was es dort hält, geht nicht verloren, wenn andere Programme oder Ansichten laufen.

## Im Hintergrund

Ein Programm hinter einem anderen oder hinter einer Ansicht **friert** normalerweise **ein** und macht weiter, wenn es wieder nach vorne kommt.

Manche Programme verlangen, auch im Hintergrund **weiterzulaufen**, z. B. TICKER, das die Zeit zählt. Solange sie dort sind, zeichnen sie nicht und spielen keinen Ton. Wenn sie wieder nach vorne kommen, haben sie auch die Zeit mitgezählt, in der sie weg waren.

In Studio wählst du das für dein Programm mit STUDIO > IN BACKGROUND.

MUSIC ist die Ausnahme: Sein Lied spielt aus dem Interrupt, 50-mal pro Sekunde, und läuft deshalb gleichmäßig hinter allem weiter. Es hält nur kurz an, während die Diskette gelesen wird.

## Fenster

Mit einer **Speichererweiterung** öffnen CLOCK, SYSINFO, DIARY, TELNET, WEBGET und DATABASE in einem **Fenster** auf dem Schreibtisch, über den Fenstern der anderen laufenden Programme. Ebenso ein Studio-Programm im Modus 1, das ein eigenes Fenster öffnet (wie CALC): das Fenster zeigt dessen Inneres mit seinen Knöpfen. DIARY, TELNET, WEBGET und DATABASE zeigen im Fenster ihren Bildschirm wie bisher; verkleinert zeigt es den oberen linken Teil davon. Auch NOTEPAD, MARKDOWN, READER und SHEET öffnen in einem Fenster und richten ihren Text darin ein: so viele Spalten und Zeilen, wie hineinpassen, die Statuszeile darunter, und erneut, wann immer man die Größe ändert. Ihre Seite (^M) und das Diagramm von SHEET erscheinen im Vollbild; ^M bringt das Fenster wieder dorthin zurück, wo es war, so groß, wie es war. Jedes Fenster behält eine Kopie von sich im Speicher; verschiebt man ein Fenster über die anderen, erscheinen diese sofort wieder, ohne dass ihre Programme sie neu zeichnen. Unter den Fenstern ist das Bild des Schreibtischs zu sehen (BACKGROUND im Setup). Auch das Dateifenster und die Laufwerkssymbole des Schreibtischs sind unter den Fenstern: sie erscheinen hinter den Programmen, und auf dem Schreibtisch (F1) erscheinen die Fenster der Programme auf seiner Fläche. Ein Klick auf ein Fenster holt es nach vorn, ein Klick auf das Fenster oder die Symbole des Schreibtischs holt den Schreibtisch. Die übrigen Programme öffnen noch im Vollbild.

- Die Menüleiste bleibt oben und gehört dem Fenster **vorn**. Ein Klick auf ein anderes Fenster holt es mit seiner Leiste nach vorn.
- Den **Titel** eines Fensters ziehen verschiebt es, seine **rechte untere Ecke** ändert seine Größe. Das Programm ordnet seinen Inhalt für die neue Größe an.
- Das **+** im Titel oder **F7** gibt dem Programm den ganzen Bildschirm (unter der Leiste) und wieder ein Fenster. **X** schließt das Programm.
- Die Uhr **läuft weiter**, während ein anderes Fenster vorn ist, solange keines sie verdeckt.

## Das Zubehörprogramm (ZUBEHÖR)

Ein kleines Programm wie CLOCK kann sich in einem Fenster **über allem** öffnen: über einer Ansicht oder einem Programm.

1. Wähle in der Ansicht Programme CLOCK aus und dann DATEI > ALS ZUBEHÖR (^A).
2. Ab dann öffnet und schließt **F5** es, wo du auch bist. Auch ESC schließt es.

Solange es offen ist, bekommt es die Tasten und Klicks. Sein Fenster lässt sich an seinem Titel verschieben. Wenn es sich schließt, wird neu gezeichnet, was darunter war.

## Die Seite (Modus 2)

NOTEPAD, MARKDOWN, READER und SHEET haben PAGE (MODE 2) in ihrem Menü, ^M. Der Bildschirm wechselt in Modus 2: schwarze Schrift auf weißem Papier, 768 Pixel breit, auch Menüs und Dialoge schwarz auf weiß. Die Editoren (NOTEPAD und MARKDOWN) zeigen 80 Spalten zwischen den Rändern der Seite, eine Linie, wo jede Seite von 60 Zeilen endet, und PAGE n in der letzten Zeile. Die Vorschau von MARKDOWN und READER zeigen die Seite in 80 Spalten mit ihren Stilen. SHEET zeigt 10 Spalten (A–J) mit Linien dazwischen. ^M noch einmal kehrt zu Modus 1 zurück.

## Die Programme auf der Diskette

Eine CPC-Diskette fasst 180K, darum kommt V-OS auf zwei. `vos.dsk` (A:) hat das System, DEMO, MIXED, STUDIO und CLOCK und die `.VBS`-Quellen der VB-Programme, die Studio von A: öffnet. `apps.dsk` (B:) hat die anderen, von PONG bis WEBGET: im Launcher zeigt TAB das Laufwerk B:. Manche Programme haben eine eigene Diskette, wie die Tabelle sagt.

| Programm | Was es ist |
|---|---|
| **STUDIO** | der Block-Editor: Du erstellst Programme auf dem CPC ([Kapitel 5](05-studio.md)) |
| **DEMO** | das erste V-OS-Programm: ein Quadrat, das sich von selbst bewegt. Die Pfeile steuern es, und SPACE ändert seine Farbe |
| **MIXED** | der „gemischte Bildschirm“: ein Streifen mit 16 Farben (Modus 0) zwischen Streifen in Modus 1. Ein Klick zeigt die Koordinaten |
| **CLOCK** | die Zeit seit dem Start von V-OS; mit einer M4-Karte die echte Uhrzeit und, als Programm, das Datum (vom Zeitserver der M4, eingestellt mit `NETSET` auf dem CPC). Läuft auch als Zubehörprogramm |
| **CALC** | ein Taschenrechner in einem Fenster mit Schaltflächen, erstellt in Studio (es gibt auch `CALC.VBS`) |
| **MINES** | ein Minesweeper mit 8×6 Feldern und 8 Minen, erstellt in Studio. Ein Klick deckt ein Feld auf, und NEW startet ein neues Spiel |
| **BRICKS** | Mauerbrechen: ein Schläger mit ←/→, 32 Steine, 3 Leben, Level mit einem immer schnelleren Ball. Bei GAME OVER startet SPACE ein neues Spiel |
| **VROUVES** | Tower Defence, nach dem CPC-Spiel LET'S GO FOR VROUVES: 7 Level, vom Kafenio bis zum Friedhof, mit je 10 Wellen. Es steht auf seiner eigenen Diskette, `vrouves.dsk`: in B:, und TAB im Launcher. Die Pfeile bewegen den Cursor, 1–6 wählt einen Verteidiger, SPACE baut, S verkauft, N holt die nächste Welle, P pausiert. Punkte für jeden Eindringling und für die Dorfbewohner, die am Ende eines Levels übrig sind. Die Diskette speichert `VROUVES.SAV`: CONTINUE beginnt mit dem erreichten Level, HIGH SCORES zeigt die besten fünf mit Namen. Mit dem SDK geschrieben (`myapps/vrouves`) |
| **NOTEPAD** | ein Texteditor in Modus 1, 48×22, für Dateien bis 4K, oder bis 16K mit einer Speichererweiterung: dann hält es etwa 2,5K um den Cursor in seinem Speicher und den Rest in seiner eigenen Datenbank, und SELECT ALL nimmt dieses Stück. NEW, OPEN (nur `.TXT`-Dateien), SAVE, SAVE AS, OTHER DRIVE. Pfeile, DEL, CLR und RETURN; ein Klick setzt den Cursor. Die untere Zeile zeigt Zeile und Spalte. Menü EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT und die Pfeile markieren. Die Zwischenablage (bis 1K) teilen sich alle Programme. PRINT ^P druckt den Text auf einem Drucker. UNDO ^Z (Menü EDIT) nimmt die letzte Änderung zurück: was getippt oder eingefügt wurde, oder was DEL, CLR, CUT oder Tippen über eine Markierung entfernt hat (bis zu 256 Zeichen); noch einmal ^Z macht es wieder. FIND ^F (Menü EDIT) sucht einen Text ab dem Cursor im ganzen Text (A–Z ohne Groß-/Kleinschreibung) und markiert ihn; FIND AGAIN ^G den nächsten; REPLACE ^R fragt nach dem Text und dem Ersatz und ändert ihn im ganzen Text (NOT FOUND, wenn er nicht da ist) (`myapps/notepad`) |
| **PAINT** | Malen in Modus 0 mit 16 Farben: ein Bild des ganzen CPC-Bildschirms, 160×200 ohne Overscan (`.SCR`, 16K, das auch BASIC und andere CPC-Programme laden; ohne Speichererweiterung 128×128, `.PIC`), oder 64×64 mit 2×-Zoom in 3 Ebenen (`.LYR`, NEW LAYERS). Werkzeuge: P Stift, B Pinsel, L Linie, X Rechteck, F Füllen, C Kreis (von seiner Mitte bis dahin, wo die Taste losgelassen wird); TAB wechselt die Farbe. Pfeile und COPY malen ohne Maus. Das Fenster zeigt 128×128 des Bildes: die Leisten rechts und darunter zeigen, welchen Teil, und ein Klick oder Ziehen darauf verschiebt es. Unter den Farben: wo der Zeiger im Bild ist, und VIEW, die linke obere Ecke des Fensters. Ebenen: 1–3 wählt eine, H blendet sie aus oder ein, U und D schieben sie nach oben und unten, E ist der Radierer. UNDO ^Z nimmt das letzte Werkzeug zurück, und noch einmal ^Z bringt es wieder (Füllen des ganzen Bildschirms lässt sich nicht zurücknehmen; nachdem ein anderes Programm gelaufen ist, gibt es nichts zurückzunehmen). EXPORT .SCR (für das 128×128-Bild und die Ebenen; der ganze Bildschirm ist schon eine `.SCR`): das Bild (die Ebenen, wie sie zu sehen sind) als CPC-Bildschirm, eine 16K-Datei `NAME.SCR` (Modus 0, in der Mitte, mit der Palette), für BASIC oder andere Programme. In BASIC: `MODE 0:LOAD"NAME.SCR",&C000:FOR I=0 TO 15:INK I,PEEK(&C7D0+I):NEXT:BORDER PEEK(&C7E0)` (`myapps/paint`) |
| **MUSIC** | spielt Songs von Arkos Tracker 3 (`.MUS`, mit `make songs` erzeugt), mit drei Lautstärkebalken. Es steht auf seiner eigenen Diskette, `music.dsk`, in B:. OPEN, SPACE spielt und stoppt. Die Musik läuft hinter anderen Ansichten und Programmen gleichmäßig weiter, auch während ein anderes Programm lädt oder zeichnet: Sie spielt aus dem Interrupt. Studios MUSIC-Block startet es mit einem Lied hinter einem Programm (`myapps/music`) |
| **MARKDOWN** | ein Editor für Markdown-Dateien (`.MD`, bis 6K), wie NOTEPAD. ^P zeigt die Seite: `#`-Überschriften, **fett**, *kursiv*, `Code`, Listen, Zitate, Linien, Codeblöcke und unterstrichene Links, ohne die Zeichen. Aufeinanderfolgende Zeilen werden ein Absatz (zwei Leerzeichen am Ende brechen die Zeile um). Die Pfeile blättern die Seite, RETURN oder ^P führen zurück zum Text. Es steht auf seiner eigenen Diskette, `markdown.dsk`, mit einer `README.MD`. Menü EDIT: COPY ^C, CUT ^X, PASTE ^V, SELECT ALL ^A; SHIFT und die Pfeile markieren. Die Zwischenablage (bis 1K) teilen sich alle Programme (`myapps/markdown`) |
| **DIARY** | die Tage und was an ihnen ist: der Monat in Modus 1, eine Woche pro Zeile ab Montag, der gewählte Tag invertiert und die Tage mit Notizen mit `*` markiert, darunter die Notizen des gewählten Tages (bis zu 10, je 40 Zeichen). Die Pfeile gehen einen Tag und eine Woche weiter, `<` und `>` einen Monat, TAB geht zu den Notizen (UP/DOWN wählen eine, RETURN ändert sie, DEL löscht sie). ^A fügt eine Notiz hinzu, ^T geht zu heute. Mit einer M4-Karte beginnt es mit heute, ohne sie mit dem letzten Tag mit einer Notiz. Die Notizen stehen in `DIARY.VDB` auf dem Laufwerk, von dem es gestartet wurde (^W das andere Laufwerk), beim ersten Mal angelegt, über `DB.SYS` (`myapps/diary`) |
| **SHOW** | die `.SCR`-Bilder eines Laufwerks eins nach dem anderen, in Modus 0, mit ihren eigenen Farben (denen von PAINT): das nächste alle fünf Sekunden, → und ← von Hand, SPACE hält an und macht weiter, ^W das andere Laufwerk (A:, B:, DISK). Bis zu 48 Bilder (`myapps/show`) |
| **SYSINFO** | zeigt die Versionen von V-OS und der API, den Speicher (den ganzen und den für Programme freien) und den freien Platz auf den Disketten in A: und B: (^R erneut). Ein Beispiel für `VOS_EXT` (`myapps/sysinfo`) |
| **TELNET** | Text über das Netz mit der M4-Karte: ^O CONNECT fragt nach `HOST:PORT` (ein Name wie `bbs.example.org` oder Zahlen wie `192.168.1.10`; ohne Port 23) und verbindet per TCP. Was ankommt, wird ins Fenster geschrieben, das am Ende nach oben rollt; Farben und andere ANSI-Codes werden weggelassen, Griechisch in ISO 8859-7 erscheint, wie es ist, und Telnet-Optionen, nach denen die Gegenseite fragt, werden abgelehnt. Die unten getippte Zeile geht mit RETURN hinaus. ^D CLOSE beendet die Verbindung, wie es auch die Gegenseite kann; die erste Zeile zeigt den Zustand (CONNECTED, NO CONNECTION…). Ohne M4-Karte: NO M4 BOARD (`myapps/telnet`) |
| **WEBGET** | lädt Dateien aus dem Web mit der M4-Karte: GET A FILE (^G) fragt nach einer Adresse (HTTP, z. B. `example.com/index.html`) und einem Namen, und die Datei (bis 16K) wird auf dem angezeigten Laufwerk gespeichert (OTHER DRIVE). Es zeigt auch den Netzwerkstatus. Ohne M4-Karte: „NO M4 BOARD“ (`myapps/webget`) |
| **READER** | liest Markdown-Seiten (`.MD`, bis 6K) von der Diskette oder mit der M4-Karte aus dem Web, so dargestellt wie die Vorschau von MARKDOWN. TAB wählt den nächsten Link (invertiert), RETURN öffnet ihn, DEL geht zur vorigen Seite zurück (es merkt sich 4). Ein Link ohne `http://` öffnet sich neben der Seite, auf der Diskette oder auf derselben Website. OPEN A FILE und OPEN AN ADDRESS (^U, HTTP, z. B. `example.com/README.md`). `https://`-Adressen lassen sich nicht öffnen. Es ist auf einer eigenen Diskette, `reader.dsk`, mit `INDEX.MD` und `ABOUT.MD` (`myapps/reader`) |
| **STREETS** | ein Straßenverzeichnis in einer V-OS-Datenbank: tippe die ersten Buchstaben einer Straße und sieh die Straßen, die so beginnen, mit Gebiet und Postleitzahl; DEL löscht einen Buchstaben. ^A fügt eine Straße hinzu, ^D löscht die erste der Liste. Die Straßen sind in `STREETS.VDB` auf seiner Diskette, `streets.dsk`, in B:; beim ersten Mal legt es sie mit Straßen Athens an. Ein Beispiel der Datenbank-API (`myapps/streets`) Beim Suchen zählen Groß- und Kleinschreibung und Akzente nicht. |
| **DATABASE** | Datenbanken, wie ein kleines Access: ^N eine neue Datenbank (`NAME.VDB`), ^O eine öffnen, ^T eine neue Tabelle (ihr Name und Felder: ein Name, TEXT bis 40 Zeichen oder ZAHL 0–65535, und ob sie nach dem ersten sortiert wird). Die Liste zeigt einen Datensatz pro Zeile und die Felder in Spalten; die Pfeile wählen und blättern, TAB geht zur nächsten Tabelle, und hat die Tabelle einen Schlüssel, springt das Getippte zu den Datensätzen, die so beginnen (ohne Groß-/Kleinschreibung und Akzente). RETURN öffnet das Formular: ein Feld pro Zeile, RETURN ändert es, ^S speichert, ^B zurück zur Liste. ^A ein neuer Datensatz, ^D löschen, ^W das andere Laufwerk, ^P druckt die Tabelle so, wie die Liste sie zeigt, alle Datensätze. PRINT LETTERS ^L druckt eine `.TXT` des Laufwerks (einen in NOTEPAD geschriebenen Brief) einmal für jeden Datensatz der Tabelle, jeden auf eine Seite: der Name eines Feldes in geschweiften Klammern, `{NAME}`, wird zu dem, was der Datensatz darin hat (ohne Groß-/Kleinschreibung; ein unbekannter Name bleibt, wie er ist). IMPORT CSV fügt der benutzten Tabelle für jede Zeile einer `.CSV` einen Datensatz hinzu: die Felder der Reihe nach, durch Kommas oder Semikolons getrennt, Texte auf ihre Länge gekürzt, Zahlen aus ihren Ziffern; eine erste Zeile, die mit dem Namen des ersten Feldes beginnt (die Überschriften), wird übersprungen. Es öffnet auch die `.VDB` von STREETS (`myapps/database`) |
| **SHEET** | eine Tabellenkalkulation: 16 Spalten (A–P) und 64 Zeilen, 5 Spalten und 19 Zeilen auf dem Bildschirm. Eine Zelle enthält, bis zu 40 Zeichen, eine Zahl (`12`, `-3.5`; das Dezimalzeichen ist ein Punkt), Text oder eine Formel nach `=`: `+ - * /`, Klammern, Zellen (`B3`), SUM, AVG, MIN, MAX und COUNT von Zellen und Bereichen (`=SUM(B2:B9)`), ABS, INT, ROUND(x, 0–2). Zahlen haben zwei Dezimalstellen, bis ±21474836.46. Die Pfeile bewegen den Cursor, RETURN ändert die Zelle, Tippen beginnt einen neuen Text, DEL (oder CLR) leert sie; nach jeder Änderung werden alle Formeln neu berechnet. Die erste Zeile zeigt den Text der Zelle. Eine Zelle mit Fehler zeigt `#ERR`, eine zu breite Zahl `########`. ^N neu, ^O öffnen, ^S speichern, ^A speichern unter (`NAME.VSH`, eine Textdatei, eine Zeile je Zelle: `B3 =B1*2`), ^W das andere Laufwerk, ^P druckt das Blatt so, wie die Seite es zeigt, die Spalten A–H und dann I–P, bis zur letzten benutzten Zeile. ^G CHART: ein Bereich einer Spalte oder einer Zeile (`B2:B9`, bis zu 16 Zellen; zuerst die Spalte des Cursors bis zu ihrer letzten Zahl) als Balken in Modus 0, jeder so hoch, wie die Zelle im Verhältnis zur größten ist, mit den Texten der Spalte A (oder der Zeile 1) darunter; ^S speichert das Diagramm als `.SCR` (die Balken, ohne die Texte), das PAINT und BASIC öffnen, jede andere Taste geht zurück. OPEN CSV liest eine `.CSV` (aus einer PC-Tabellenkalkulation oder einer Datenbank): eine Zeile je Tabellenzeile, die Felder ab Spalte A, getrennt durch Kommas oder Semikolons (die erste Zeile zeigt, welche); Felder in Anführungszeichen dürfen sie enthalten, und mit Semikolons ist `1,5` die Zahl 1.5. Gespeichert wird daraus eine `.VSH` mit demselben Namen. Die Formeln berechnet `CALC.SYS` auf A:, das jedes Programm benutzen kann (`VX_CALC`). Es ist auf einer eigenen Diskette, `sheet.dsk`, mit dem Beispiel `BUDGET.VSH` (`myapps/sheet`) |
| **PONG** | ein Ball und ein Schläger mit den Pfeilen, Punkte und Leben |
| **CATCH** | fange die fallenden Sterne |
| **STARCAT** | eine Katze mit Kostümen, die läuft, ein Stern, eine Melodie aus einer Liste |
| **COUNTER** | ein Zähler mit den Schaltflächen +1, −1 und 0, in Modus 1 |
| **FLAP** | ein Vogel, der mit den Flügeln schlägt (Kostüme), und ein Stern, der jede Sekunde das Kostüm wechselt |
| **TICKER** | zählt Sekunden und läuft im Hintergrund weiter |

- Blockprogramme sind `.VBN`-Dateien. Sie haben ein Menü PROGRAM > STOP (CONTROL+Q).
- Die, die auch eine `.VBS` haben (CALC, MINES, FLAP, TICKER), lassen sich in Studio öffnen, damit du sie ansehen oder ändern kannst.
- `VBRUN.SYS` ist kein Programm: Es ist der „Player“, den Studio braucht.

## Drucken

NOTEPAD, SHEET und DATABASE drucken mit ^P (PRINT in ihrem Menü) auf einem Drucker am Druckerport des CPC (Centronics), etwa dem Amstrad DMP2000 oder einem Epson-kompatiblen.

- **Sieben Bit:** Der Port des CPC sendet 7 Bit, daher gehen Buchstaben über 127 als einfache Buchstaben hinaus: Akzente fallen weg (É → E, ñ → n, ß → s), und Griechisch wird als Greeklish geschrieben, Buchstabe für Buchstabe (Α → A, Θ → 8, Ξ → 3, Ψ → 4, Ω → W).
- **Die Seiten:** Jede Seite beginnt mit einer Kopfzeile, dem Namen der Datei und der Seitenzahl (`NOTES.TXT  SEITE 2`), und nach 60 Zeilen beginnt von selbst eine neue Seite.
- **Das Ende:** Jeder Ausdruck endet mit einer neuen Seite.
- **Kein Drucker:** Bleibt der Drucker zwei Sekunden lang belegt (keiner angeschlossen, offline, kein Papier), erscheint DER DRUCKER IST NICHT BEREIT, und das Drucken hört auf.
- Programme drucken mit dem Aufruf `VX_PRINT` (Kapitel 7).


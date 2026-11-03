# 2. Die Ansichten

V-OS hat vier „Ansichten“: Arten, die Dateien und Programme zu sehen, und die Einstellungen. Du wechselst die Ansicht mit F1–F4 oder über das Menü ANSICHT. Jede Ansicht merkt sich, welche Datei ausgewählt war, und die nächste wählt dieselbe Datei aus.

## Die gemeinsamen Menüs

Die letzten beiden Menüs sind in allen Ansichten und in Programmen gleich:

| ANSICHT | | HILFE | |
|---|---|---|---|
| SCHREIBTISCH | F1 | TASTEN | ^K |
| PROGRAMME | F2 | ÜBER V-OS | |
| COMMANDER | F3 | | |
| OPTIONEN | F4 | | |
| PROGRAMME (laufende) | F6 | | |
| SPRACHE WECHSELN | ^L | | |

HILFE > ÜBER V-OS zeigt die Version (0.15 Beta; jeder Meilenstein fügt 0.01 hinzu), das Datum des Builds, den Hersteller (Revive8bit, 2026) und den Architekten (Vasper).

## Schreibtisch, F1

Modus 1. Ein Fenster DATEIEN zeigt die Dateien eines Laufwerks als Symbole, vier pro Reihe. Der Typ steht im Symbol und der Name darunter, und eine `.VBN` hat daneben ein „Play“-Zeichen. Rechts wählen zwei Symbole A: oder B:. Die Titelleiste zeigt das Diskettenformat und die Anzahl der Dateien, und unten wird der freie Platz angezeigt.

| Taste | Was sie tut |
|---|---|
| Pfeile | eine Datei auswählen (↑/↓ eine Reihe) |
| TAB | das nächste Laufwerk: A:, B:, DISK (mit einer M4-Karte) |
| RETURN, ENTER | öffnen: ein Programm startet, eine Datei bekannten Typs öffnet sich in ihrem Programm, andere zeigen ihre Info |
| ^C | auf das nächste Laufwerk kopieren (von DISK: auf A:) |
| ^D | löschen (fragt vorher) |
| ^N | umbenennen |
| ^R | die Disketten neu lesen |
| Maus | Klick auf eine Datei: auswählen, noch einmal: öffnen. Klick auf ein Laufwerk: öffnet es |

- **Menü DATEI:** ÖFFNEN, DATEI-INFO (^I), AUFS NÄCHSTE LAUFWERK, LÖSCHEN, UMBENENNEN, DISKETTEN NEU LESEN, ZURÜCK ZU BASIC.
- **Das Fenster DATEIEN** lässt sich an seinem Titel verschieben und bleibt dort, auch wenn du die Ansicht wechselst.
- **Öffnen nach Typ** (auch im Commander): `.TXT`-Dateien öffnen sich in NOTEPAD, `.MD` in MARKDOWN, `.PIC` und `.LYR` in PAINT, `.VDB` in DATABASE, `.VSH` in SHEET, `.MUS` in MUSIC, das sie gleich abspielt. Das Programm wird auf dem Laufwerk der Datei gesucht, dann auf A:, dann auf B:. Wird es nicht gefunden, erscheint „KEIN PROGRAMM FÜR DIESE DATEI“. Hat das Programm ungespeicherte Änderungen, fragt es zuerst.

## Programme, F2

Modus 0, 16 Farben. Zeigt nur die Programme eines Laufwerks (`.BIN`, `.VBN`, `.BAS`), zuerst A:, als Kacheln in einem 3×3-Raster, mit den weiteren Seiten darunter. Die Seitenzeile beginnt mit dem Laufwerk (`A:`, `B:`). Jedes Programm, das ein Symbol hat, zeigt es auf seiner Kachel. Die ausgewählte Kachel ist weiß.

| Taste | Was sie tut |
|---|---|
| Pfeile | auswählen (↑/↓ eine Reihe. Über den Rand hinaus die nächste oder vorige Seite) |
| RETURN, ENTER | startet das Programm. Läuft es bereits, macht es dort weiter, wo es war |
| ^A | lädt es als Zubehörprogramm (ALS ZUBEHÖR). F5 öffnet es dann |
| ^R | die Diskette neu lesen |
| TAB | das nächste Laufwerk (NÄCHSTES LAUFWERK): A:, B:, DISK. Ein Programm, das von B: gestartet wurde, kehrt zu B: zurück |
| Maus | Klick: auswählen, noch einmal: starten |

**Menü DATEI:** STARTEN, ALS ZUBEHÖR, NÄCHSTES LAUFWERK, DISKETTEN NEU LESEN, ZURÜCK ZU BASIC.

## Commander, F3

Modus 1, zwei Felder mit Dateilisten: A: links, B: rechts. Jedes Feld zeigt in seinem Titel das Format und die Anzahl der Dateien, und unten den freien Platz. Das aktive Feld hat einen dunklen Titel und eine Auswahl.

| Taste | Was sie tut |
|---|---|
| ↑/↓ | auswählen (mit SHIFT: eine Seite) |
| TAB, ←/→ | das andere Feld |
| RETURN, ENTER | öffnen, wie auf dem Schreibtisch. Die Info (Größe, Typ, Ladeadresse, die ersten Bytes) mit ^I |
| ^C | in das andere Feld kopieren, in beliebiger Größe. Gibt es eine Datei mit demselben Namen, fragt es vorher |
| ^D | löschen |
| ^N | umbenennen |
| ^R | beide Disketten neu lesen |
| ^G | das nächste Laufwerk für das aktive Feld: A:, B:, DISK (auch ein Klick auf seinen Titel) |
| Maus | Klick: auswählen, noch einmal: öffnen |

**Menü DATEI:** ÖFFNEN, DATEI-INFO (^I), INS ANDERE FELD KOPIEREN, LÖSCHEN, UMBENENNEN, DISKETTEN NEU LESEN, NÄCHSTES LAUFWERK (^G), FORMATIEREN (DATA), ZURÜCK ZU BASIC.

> FORMATIEREN löscht alle Dateien auf der Diskette des aktiven Feldes. Es fragt vorher.

## DISK: die SD-Karte der M4

Mit einer M4-Karte hat der Schreibtisch ein drittes Laufwerkssymbol, DISK, unter A: und B:, und TAB geht von A: zu B: und zu DISK. Auch die Programme-Ansicht und die Felder des Commanders (^G) erreichen es. Der Titel zeigt den Ordner, in dem du bist, z. B. `DISK:/GAMES/`.

- **Ordner** erscheinen als Ordner (ein Symbol mit Reiter, oder DIR im Commander). RETURN auf einem geht hinein, und `..`, der erste Eintrag, wieder hinauf. In der Programme-Ansicht sind sie auch da, damit du die Programme darin erreichst.
- **Alles wie auf einer Diskette:** Programme starten von dort, Dateien öffnen sich in ihren Programmen, und ^C, ^D und ^N kopieren, löschen und benennen um. Kopien zwischen DISK und einer Diskette gehen bis 16K. Ordner und Dateien haben Namen wie auf dem CPC (8.3: `NAME.EXT`); längere Namen erscheinen nicht.
- **M4.SYS** (auf `vos.dsk`) wird von A: geladen, wenn DISK das erste Mal gebraucht wird.
- **In den Programmen:** OTHER DRIVE (^W in SHEET) geht A: → B: → DISK, und die untere Zeile zeigt `DISK:NAME.TXT`. Die Liste von OPEN zeigt auch die Ordner: RETURN auf einem (oder auf `..`) zeigt diesen Ordner, und SAVE schreibt in den Ordner, aus dem geöffnet wurde. READER schreibt die Karte als `C:` in seinen Adressen.
- **Datenbanken** gehen auch auf DISK: das ^W von DATABASE erreicht es, und STREETS, von der Karte gestartet, hält dort seine STREETS.VDB.
- **Noch nicht:** die SD-Karte wird nicht in V-OS formatiert. V-OS selbst startet weiter von einer Diskette in A: (tippe `|DISC` vor `RUN"VOS"`: mit einer M4-Karte startet der CPC auf der SD-Karte).

## Optionen, F4

Modus 1. Eine Zeile für jede Einstellung. Änderungen wirken sofort. Beim Speichern (RETURN oder ^S) werden sie in `A:SETUP.CFG` geschrieben und gelten auch beim nächsten Start.

| Einstellung | Werte |
|---|---|
| START-ANSICHT | SCHREIBTISCH, PROGRAMME, COMMANDER |
| SPRACHE | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| VERZÖGERUNG | wie lange du eine Taste hältst, bevor sie sich wiederholt: KURZ, MITTEL, LANG |
| WIEDERHOLRATE | LANGSAM, MITTEL, SCHNELL |
| AMX-MAUS | AN, AUS |
| AMX-LESEART | PEGEL (anfangs) oder IMPULSE: wie die Maus gelesen wird. PEGEL zählt jedes Lesen mit Bewegung, IMPULSE nur den Beginn der Impulse. Bewegt sich der Zeiger zu schnell oder zu langsam, versuche die andere |
| HINTERGRUND | BLAU, SCHWARZ, GRÜN, ROT |
| TASTATUREN | EN + SPRACHE, ALLE SECHS (die CONTROL+SHIFT durchgeht) |

| Taste | Was sie tut |
|---|---|
| ↑/↓ | eine Einstellung auswählen |
| ←/→ | den Wert ändern (auch ein Klick auf die Zeile) |
| RETURN, ^S | speichern |

Wenn du die SPRACHE änderst, wird das Sprachpaket sofort von A: geladen. Siehe [Kapitel 4](04-languages.md).

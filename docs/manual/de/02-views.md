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

## Schreibtisch, F1

Modus 1. Ein Fenster DATEIEN zeigt die Dateien eines Laufwerks als Symbole, vier pro Reihe. Der Typ steht im Symbol und der Name darunter, und eine `.VBN` hat daneben ein „Play“-Zeichen. Rechts wählen zwei Symbole A: oder B:. Die Titelleiste zeigt das Diskettenformat und die Anzahl der Dateien, und unten wird der freie Platz angezeigt.

| Taste | Was sie tut |
|---|---|
| Pfeile | eine Datei auswählen (↑/↓ eine Reihe) |
| TAB | das andere Laufwerk |
| RETURN, ENTER | Dateiinfo |
| ^C | auf das andere Laufwerk kopieren |
| ^D | löschen (fragt vorher) |
| ^N | umbenennen |
| ^R | die Disketten neu lesen |
| Maus | Klick auf eine Datei: auswählen, noch einmal: Info. Klick auf ein Laufwerk: öffnet es |

- **Menü DATEI:** STARTEN (startet das ausgewählte Programm), DATEI-INFO, AUF ANDERES LAUFWERK, LÖSCHEN, UMBENENNEN, DISKETTEN NEU LESEN, ZURÜCK ZU BASIC.
- **Das Fenster DATEIEN** lässt sich an seinem Titel verschieben und bleibt dort, auch wenn du die Ansicht wechselst.

## Programme, F2

Modus 0, 16 Farben. Zeigt nur die Programme auf A: (`.BIN`, `.VBN`, `.BAS`), als Kacheln in einem 3×3-Raster, mit den weiteren Seiten darunter. Jedes Programm, das ein Symbol hat, zeigt es auf seiner Kachel. Die ausgewählte Kachel ist weiß.

| Taste | Was sie tut |
|---|---|
| Pfeile | auswählen (↑/↓ eine Reihe. Über den Rand hinaus die nächste oder vorige Seite) |
| RETURN, ENTER | startet das Programm. Läuft es bereits, macht es dort weiter, wo es war |
| ^A | lädt es als Zubehörprogramm (ALS ZUBEHÖR). F5 öffnet es dann |
| ^R | die Diskette neu lesen |
| Maus | Klick: auswählen, noch einmal: starten |

**Menü DATEI:** STARTEN, ALS ZUBEHÖR, DISKETTEN NEU LESEN, ZURÜCK ZU BASIC.

## Commander, F3

Modus 1, zwei Felder mit Dateilisten: A: links, B: rechts. Jedes Feld zeigt in seinem Titel das Format und die Anzahl der Dateien, und unten den freien Platz. Das aktive Feld hat einen dunklen Titel und eine Auswahl.

| Taste | Was sie tut |
|---|---|
| ↑/↓ | auswählen (mit SHIFT: eine Seite) |
| TAB, ←/→ | das andere Feld |
| RETURN, ENTER | Info: Größe, Typ, Ladeadresse, die ersten Bytes |
| ^C | in das andere Feld kopieren, in beliebiger Größe. Gibt es eine Datei mit demselben Namen, fragt es vorher |
| ^D | löschen |
| ^N | umbenennen |
| ^R | beide Disketten neu lesen |
| Maus | Klick: auswählen, noch einmal: Info |

**Menü DATEI:** STARTEN, DATEI-INFO, INS ANDERE FELD KOPIEREN, LÖSCHEN, UMBENENNEN, DISKETTEN NEU LESEN, FORMATIEREN (DATA), ZURÜCK ZU BASIC.

> FORMATIEREN löscht alle Dateien auf der Diskette des aktiven Feldes. Es fragt vorher.

## Optionen, F4

Modus 1. Eine Zeile für jede Einstellung. Änderungen wirken sofort. Beim Speichern (RETURN oder ^S) werden sie in `A:SETUP.CFG` geschrieben und gelten auch beim nächsten Start.

| Einstellung | Werte |
|---|---|
| START-ANSICHT | SCHREIBTISCH, PROGRAMME, COMMANDER |
| SPRACHE | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| VERZÖGERUNG | wie lange du eine Taste hältst, bevor sie sich wiederholt: KURZ, MITTEL, LANG |
| WIEDERHOLRATE | LANGSAM, MITTEL, SCHNELL |
| AMX-MAUS | AN, AUS |
| AMX-LESEART | IMPULSE oder PEGEL: wie die Maus gelesen wird. Bewegt sich der Zeiger nicht richtig, versuche die andere |
| HINTERGRUND | BLAU, SCHWARZ, GRÜN, ROT |

| Taste | Was sie tut |
|---|---|
| ↑/↓ | eine Einstellung auswählen |
| ←/→ | den Wert ändern (auch ein Klick auf die Zeile) |
| RETURN, ^S | speichern |

Wenn du die SPRACHE änderst, wird das Sprachpaket sofort von A: geladen. Siehe [Kapitel 4](04-languages.md).

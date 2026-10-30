# 5. Studio: Programme mit Blöcken

STUDIO ist ein Block-Editor im Stil von Scratch, der auf dem CPC selbst läuft.

- Du baust Sprites und Skripte aus Blöcken.
- Das Programm läuft sofort mit CONTROL+R.
- Es wird ein normales V-OS-Programm (`.VBN`), das auch aus der Ansicht Programme startet.

## Der Bildschirm

Studio nutzt einen „geteilten“ Bildschirm mit zwei Zonen:

- **Oben, in Modus 0 (16 Farben):**
  - **links die Bühne** in halber Größe
  - **rechts das Feld SPRITES:** die Sprites mit ihrer Farbe und Position, die Größe des ausgewählten (W, H), der Hintergrund und der Modus des Programms (z. B. `STAGE 2 M1`) sowie der Dateiname
- **Unten, in Modus 1:**
  - **links die Palette** mit den Blöcken einer Kategorie (`< EVENTS >`)
  - **rechts das Skript**, eine Zeile pro Block
  - **ganz unten die Statuszeile**, mit den Tasten, die dort funktionieren, wo du gerade bist

**TAB** geht vom Skript zur Palette, dann zur Bühne und zurück zum Skript.

## Menüs

| STUDIO | | EDIT |
|---|---|---|
| NEW | ^N | DELETE LINE |
| OPEN (`.VBS`) | ^O | + SPRITE (bis zu 6) |
| SAVE | ^S | − SPRITE |
| SAVE AS | | BACKGROUND (die Farbe der Bühne) |
| RUN | ^R | SCREEN MODE (0 oder 1) |
| IN BACKGROUND | | |
| BACK | ^Q | |

- **RUN (^R):** speichert `NAME.VBS`, schreibt `NAME.VBN` und startet es. Das Programm endet über sein eigenes Menü (PROGRAM > STOP, ^Q), und dann startet Studio wieder mit demselben Programm geöffnet.
- **IN BACKGROUND:** fragt, ob das Programm weiterläuft, wenn es hinter einem anderen oder hinter einer Ansicht liegt, oder pausiert, was die Voreinstellung ist.
- **SCREEN MODE:**
  - **Modus 0:** 16 Farben, 192 Pixel breit.
  - **Modus 1:** 4 Farben (Stifte 0–3), 384 Pixel breit, und mehr Text.

## Die Palette

←/→ wechseln die Kategorie, ↑/↓ wählen einen Block, und RETURN fügt ihn unter der Skriptzeile ein. Ein Klick auf einen Block der Palette tut dasselbe.

Ein Block, der sich öffnet (FOREVER, REPEAT, IF), kommt zusammen mit seinem END hinein und wird zusammen mit ihm gelöscht. Ein Block mit Text fragt sofort nach dem Text.

## Das Skript

| Taste | Was sie tut |
|---|---|
| ↑/↓ | Zeile |
| ←/→ | Feld der Zeile (die Felder sind die Werte im Block) |
| RETURN | ohne ausgewähltes Feld: fügt den Block der Palette ein. Auf einem Textfeld: den Text ändern. Auf einem Tastenfeld: wartet, bis du die Taste drückst |
| CLR | löscht die Zeile |
| DEL | löscht die letzte Ziffer einer Zahl |
| Maus | Klick auf ein Feld: wählt es aus. Zweiter Klick: ändert seine Art |

Das Programm ist eine Liste von Zeilen:

- Jedes `WHEN …` beginnt ein Skript, für ein Sprite oder für die Bühne. Das Skript reicht bis zum nächsten `WHEN`.
- Die Einrückung ergibt sich von selbst aus den Blöcken, die sich öffnen und schließen.
- Zeilen vor dem ersten `WHEN` werden ignoriert.
- Was offen bleibt, wird am Ende des Skripts geschlossen.

### Was in ein Feld kommt

Die Statuszeile sagt immer, was das Feld annimmt.

**Wertfeld:**

| Taste | Wert |
|---|---|
| 0–9, − | Zahl, eine ganze Zahl von −32768 bis 32767 |
| A–H | Variable. Derselbe Buchstabe noch einmal: A1, A2 … A15, und zurück zu A |
| X, Y | die Position des Sprites des Skripts |
| R und Ziffern | RANDOM: eine Zahl von 1 bis n |
| K und eine Taste | KEY: 1, solange sie gedrückt ist, sonst 0 |
| T und eine Ziffer | TOUCHING: 1, wenn das Sprite das Sprite n berührt |
| Z | AT EDGE: 1, wenn das Sprite am Rand der Bühne ist |
| P | BUTTON: die Nummer der zuletzt gedrückten Schaltfläche |
| U | COSTUME: die Nummer des Kostüms des Sprites (0: kein Kostüm) |

**Andere Arten von Feldern:**

- **Variable:** A–H, und derselbe Buchstabe noch einmal für A1…A15.
- **Vergleich:** `<`, `=`, `>`. SPACE ergibt „keiner“, und dann prüft IF nur, ob der erste Wert nicht 0 ist.
- **Sprite** (in den `WHEN`-Blöcken): 0 die Bühne, 1–6 ein Sprite.
- **Taste** (in `WHEN KEY`): RETURN und dann die Taste.
- **Text:** RETURN, und du tippst bis zu 14 Zeichen.
- **Variablengruppe** (SAVE/LOAD VARS): A–H geht zur nächsten Achtergruppe (A-H, A1-H1 … A15-H15), und SPACE ergibt ALL.

Die Buchstaben werden als Tasten gelesen, deshalb funktionieren sie auch mit der griechischen Tastatur.

## Die Bühne und die Sprites

| Taste | Was sie tut |
|---|---|
| Pfeile | bewegen das ausgewählte Sprite |
| 1–6 | ein Sprite auswählen |
| C | nächste Farbe |
| W, H | Breite, Höhe |
| K | welches Kostüm es trägt (keines, 1, 2, …) |
| E | sein Kostüm zeichnen (ein neues, wenn es keines hat) |
| Klick auf die Bühne | setzt das Sprite dorthin |

Ein Sprite ohne Kostüm ist ein farbiges Rechteck.

### Kostüme

**E** öffnet den Kostüm-Editor an der Stelle der Bühne. Er hat ein 16×16-Raster mit den 16 Stiften darunter.

| Taste | Was sie tut |
|---|---|
| Pfeile | Zelle |
| SPACE, RETURN | malt die Zelle |
| 0–9, A–F | Stift |
| `.` | transparent |
| E, TAB | fertig |
| Klick | auf eine Zelle: malt. Auf die Reihe der Stifte: wählt einen Stift |

Ein Programm hat bis zu 8 Kostüme, die alle Sprites gemeinsam nutzen. Ein Sprite mit Kostüm ist 16×16 groß. Auf der Bühne wird x auf ein ganzes Byte gerundet (2 Pixel in Modus 0, 4 in Modus 1).

## Alle Blöcke

In der Spalte „Block“ erscheinen die Felder wie im Skript.

### EVENTS

| Block | Was er tut |
|---|---|
| WHEN START *sprite* | das Skript startet zusammen mit dem Programm |
| WHEN KEY *key* *sprite* | startet, wenn die Taste gedrückt wird |
| WHEN CLICKED *sprite* | startet mit einem Klick auf das Sprite (oder auf die Bühne) |
| WHEN I RECEIVE *n* *sprite* | startet, wenn Nachricht n gesendet wird |
| SEND *n* | sendet Nachricht n (n kann auch eine Variable sein) |

> Eine Nachricht startet jedes Skript, das auf sie wartet, **von vorne**, auch wenn es schon lief. Deshalb sollte ein Skript keine Nachricht an sich selbst senden.

### CONTROL

| Block | Was er tut |
|---|---|
| FOREVER … END | wiederholt für immer |
| REPEAT *n* … END | n-mal |
| IF *a* *comparison* *b* … [ELSE …] END | führt die Zeilen nur aus, wenn der Vergleich zutrifft |
| WAIT *n* | wartet n Frames (50 = eine Sekunde) |
| WAIT UNTIL *a* *comparison* *b* | wartet, bis der Vergleich zutrifft |
| STOP | beendet dieses Skript |

### MOTION

| Block | Was er tut |
|---|---|
| GO TO *x* *y* | das Sprite geht zu x, y |
| CHANGE X *n*, CHANGE Y *n* | bewegt um n |
| SPEED *vx* *vy* | setzt seine Geschwindigkeit |
| MOVE | ein Schritt mit seiner Geschwindigkeit |
| BOUNCE | kehrt am Rand der Bühne die Geschwindigkeit um |

### LOOKS/SOUND

| Block | Was er tut |
|---|---|
| COLOUR *n* | der Stift des Rechtecks |
| COSTUME *n* | trägt Kostüm n (1–8. 0 ändert nichts) |
| NEXT COSTUME | das nächste, und nach dem letzten wieder das erste |
| SHOW, HIDE | |
| PRINT *value* AT *x* *y* | gibt eine Zahl aus |
| NOTE *n* FOR *frames* | spielt eine Note (MIDI-Nummer: 60 = C, 69 = A 440 Hz) und wartet, bis sie zu Ende ist |

### VARIABLES

| Block | Was er tut |
|---|---|
| SET *variable* TO *value* | |
| CHANGE *variable* BY *value* | Addition |
| DECREASE *variable* BY *value* | Subtraktion |
| MULTIPLY *variable* BY *value* | |
| DIVIDE *variable* BY *value* | ganzzahlige Division |
| REMAINDER *variable* BY *value* | der Rest der Division |
| SAVE VARS *group* TO *"name"* | schreibt die Variablen in eine Textdatei (siehe unten) |
| LOAD VARS *group* FROM *"name"* | liest sie zurück |

### WINDOWS

| Block | Was er tut |
|---|---|
| WINDOW *"title"* *width* *height* | ein Fenster in der Mitte der Bühne, wie die Dialoge von V-OS. Ein neues Fenster nimmt den Platz des vorigen und seiner Schaltflächen ein |
| BUTTON *"text"* AT *x* *y* | eine System-Schaltfläche. Sie wird mit einem Klick oder mit TAB und RETURN gedrückt. Die Schaltflächen werden ab 0 nummeriert, in der Reihenfolge, in der sie erscheinen |
| WHEN BUTTON *sprite* | startet, wenn irgendeine Schaltfläche gedrückt wird. Der Wert BUTTON (P) sagt, welche |
| TEXT *"text"* AT *x* *y* | schreibt Text |
| LABEL *button* TO *"text"* | ändert den Text einer Schaltfläche |

Ist ein Fenster offen, zählen TEXT, BUTTON und PRINT ab der linken oberen Ecke seines Inneren. Das Fenster wird an seinem Titel verschoben, zusammen mit seinen Schaltflächen.

## Variablen

Es gibt 128 Variablen, die alle Skripte gemeinsam nutzen, mit den Namen A–H, A1–H1, …, A15–H15. Am Anfang sind alle 0, und sie enthalten ganze Zahlen von −32768 bis 32767.

### Speichern und Wiederherstellen (SAVE VARS, LOAD VARS)

- `SAVE VARS ALL TO "GAME"` schreibt alle 128 in die Datei `GAME.TXT`. Das `.TXT` wird angehängt, wenn der Name keinen Typ hat.
- Mit einer Gruppe (`A-H`, `A1-H1`, …) schreibt es nur diese 8.
- Die Datei ist Text, eine Zeile pro Variable:

  ```
  A=12
  B=0
  A1=-5
  ```

- `LOAD VARS ALL FROM "GAME"` ändert die Variablen, die die Datei nennt. Mit einer Gruppe ändert es nur die, die auch in der Gruppe sind. Zeilen, die es nicht versteht, werden ignoriert, und fehlt die Datei, ändert sich nichts.
- So kann eine Datei alle Variablen wiederherstellen oder nur eine Achtergruppe, z. B. die gespeicherten Positionen eines Spiels.

## Dateien

- **`NAME.VBS`:** das Programm, so wie du es bearbeitest. OPEN öffnet es, und bis zu 5K werden gelesen.
- **`NAME.VBN`:** das startbereite Programm. RUN schreibt es, und es startet auch aus der Ansicht Programme. Es ist der Player (`VBRUN.SYS`) zusammen mit dem Programm. Der Player übersetzt die Blöcke beim Start in Z80-Code, deshalb laufen die Programme schnell.

Eine `.VBS` lässt sich auch aus Text auf dem PC erzeugen, mit `tools/mkvbs.py`. Die Syntax ist am Anfang der Datei beschrieben, und Beispiele sind `blocks/examples/*.vbt` (CALC, MINES, FLAP, TICKER, VARS).

## Grenzen

| | |
|---|---|
| Zeilen (Blöcke) | 240 |
| Sprites | 6 |
| Skripte (`WHEN …`) | 16 |
| Variablen | 128 |
| REPEAT in einem Programm | 64 (darüber hinaus teilen sie sich einen Zähler) |
| Ineinander verschachtelte offene Blöcke | 16 |
| Texte | 32, je bis zu 14 Zeichen |
| Kostüme | 8, 16×16 |
| Schaltflächen | 64 |
| Code | mindestens 4.000 Bytes, auch für das größte Programm. Was nicht hineinpasst, wird ignoriert |

## Tipps

- **Skripte der Bühne:** Die Bewegungs- und Aussehen-Blöcke tun nichts, und X, Y, TOUCHING und AT EDGE ergeben 0.
- **TOUCHING:** trifft nur zu, wenn beide Sprites sichtbar sind.
- **Zeitablauf:** Die Skripte laufen „zusammen“. Jedes Skript gibt seinen Zug am Ende jeder Schleife und bei jedem WAIT ab. Soll ein Skript auf ein anderes warten, nimm eine Variable und `WAIT UNTIL` (siehe MINES).
- **Fertige Beispiele:** CALC, MINES, FLAP und TICKER lassen sich in Studio öffnen (OPEN).

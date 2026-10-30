# 6. Blöcke auf dem PC: der Web-Editor und `vbc.py`

Neben Studio, das auf dem CPC läuft, gibt es auch einen Block-Editor für den PC. Die Sprache ist dieselbe, mit ein paar zusätzlichen Blöcken: Listen, Rauschen, Sprite-Größe, farbiger Text.

## Der Editor

Öffne `blocks/editor.html` in einem Browser. Er basiert auf Blockly und gibt es auf Griechisch oder Englisch.

- **Kategorien:** Ereignisse, Steuerung, Bewegung, Aussehen, Text, Operatoren, Fühlen, Variablen, Listen und Fenster.
- **Sprites:** Rechtecke oder Kostüme. Sie werden in einer Tabelle festgelegt, und die Bühne zeigt sie in den Farben des CPC. Sie lassen sich mit der Maus verschieben.
- **Dateien:** Er öffnet und speichert `.vbp`-Dateien. Sie sind JSON mit dem ganzen Programm, deshalb kann man sie auch von Hand schreiben.

## Übersetzen

```bash
python3 blocks/vbc.py pong.vbp --dsk build/vos.dsk
```

`vbc.py` schreibt `build/NAME.ASM`, mit einem Kommentar für jeden Block. Es assembliert sie mit RASM zu `NAME.VBN`, mit einer Relokationstabelle, damit sie neben anderen Programmen läuft, und mit `--dsk` legt es sie auf die Diskette.

| Option | Was sie tut |
|---|---|
| `-o build` | Ausgabeordner |
| `--asm-only` | nur die `.ASM` |
| `--dsk build/vos.dsk` | auch auf die Diskette |

## Das Format `.vbp`

Die vollständige Beschreibung steht am Anfang von `blocks/vbc.py`: Ereignisse, Befehle, Werte, Kostüme, Symbol. Kurz gesagt:

```json
{"name": "PONG", "mode": 0, "background": 0,
 "sprites": [{"name": "ball", "x": 90, "y": 100, "w": 6, "h": 6,
              "colour": 8, "vx": 2, "vy": 2, "visible": true}],
 "variables": {"score": 0},
 "scripts": [{"sprite": "ball", "when": {"event": "start"},
              "do": [{"block": "forever", "do": [{"block": "move"}, {"block": "bounce"}]}]}]}
```

- **Variablen und Listen:** Sie haben Namen, keine Buchstaben. Listen haben eine feste Höchstlänge.
- **Symbol:** `"icon"` gibt ein Symbol für die Ansicht Programme an.
- **Ein Programm mit vielen ähnlichen Teilen:** Ein Python-Skript kann es schreiben. Siehe `tools/mkbricks.py`, das `bricks.vbp` mit 32 Steinen schreibt.

## Beispiele

In `blocks/examples/`:

| Datei | Programm |
|---|---|
| `pong.vbp` | PONG |
| `catch.vbp` | CATCH |
| `starcat.vbp` | STARCAT: Kostüme, eine Melodie aus einer Liste |
| `counter.vbp` | COUNTER: ein Fenster und Schaltflächen |
| `bricks.vbp` | BRICKS (geschrieben von `tools/mkbricks.py`) |

Die Dateien `*.vbt` sind Studio-Programme als Text, für `tools/mkvbs.py`. Siehe [Kapitel 5](05-studio.md).

## Studio oder Web-Editor?

| | Studio | Web-Editor |
|---|---|---|
| Wo | auf dem CPC | auf dem PC |
| Datei | `.VBS` | `.vbp` |
| Variablen | 128, A–H15 | mit Namen |
| Listen, Rauschen, Sprite-Größe | nein | ja |
| SAVE/LOAD VARS | ja | nein |
| Textstil, `.MUS`-Musik | ja | ja |
| Das Programm | braucht den ganzen Speicher | klein, läuft neben anderen |

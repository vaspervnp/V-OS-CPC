# 6. I blocchi sul PC: l'editor web e `vbc.py`

Oltre a Studio, che gira sul CPC, c'è anche un editor a blocchi per il PC. Il linguaggio è lo stesso, con qualche blocco in più: liste, rumore, dimensione degli sprite, testo colorato.

## L'editor

Apri `blocks/editor.html` in un browser. È basato su Blockly ed è disponibile in greco o in inglese.

- **Categorie:** eventi, controllo, movimento, aspetto, testo, operatori, sensori, variabili, liste e finestre.
- **Sprite:** rettangoli o costumi. Si definiscono in una tabella, e lo stage li mostra con i colori del CPC. Si possono trascinare con il mouse.
- **File:** apre e salva file `.vbp`. Sono JSON con tutto il programma, quindi si possono anche scrivere a mano.

## Compilazione

```bash
python3 blocks/vbc.py pong.vbp --dsk build/vos.dsk
```

`vbc.py` scrive `build/NAME.ASM`, con un commento per ogni blocco. Lo assembla con RASM in `NAME.VBN`, con una tabella di rilocazione perché giri accanto ad altri programmi, e con `--dsk` lo mette sul dischetto.

| Opzione | Cosa fa |
|---|---|
| `-o build` | cartella di uscita |
| `--asm-only` | solo il `.ASM` |
| `--dsk build/vos.dsk` | anche sul dischetto |

## Il formato `.vbp`

La descrizione completa è all'inizio di `blocks/vbc.py`: eventi, comandi, valori, costumi, icona. In breve:

```json
{"name": "PONG", "mode": 0, "background": 0,
 "sprites": [{"name": "ball", "x": 90, "y": 100, "w": 6, "h": 6,
              "colour": 8, "vx": 2, "vy": 2, "visible": true}],
 "variables": {"score": 0},
 "scripts": [{"sprite": "ball", "when": {"event": "start"},
              "do": [{"block": "forever", "do": [{"block": "move"}, {"block": "bounce"}]}]}]}
```

- **Variabili e liste:** hanno nomi, non lettere. Le liste hanno una lunghezza massima fissa.
- **Icona:** `"icon"` dà un'icona per il Launcher.
- **Un programma con molte parti simili:** può scriverlo uno script Python. Vedi `tools/mkbricks.py`, che scrive `bricks.vbp` con 32 mattoni.

## Esempi

In `blocks/examples/`:

| File | Programma |
|---|---|
| `pong.vbp` | PONG |
| `catch.vbp` | CATCH |
| `starcat.vbp` | STARCAT: costumi, una melodia da una lista |
| `counter.vbp` | COUNTER: una finestra e pulsanti |
| `bricks.vbp` | BRICKS (scritto da `tools/mkbricks.py`) |

I file `*.vbt` sono programmi di Studio in forma di testo, per `tools/mkvbs.py`. Vedi il [capitolo 5](05-studio.md).

## Studio o editor web?

| | Studio | editor web |
|---|---|---|
| Dove | sul CPC | sul PC |
| File | `.VBS` | `.vbp` |
| Variabili | 128, A–H15 | con nomi |
| Liste, rumore, dimensione degli sprite | no | sì |
| SAVE/LOAD VARS | sì | no |
| Il programma | ha bisogno di tutta la memoria | piccolo, gira accanto ad altri |

# 6. Blocks on the PC: the web editor and `vbc.py`

Besides Studio, which runs on the CPC, there is also a block editor for the PC. The language is the same, with a few extra blocks: lists, noise, sprite size, colored text.

## The editor

Open `blocks/editor.html` in a browser. It is based on Blockly and comes in Greek or English.

- **Categories:** events, control, motion, looks, text, operators, sensing, variables, lists and windows.
- **Sprites:** rectangles or costumes. They are defined in a table, and the stage shows them in the CPC's colors. They can be dragged with the mouse.
- **Files:** it opens and saves `.vbp` files. They are JSON with the whole program, so they can also be written by hand.

## Compiling

```bash
python3 blocks/vbc.py pong.vbp --dsk build/vos.dsk
```

`vbc.py` writes `build/NAME.ASM`, with a comment for each block. It assembles it with RASM into `NAME.VBN`, with a relocation table so that it runs alongside other programs, and with `--dsk` it puts it on the disk.

| Option | What it does |
|---|---|
| `-o build` | output folder |
| `--asm-only` | only the `.ASM` |
| `--dsk build/vos.dsk` | also onto the disk |

## The `.vbp` format

The full description is at the top of `blocks/vbc.py`: events, commands, values, costumes, icon. In short:

```json
{"name": "PONG", "mode": 0, "background": 0,
 "sprites": [{"name": "ball", "x": 90, "y": 100, "w": 6, "h": 6,
              "colour": 8, "vx": 2, "vy": 2, "visible": true}],
 "variables": {"score": 0},
 "scripts": [{"sprite": "ball", "when": {"event": "start"},
              "do": [{"block": "forever", "do": [{"block": "move"}, {"block": "bounce"}]}]}]}
```

- **Variables and lists:** they have names, not letters. Lists have a fixed maximum length.
- **Icon:** `"icon"` gives an icon for the Launcher.
- **A program with many similar parts:** a Python script can write it. See `tools/mkbricks.py`, which writes `bricks.vbp` with 32 bricks.

## Examples

In `blocks/examples/`:

| File | Program |
|---|---|
| `pong.vbp` | PONG |
| `catch.vbp` | CATCH |
| `starcat.vbp` | STARCAT: costumes, a tune from a list |
| `counter.vbp` | COUNTER: a window and buttons |
| `bricks.vbp` | BRICKS (written by `tools/mkbricks.py`) |

The `*.vbt` files are Studio programs as text, for `tools/mkvbs.py`. See [chapter 5](05-studio.md).

## Studio or web editor?

| | Studio | web editor |
|---|---|---|
| Where | on the CPC | on the PC |
| File | `.VBS` | `.vbp` |
| Variables | 128, A–H15 | with names |
| Lists, noise, sprite size | no | yes |
| SAVE/LOAD VARS | yes | no |
| The program | needs all the memory | small, runs alongside others |

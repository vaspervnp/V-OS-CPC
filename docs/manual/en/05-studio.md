# 5. Studio: programs with blocks

STUDIO is a Scratch-style block editor that runs on the CPC itself.

- You make sprites and scripts out of blocks.
- The program runs at once with CONTROL+R.
- It becomes a normal V-OS program (`.VBN`) that also starts from the Launcher.

## The screen

Studio uses a "split" screen, with two zones:

- **Top, in mode 0 (16 colors):**
  - **left, the stage** at half size
  - **right, the SPRITES panel:** the sprites with their color and position, the size of the selected one (W, H), the background and the program's mode (e.g. `STAGE 2 M1`), and the file name
- **Bottom, in mode 1:**
  - **left, the palette** with the blocks of one category (`< EVENTS >`)
  - **right, the script**, one line per block
  - **at the end, the status line**, with the keys that work where you are

**TAB** goes from the script to the palette, then to the stage, and back to the script.

## Menus

| STUDIO | | EDIT |
|---|---|---|
| NEW | ^N | DELETE LINE |
| OPEN (`.VBS`) | ^O | + SPRITE (up to 6) |
| SAVE | ^S | − SPRITE |
| SAVE AS | | BACKGROUND (the stage's color) |
| RUN | ^R | SCREEN MODE (0 or 1) |
| IN BACKGROUND | | |
| BACK | ^Q | |

- **RUN (^R):** saves `NAME.VBS`, writes `NAME.VBN` and runs it. The program stops from its own menu (PROGRAM > STOP, ^Q), and then Studio starts again with the same program open.
- **IN BACKGROUND:** asks whether the program keeps running when it is behind another one or behind a view, or pauses, which is the default.
- **SCREEN MODE:**
  - **Mode 0:** 16 colors, 192 pixels wide.
  - **Mode 1:** 4 colors (pens 0–3), 384 pixels wide, and more text.

## The palette

←/→ change the category, ↑/↓ choose a block, and RETURN adds it below the script line. A click on a palette block does the same.

A block that opens (FOREVER, REPEAT, IF) goes in together with its END, and is deleted together with it. A block with text asks for the text at once.

## The script

| Key | What it does |
|---|---|
| ↑/↓ | line |
| ←/→ | slot of the line (the slots are the values inside the block) |
| RETURN | with no slot selected: adds the palette block. On a text slot: change the text. On a key slot: waits for you to press the key |
| CLR | deletes the line |
| DEL | deletes the last digit of a number |
| mouse | click on a slot: selects it. Second click: changes its kind |

The program is a list of lines:

- Each `WHEN …` starts a script, for a sprite or for the stage. The script runs up to the next `WHEN`.
- The indentation comes by itself from the blocks that open and close.
- Lines before the first `WHEN` are ignored.
- Anything left open is closed at the end of the script.

### What goes in a slot

The status line always says what the slot accepts.

**Value slot:**

| Key | Value |
|---|---|
| 0–9, − | number, an integer from −32768 to 32767 |
| A–H | variable. The same letter again: A1, A2 … A15, and back to A |
| X, Y | the position of the script's sprite |
| R and digits | RANDOM: a number from 1 to n |
| K and a key | KEY: 1 while it is held down, otherwise 0 |
| T and a digit | TOUCHING: 1 when the sprite touches sprite n |
| Z | AT EDGE: 1 when the sprite is at the edge of the stage |
| P | BUTTON: the number of the last button pressed |
| U | COSTUME: the number of the sprite's costume (0: no costume) |

**Other kinds of slot:**

- **Variable:** A–H, and the same letter again for A1…A15.
- **Comparison:** `<`, `=`, `>`. SPACE gives "none", and then IF only checks that the first value is not 0.
- **Sprite** (in the `WHEN` blocks): 0 the stage, 1–6 a sprite.
- **Key** (in `WHEN KEY`): RETURN and then the key.
- **Text:** RETURN, and you type up to 14 characters.
- **Variable group** (SAVE/LOAD VARS): A–H moves to the next group of eight (A-H, A1-H1 … A15-H15), and SPACE gives ALL.

The letters are read as keys, so they also work with the Greek keyboard.

## The stage and the sprites

| Key | What it does |
|---|---|
| arrows | move the selected sprite |
| 1–6 | select a sprite |
| C | next color |
| W, H | width, height |
| K | which costume it wears (none, 1, 2, …) |
| E | draw its costume (a new one, if it has none) |
| click on the stage | puts the sprite there |

A sprite without a costume is a colored rectangle.

### Costumes

**E** opens the costume editor in place of the stage. It has a 16×16 grid with the 16 pens below it.

| Key | What it does |
|---|---|
| arrows | cell |
| SPACE, RETURN | paints the cell |
| 0–9, A–F | pen |
| `.` | transparent |
| E, TAB | done |
| click | on a cell: paints. On the row of pens: selects a pen |

A program has up to 8 costumes, shared by all sprites. The size of a sprite with a costume is 16×16. On the stage, x is rounded to a whole byte (2 pixels in mode 0, 4 in mode 1).

## All the blocks

In the "Block" column, the slots appear as in the script.

### EVENTS

| Block | What it does |
|---|---|
| WHEN START *sprite* | the script starts together with the program |
| WHEN KEY *key* *sprite* | starts when the key is pressed |
| WHEN CLICKED *sprite* | starts with a click on the sprite (or on the stage) |
| WHEN I RECEIVE *n* *sprite* | starts when message n is sent |
| SEND *n* | sends message n (n can also be a variable) |

> A message starts **from the beginning** every script that waits for it, even if it was already running. That is why a script should not send a message to itself.

### CONTROL

| Block | What it does |
|---|---|
| FOREVER … END | repeats forever |
| REPEAT *n* … END | n times |
| IF *a* *comparison* *b* … [ELSE …] END | runs the lines only if the comparison holds |
| WAIT *n* | waits n frames (50 = one second) |
| WAIT UNTIL *a* *comparison* *b* | waits until the comparison holds |
| STOP | ends this script |

### MOTION

| Block | What it does |
|---|---|
| GO TO *x* *y* | the sprite goes to x, y |
| CHANGE X *n*, CHANGE Y *n* | moves by n |
| SPEED *vx* *vy* | sets its speed |
| MOVE | one step at its speed |
| BOUNCE | at the edge of the stage, reverses the speed |

### LOOKS/SOUND

| Block | What it does |
|---|---|
| COLOUR *n* | the rectangle's pen |
| COSTUME *n* | wears costume n (1–8. 0 changes nothing) |
| NEXT COSTUME | the next one, and after the last one the first again |
| SHOW, HIDE | |
| PRINT *value* AT *x* *y* | prints a number |
| NOTE *n* FOR *frames* | plays a note (MIDI number: 60 = C, 69 = A 440 Hz) and waits for it to finish |

### VARIABLES

| Block | What it does |
|---|---|
| SET *variable* TO *value* | |
| CHANGE *variable* BY *value* | addition |
| DECREASE *variable* BY *value* | subtraction |
| MULTIPLY *variable* BY *value* | |
| DIVIDE *variable* BY *value* | integer division |
| REMAINDER *variable* BY *value* | the remainder of the division |
| SAVE VARS *group* TO *"name"* | writes the variables to a text file (see below) |
| LOAD VARS *group* FROM *"name"* | reads them back |

### WINDOWS

| Block | What it does |
|---|---|
| WINDOW *"title"* *width* *height* | a window in the middle of the stage, like the V-OS dialogs. A new window takes the place of the previous one and its buttons |
| BUTTON *"text"* AT *x* *y* | a system button. It is pressed with a click or with TAB and RETURN. Buttons are numbered from 0, in the order they appear |
| WHEN BUTTON *sprite* | starts when any button is pressed. The BUTTON value (P) says which |
| TEXT *"text"* AT *x* *y* | writes text |
| LABEL *button* TO *"text"* | changes the text of a button |

With a window open, TEXT, BUTTON and PRINT count from the top-left corner of its inside. The window is dragged by its title, together with its buttons.

## Variables

There are 128 variables, shared by all scripts, named A–H, A1–H1, …, A15–H15. At the start they are all 0, and they hold integers from −32768 to 32767.

### Saving and restoring (SAVE VARS, LOAD VARS)

- `SAVE VARS ALL TO "GAME"` writes all 128 to the file `GAME.TXT`. The `.TXT` is added when the name has no type.
- With a group (`A-H`, `A1-H1`, …) it writes only those 8.
- The file is text, one line per variable:

  ```
  A=12
  B=0
  A1=-5
  ```

- `LOAD VARS ALL FROM "GAME"` changes the variables the file mentions. With a group, it changes only those that are also in the group. Lines it does not understand are ignored, and if the file is missing nothing changes.
- So a file can restore all the variables or just one group of eight, e.g. a game's saved positions.

## Files

- **`NAME.VBS`:** the program as you edit it. OPEN opens it, and up to 5K is read.
- **`NAME.VBN`:** the program ready to run. RUN writes it, and it also starts from the Launcher. It is the player (`VBRUN.SYS`) together with the program. The player compiles the blocks to Z80 code when it starts, so programs run fast.

A `.VBS` can also be made from text on the PC, with `tools/mkvbs.py`. The syntax is described at the top of the file, and examples are `blocks/examples/*.vbt` (CALC, MINES, FLAP, TICKER, VARS).

## Limits

| | |
|---|---|
| Lines (blocks) | 240 |
| Sprites | 6 |
| Scripts (`WHEN …`) | 16 |
| Variables | 128 |
| REPEAT in one program | 64 (beyond that they share a counter) |
| Open blocks nested inside each other | 16 |
| Texts | 32, up to 14 characters each |
| Costumes | 8, 16×16 |
| Buttons | 64 |
| Code | at least 4,000 bytes, even for the largest program. Whatever does not fit is ignored |

## Tips

- **Stage scripts:** the motion and looks blocks do nothing, and X, Y, TOUCHING and AT EDGE give 0.
- **TOUCHING:** holds only when both sprites are visible.
- **Timing:** scripts run "together". Each script gives up its turn at the end of every loop and at every WAIT. To make one script wait for another, use a variable and `WAIT UNTIL` (see MINES).
- **Ready-made examples:** CALC, MINES, FLAP and TICKER open in Studio (OPEN).

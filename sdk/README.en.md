# The V-OS SDK: programs in assembly

With this SDK you write your own programs in Z80 assembly. They run inside V-OS like DEMO or CLOCK: they appear in the Launcher, the Desktop and the Commander, and they have their own menu, buttons, dialogs, sound and files. They also run alongside other programs.

## Quick start

```bash
make new-app NAME=hello
```

This creates the folder `myapps/hello/` from `sdk/template/`. It has three files:

- `hello.asm`: the program. The arrows move a box, there is a BEEP button, a seconds counter, and its own menu (ABOUT, BACK) next to VIEW and HELP.
- `texts.txt`: its texts, in English and Greek.
- `icon.txt`: its icon, 16×16, for the Launcher.

```bash
make app NAME=hello
```

This builds `build/HELLO.BIN` and puts it on the disk `build/vos.dsk`.

```bash
make run
```

This opens the disk in Caprice32. HELLO is in the Launcher, on the last page.

- Plain `make` builds all the programs in `myapps/` and puts them on the disk, together with V-OS.
- The name has 1–8 lowercase letters or digits and starts with a letter. It cannot be the name of a V-OS program (e.g. demo).
- You need RASM, Python 3 and iDSK, as for all of V-OS.
- In Caprice32 you run the program yourself, from the Launcher.

A bigger program:

- Put more `.asm` files in its folder (e.g. `art.asm` with sprites) and bring them in with `include "art.asm"`. The build finds them, and rebuilds the program when they change.
- Whatever you put in the subfolder `disc/` (e.g. `disc/LEVEL1.DAT`) goes onto the disk as it is, for `VOS_LOAD`.
- With a subfolder `owndisc/`, the program also gets a disk of its own, `build/<name>.dsk`, with the `.BIN` and the files of `owndisc/`. It stays off `vos.dsk`. You put it in B: and run it from the Launcher (TAB, the other drive). Which drive it was started from, so that it loads its files from there, is in `VOS_SELF`: `db drive`, then its name (11 bytes).
- **A file to open (version 14):** when RETURN in the Desktop or the Commander opens a file in your program, `VOS_OPEN` (`#B000`) holds `db 1, drive, 11-byte name` (0: none). Read it in `init`, with A = 0 and also with A = 2 (the program was already running), then write 0 there. The types and their programs are in the kernel's `ft_open` table (`src/kernel/files_ext.asm`).
- A program with a relocation table (like those of the SDK) can be up to 12K. For the rest, load files into the data bank.

## How a program works

A program is a `.BIN`, built for `VOS_APP_ADDR` (`#4000`). It starts like this:

```
        include "api/vos_api.inc"
        org VOS_APP_ADDR
        jp init                 ; +0
        jp event                ; +3  HL -> the event
        jp redraw               ; +6
        db "VA", VOS_API_VERSION
        include "app_icon.asm"  ; +12 the icon (optional)
```

- **`init`** sets mode, palette, menu and buttons, turns on `VE_FRAME` if needed, and draws everything.
  - A = 0: a fresh start.
  - A = 2: the program returns from a view or another program. Its state is as it left it; it sets the above again and draws.
- **`event`** is called for each event and returns immediately. A program never waits on its own (no wait loop). For motion or time, `VOS_TICKS` with A = 1, and then a `VE_FRAME` arrives 50 times a second.
- **`redraw`** redraws everything, e.g. when the language changes or the desk accessory closes.
- **Exit:** `VOS_EXIT`, which returns to the view that started it.

### The order inside `event`

```
event:  ld a,(hl)
        cp VE_FRAME : jp z,frame        ; the frames
        push hl
        call VOS_UI_EVENT               ; menus, buttons, CONTROL+letter
        pop hl
        or a : jr nz,command            ; A = the command
        call VOS_MENU_OPEN : ret nz     ; menu open: the keys are its own
        ...                             ; your own keys and clicks
command: ...
        jp VOS_COMMAND                  ; whatever is not yours (VIEW, HELP)
```

**While a menu is open, do not draw.** Otherwise you will draw over it. On `VE_FRAME`, update the state, but draw only if `VOS_MENU_OPEN` gives Z. Dialogs (`VOS_DIALOG`, `VOS_INPUT`, `VOS_FILE_PICK`) have their own loop, so no event arrives while they are open.

### The events

`HL` → 8 bytes: `db type, code, char, mods; dw x, y`.

| type | what | code / char / x, y |
|---|---|---|
| `VE_KEY_DOWN` 1, `VE_KEY_REPEAT` 3, `VE_KEY_UP` 2 | key | code = key number (`VK_*`, keyboard row·8 + bit), char = the character in the pack's language |
| `VE_PTR_DOWN` 5, `VE_PTR_UP` 6, `VE_PTR_MOVE` 4 | pointer | x, y in pixels of the mode |
| `VE_FRAME` 8 | frame (with `VOS_TICKS`) | — |
| `VE_LANG` 7 | the keyboard language changed | — |

### Three kinds of program

- **With a relocation table (the SDK default):** `make app` builds it twice, at `#4000` and at `#4100`. `tools/mkreloc.py` adds the table from the difference.
  - It runs alongside other programs, in the 12K from `#5000`, and continues where it stopped (F6 shows the running programs).
  - Its data must be inside its own bytes (labels, `ds`), never at fixed addresses.
  - If `mkreloc.py` gives an error, an address is used somewhere in a way that does not survive relocation. E.g. `ld a,label & 255`, or only the low byte of an address.
- **Without a table:** it takes the whole bank (up to 16K, code and data), but runs only on its own, unless there is a memory expansion. This needs your own rule in the Makefile (see `STUDIO.BIN`).
- **Desk accessory:** up to 4K, with a table. It opens with F5 on top of anything, and `init` gets A = 1. See `apps/clock/clock.asm` and the description in `src/api/vos_api.inc`.

### Rules

- **Registers:** calls corrupt all registers except IX. Arguments go in A, BC, DE, HL (IX for `VOS_RECT` and `VOS_BLIT`). Results return in A or HL. On failure, carry is set and A = error number, which `VOS_ERROR` displays.
- **Memory:** do not page another bank in at `#4000`, because the program will vanish from under you. For 16K more there is the data bank (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). It is shared with views and other programs, and keeps its data only while the program is running.
- **Coordinates:** x in pixels of the mode (mode 0: 0–191, mode 1: 0–383), y from 0 to 258. The menu bar takes y 0–11.
- **RASM:** labels are not case-sensitive (`BOX` and `box` are the same). Hex is written with `#` and not with `&`.

## The data formats

- **Menu bar** (`VOS_SET_BAR`): `db count; dw menu, ...`. The shared VIEW and HELP come from `VOS_MENU_VIEW` and `VOS_MENU_HELP`.
- **Menu:** `db title, count` and for each item `db text, command, letter, 0`.
  - text: `VOS_SEPARATOR` for a line
  - command: 1.., what `VOS_UI_EVENT` returns
  - letter: CONTROL+letter shortcut, or 0
- **Buttons** (`VOS_SET_WIDGETS`, then `VOS_DRAW_WIDGETS`): `db count`, and for each button `dw x, y; db width in characters, text, command, 0`.
- **Dialog** (`VOS_DIALOG` → A = button, 0 the first, ESC gives the last): `db title, text, number of buttons (1–3), button, ...`. For buttons, `VM_OK`, `VM_YES` and `VM_NO`.
- **Texts** (`VOS_TEXTS`): made by `tools/mktexts.py` from `texts.txt`, with lines `NAME | English | Greek`.
  - It gives `T_NAME` (`VT_FIRST` = `#C0` and up) and the table `texts:`. Up to 64 texts.
  - A `|` with no spaces around it starts a new line in dialogs.
  - Texts go wherever a "text" is asked for (menus, buttons, dialogs). With `VOS_MSG` you get their address for `VOS_PRINT`.
- **Palette** (`VOS_PALETTE`): 17 firmware colors (0–26): 16 pens and the border. In mode 1, pens 0–3 count.
- **Rectangle** (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`.
- **Icon:** 16 lines of 16 characters in `icon.txt`. Each character is a pen in hex (mode 0, Launcher palette) or `.` for transparent.
- **File names** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`): 11 bytes, `"NAME    EXT"`. Drive 0 = A:, 1 = B:.

## The API (version 17)

| Call | Input → output | What it does |
|---|---|---|
| `VOS_EXIT` | — | end, back to the view that started it |
| `VOS_TICKS` | A = 1 / 0 (+ `VOS_PTR_KEYS`) | `VE_FRAME` 50 times a second, or none. With `VOS_PTR_KEYS` (2) the arrows and COPY also move the pointer and click |
| `VOS_FRAMES` | → HL (and A bits 16–23) | frames since startup |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = command | the shared commands of VIEW and HELP (6–19). Number your own commands from `VC_APP` (32) up, or a VIEW or HELP item runs one of yours |
| `VOS_ERROR` | A = error | error dialog |
| `VOS_MODE` | A = 0 / 1 | mode 0 (192×259, 16 pens) or 1 (384×259, 4 pens) |
| `VOS_PALETTE` | HL → 17 colors | |
| `VOS_CLS` | A = pen | clears the screen |
| `VOS_PLOT` | HL = x, DE = y, A = pen | one pixel |
| `VOS_RECT` | IX → rectangle | filled rectangle |
| `VOS_COLOURS` | A = text pen (+ `VOS_BOLD`, `VOS_ITALIC`, `VOS_UNDERLINE`), C = background | for `VOS_PRINT` and `VOS_CHAR`. The styles are made from the same font, for every language |
| `VOS_PRINT` | HL = x, DE = y, BC → text, 0 | |
| `VOS_CHAR` | HL = x, DE = y, A = character | |
| `VOS_MSG` | A = text → HL | the address of a text (`T_*` or a system one) |
| `VOS_SET_BAR`, `VOS_DRAW_BAR` | HL → menu bar | |
| `VOS_UI_EVENT` | (the current event) → A | menu, button or shortcut command, 0 for none |
| `VOS_DIALOG` | HL → dialog → A | |
| `VOS_INPUT` | A = title, HL → text, C = maximum → carry if cancelled | text input (needs C + 2 bytes) |
| `VOS_SET_WIDGETS`, `VOS_DRAW_WIDGETS` | HL → buttons | |
| `VOS_MENU_VIEW`, `VOS_MENU_HELP` | → HL | the shared menus |
| `VOS_CATALOG` | A = drive → A = files, HL → list | 16 bytes each: 11 the name, at +12 the size in K. With A = drive + `VOS_CAT_EXT` and HL → `"EXT"`, only the files with that extension |
| `VOS_FILE_PICK` | A = title → A = file, carry if cancelled | picker dialog, after `VOS_CATALOG` |
| `VOS_LOAD` | A = drive, HL → name, DE = where → BC = length | |
| `VOS_SAVE` | A = drive, HL → name, DE = from, BC = length | binary file, replacing the old one |
| `VOS_DELETE` | A = drive, HL → name | |
| `VOS_TEXTS` | HL → text table | the program's texts |
| `VOS_MENU_OPEN` | → NZ if a menu is open | |
| `VOS_KEY_HELD` | A = key → NZ while pressed | for games |
| `VOS_BLIT` | IX → `dw x, y; db bytes, lines; dw source; db source stride` | image: pairs (mask, pixels) |
| `VOS_SOUND` | A = channel 0–2, HL = period (bit 15: noise), C = volume 0–15, B = frames | a note; 440 Hz is period 142 |
| `VOS_SPLIT` | HL → `dw y1, y2; db 8 colors` (0 = turns off) | mixed screen: mode 0 between y1 and y2 |
| `VOS_RUN` | A = drive, HL → name | runs another program, and then this one starts again |
| `VOS_KEEP` | → HL → 16 bytes | memory that stays between programs |
| `VOS_BANK_GET`, `VOS_BANK_PUT` | HL = from, DE = to, BC = bytes | copy from and to the data bank |
| `VOS_BACKGROUND` | A = 1 / 0 | keeps running or freezes when behind another |
| `VOS_DRAG` | HL = x, DE = y, BC = w, A = h → carry: new HL, DE | dragging a window by its title |
| `VOS_FIT` | same → HL, DE | brings a window inside the screen |
| `VOS_EXT` | A = a `VX_*` call, BC, DE, HL as it wants → A, HL, C, DE, carry | the calls after the table (version 15): `VX_VERSION` → A = API, HL = V-OS version (BCD). `VX_FREE` C = drive → A = free K. Unknown: carry `VX_CLIP_PUT` HL = text, BC = bytes → the clipboard (up to 1K). `VX_CLIP_GET` DE = where, BC = room → HL = size (version 16). `VX_M4` HL → a command for the M4 board (db size, dw command, data), DE → the response, BC = bytes; carry: no M4 board (version 17). |

Full details, e.g. on the background, the accessory and `VOS_SPLIT`, are in `src/api/vos_api.inc`. For examples, see `apps/demo/demo.asm` (mode 0, motion), `apps/clock/clock.asm` (accessory) and `apps/mixed/mixed.asm` (mixed screen). A whole game with sprites, a stage from a file and sound is `myapps/vrouves/`.

An AI assistant writing a program should read [`AI.md`](AI.md): the same rules, shorter, with the traps of RASM and of the data bank.

## Testing

`make test-sdk` builds the template as TEMPLATE.BIN and opens it from the Launcher in Caprice32, with key presses defined by `src/kernel/test_script.asm` (script 15). It takes screenshots in `build/shots`: its screen, the box after it moves, its menu, the ABOUT dialog, and the return to the Launcher.

For your own automated test, copy script 15 and the `test-sdk` target of the Makefile.

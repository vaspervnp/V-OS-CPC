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

This builds `build/HELLO.BIN` and puts it on the programs' disk, `build/apps.dsk`. `make run` puts that in B:; in the Launcher, TAB shows B:.

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
- With a subfolder `owndisc/`, the program also gets a disk of its own, `build/<name>.dsk`, with the `.BIN` and the files of `owndisc/`. It stays off `apps.dsk`. You put it in B: and run it from the Launcher (TAB, the other drive). Which drive it was started from, so that it loads its files from there, is in `VOS_SELF`: `db drive`, then its name (11 bytes).
- **A file to open (version 14):** when RETURN in the Desktop or the Commander opens a file in your program, `VOS_OPEN` (`#B000`) holds `db 1, drive, 11-byte name` (0: none). Read it in `init`, with A = 0 and also with A = 2 (the program was already running), then write 0 there. The types and their programs are in the kernel's `ft_open` table (`src/kernel/files_ext.asm`).
- A program with a relocation table (like those of the SDK) runs beside others when it is up to 12K; a bigger one (up to 16K) runs on its own without a memory expansion, like one without a table (MARKDOWN, READER). For the rest, load files into the data bank.

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
- **Memory:** do not page another bank in at `#4000`, because the program will vanish from under you. For 16K more there is the data bank (`VOS_BANK_GET`, `VOS_BANK_PUT`, `VOS_DATA`). It is shared with views and other programs, and keeps its data only while the program is running. With a memory expansion (API 21) each program gets one of its own, which keeps what is in it until the program ends, whatever runs meanwhile; `VX_DATA` says which (A = 1: its own).
- **Coordinates:** x in pixels of the mode (mode 0: 0–191, mode 1: 0–383, mode 2: 0–767), y from 0 to 258. The menu bar takes y 0–11.
- **RASM:** labels are not case-sensitive (`BOX` and `box` are the same). Hex is written with `#` and not with `&`.

## The data formats

- **Menu bar** (`VOS_SET_BAR`): `db count; dw menu, ...`. The shared VIEW and HELP come from `VOS_MENU_VIEW` and `VOS_MENU_HELP`.
- **Menu:** `db title, count` and for each item `db text, command, letter, 0`.
  - text: `VOS_SEPARATOR` for a line
  - command: 1.., what `VOS_UI_EVENT` returns
  - letter: CONTROL+letter shortcut, or 0
- **Buttons** (`VOS_SET_WIDGETS`, then `VOS_DRAW_WIDGETS`): `db count`, and for each button `dw x, y; db width in characters, text, command, 0`.
- **Dialog** (`VOS_DIALOG` → A = button, 0 the first, ESC gives the last): `db title, text, number of buttons (1–3), button, ...`. For buttons, `VM_OK`, `VM_YES` and `VM_NO`.
- **Texts** (`VOS_TEXTS`): made by `tools/mktexts.py` from `texts.txt`, with lines `NAME | English | Greek`. Both columns are written in UTF-8 and become bytes of the V-OS character set (`tools/voscs.py`), which holds Greek and the Latin letters of French, Spanish, German and Italian.
  - It gives `T_NAME` (`VT_FIRST` = `#C0` and up) and the table `texts:`. Up to 64 texts.
  - A `|` with no spaces around it starts a new line in dialogs.
  - Texts go wherever a "text" is asked for (menus, buttons, dialogs). With `VOS_MSG` you get their address for `VOS_PRINT`.
- **Palette** (`VOS_PALETTE`): 17 firmware colors (0–26): 16 pens and the border. In mode 1, pens 0–3 count.
- **Rectangle** (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`.
- **Icon:** 16 lines of 16 characters in `icon.txt`. Each character is a pen in hex (mode 0, Launcher palette) or `.` for transparent. The Launcher reads it from the disc: while the program runs, the 256 bytes after "IC" are free for buffers (PAINT keeps its rows there).
- **File names** (`VOS_LOAD`, `VOS_SAVE`, `VOS_DELETE`, `VOS_RUN`): 11 bytes, `"NAME    EXT"`. Drive 0 = A:, 1 = B:.

## The API (version 22)

| Call | Input → output | What it does |
|---|---|---|
| `VOS_EXIT` | — | end, back to the view that started it |
| `VOS_TICKS` | A = 1 / 0 (+ `VOS_PTR_KEYS`) | `VE_FRAME` 50 times a second, or none. With `VOS_PTR_KEYS` (2) the arrows and COPY also move the pointer and click |
| `VOS_FRAMES` | → HL (and A bits 16–23) | frames since startup |
| `VOS_RANDOM` | → A | 0–255 |
| `VOS_COMMAND` | A = command | the shared commands of VIEW and HELP (6–19). Number your own commands from `VC_APP` (32) up, or a VIEW or HELP item runs one of yours |
| `VOS_ERROR` | A = error | error dialog |
| `VOS_MODE` | A = 0 / 1 / 2 | mode 0 (192×259, 16 pens), 1 (384×259, 4 pens) or 2 (768×259, 2 pens, 96 text columns; version 25). In mode 2 menus and dialogs draw in pen 1 on pen 0: pen 0 white and pen 1 black give black text on white paper (NOTEPAD, MARKDOWN, READER, SHEET with ^M) |
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
| `VOS_CATALOG` | A = drive → A = files, HL → list | 16 bytes each: 11 the name, at +12 the size in K, at +13 1 for a folder (drive 2). With A = drive + `VOS_CAT_EXT` and HL → `"EXT"`, only the files with that extension |
| `VOS_FILE_PICK` | A = title → A = file, carry if cancelled | picker dialog, after `VOS_CATALOG` |
| `VOS_LOAD` | A = drive, HL → name, DE = where → BC = length | |
| `VOS_SAVE` | A = drive, HL → name, DE = from, BC = length | binary file, replacing the old one. With A + `VOS_LOAD_IX` (#40, version 20) its header says it loads at IX, not at DE (a `.SCR`: IX = #C000) |
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
| `VOS_EXT` | A = a `VX_*` call, BC, DE, HL as it wants → A, HL, C, DE, carry | the calls after the table (version 15), below |

**Drives:** 0 = A:, 1 = B:, 2 = DISK, the SD card of an M4 board (version 28), in the folder the Desktop or the Commander last went into. File calls and `VX_FREE` work there as on a disc (8.3 names; without an M4 board: carry, A = 35). Databases (`VX_DB`) work there too (version 29). From version 29, `VOS_CAT_EXT` keeps the folders, and `VOS_FILE_PICK` goes into a folder chosen (or `..`) and lists it as the last `VOS_CATALOG` asked, so what it returns is always a file, in the folder now. `VX_DRIVE` C = drive → A = the next one (A: → B: → DISK with an M4 board → A:), for an OTHER DRIVE command; `src/api/vos_drive.inc` has `vos_next_drive` (A: ↔ B: on an older V-OS) and `vos_drive_text` (`A:`, `B:`, `DISK:`).

**The `VOS_EXT` calls:** `VX_VERSION` → A = API, HL = V-OS version (BCD). `VX_FREE` C = drive → A = free K. Unknown: carry `VX_CLIP_PUT` HL = text, BC = bytes → the clipboard (up to 1K). `VX_CLIP_GET` DE = where, BC = room → HL = size (version 16). `VX_M4` HL → a command for the M4 board (db size, dw command, data), DE → the response, BC = bytes; carry: no M4 board (version 17); HL = 0: BC bytes of the M4 ROM's `sock_info` to DE, 16 a socket (its status, its last command, the bytes received, an ip and a port; socket 0 is C_NETHOSTIP's, its ip the name looked up) (version 32; TELNET waits on it). `VX_MEM` → HL = the RAM in K, DE = the K free for programs (version 18). `VX_BEHIND` DE → db drive, 11-byte name of a file: its program (by type) starts behind this one, with `init` A = 3 and the file in `VOS_OPEN` (version 19; MUSIC knows it). `VX_DATA` → A = 1 if the data bank is the program's own (memory expansion), 0 if it is the shared bank 4 (version 21; NOTEPAD keeps text up to 16K this way). `VX_DB` C = a `DB_*` call, DE, HL → a database (version 22, below). `VX_UTF8` HL → text, BC = bytes, E = 0 in the program's memory or `VOS_DATA` in its data bank: if it is UTF-8 (from a PC or the web), it becomes the V-OS character set there → BC = bytes now, A = 1; A = 0: it was not UTF-8 and stays as it was (version 23; NOTEPAD and READER do this). `VX_CALC` C = a `CALC_*` call, DE → a block, HL → text → formulas and numbers (version 24, below). `VX_LANG` → HL = the code of the language V-OS shows (`"EN"`, `"EL"`, `"FR"`…; L the first letter) (version 26; VBRUN shows the translations of Studio's programs this way). `VX_IRQ` HL = a routine of the program → the kernel calls it once a frame from the interrupt, in front or behind, with its bank there and interrupts off; 0 stops it, and so does the program's end; carry: not for an accessory or a program alone in bank 5 (version 27; MUSIC plays its songs this way, so they do not stop while another program loads or draws). It must be short, keep IY, EXX and AF', write only its own memory and the AY, and call nothing of V-OS. `VX_PRINT` HL → text, BC = bytes, E = 0 in the program's memory or `VOS_DATA` in its data bank → to the printer (the CPC's Centronics port, 7 bits), as it is: 13, 10 end a line, 12 starts a new page; the letters over 127 go out as plain ASCII (accents left out, Greek as Greeklish: Θ 8, Ξ 3, Ψ 4); carry, A = 41: the printer stayed busy for two seconds (none, off line, no paper) (version 30; NOTEPAD, SHEET and DATABASE print with ^P). After 60 lines a new page begins by itself; BC = 0 with HL → a file's 11-byte name (as `VOS_CATALOG` gives it) starts a printout whose pages begin with a heading, `NOTES.TXT  PAGE 2`; HL = 0: no headings (version 31). `VX_VIEW` HL → dw x, y, w, h: from then on the program draws with (0, 0) at (x, y) and nothing outside that rectangle (cut to the screen): `VOS_CLS` fills it, `VOS_RECT` is cut to it, a point, a character (each of `VOS_PRINT`) or a `VOS_BLIT` image is drawn only if all of it is inside; menus, dialogs and the bar are not affected; HL = 0: none; set it again after `VOS_MODE` and in `redraw` (it ends when another program comes to the front); carry: no memory expansion (version 33; the first step towards programs in windows, docs/WINDOWS.md). `VX_WINDOW` HL → dw w, h: the program in a window on the desk, its inside w × h (w a multiple of 8) as its view and its pointer events with x, y from it; call it first in init, each time (A = 2 too: that is how the windows behind are drawn again, through their init); its title moves it, X ends it, + or F7 make it full screen and back, a click on another brings that one to the front with its bar; mode 1, the theme's colours; carry: no memory expansion or no `WM.SYS` on A: (full screen as before; version 34). From version 35 `VX_WINDOW` writes back at HL the size its inside has now (full screen: the screen under the bar), so init lays out what it shows for it; the bottom right corner resizes it (and init is called again with A = 2); with `VOS_BACKGROUND` the program draws in its window from behind too, while none covers it (`VOS_CLS`, `PLOT`, `RECT`, `COLOURS`, `PRINT`, `CHAR`, `BLIT`; not `VOS_MSG`). Examples: `apps/clock`, `myapps/sysinfo`. From version 36 HL points to dw w, h, x0, y0: the window shows the part of the program's screen from x0, y0 (0, 0: as before), so a program made for the whole screen draws as it did, its widgets and events going with it (e.g. `dw 376, 232, 0, 12` in `myapps/telnet`); a program with version 36 in its header always gives all four. One that calls it outside init draws its bar again after it (`VOS_DRAW_BAR`). From V-OS 0.49 a window behind that has a copy of itself (taken while nothing covered it) is copied back instead: its init is not called then, so a program must not count on being called to draw while behind; one that goes on in the background (`VOS_BACKGROUND`) draws as before while uncovered. The Desktop's files window and drive icons are among the windows too (0.50): up to eight windows in all. With w = 0 (V-OS 0.48) the program leaves the windows: its window goes (carry), and it sets its mode and palette and draws full screen, as for a mode 2 page; asking again later brings the window back where it was, as large as it was. The size written back lets a program lay itself out for its window: NOTEPAD, MARKDOWN, READER and SHEET (`set_mode`) take w / 8 columns and as many rows as fit, again at each resize, and leave the windows for their page (^M).

### Databases (version 22)

`VOS_EXT` with A = `VX_DB` and C = a `DB_*` call works on a database: a file `NAME.VDB` of 1K pages, as big as the disc allows (up to 255K). It holds up to 8 tables; a table has up to 10 fields, text (up to 255 characters) or a number (2 bytes), and may have a key field (text up to 64 characters, or a number) with an index, so that FIND is fast. A record is its fields one after the other; its id (rid) is a 16-bit number. One database is open at a time, for the program that opened it. Each call writes its changes to the disc before it returns. The kernel loads the engine, `DB.SYS`, from drive A: the first time.

| Call | In → out |
|---|---|
| `DB_CREATE`, `DB_OPEN` | DE → db drive, 11-byte name (`"STREETS VDB"`); OPEN → A = 1: Latin-1 (of V-OS 0.15) |
| `DB_CLOSE` | |
| `DB_TABLE` | DE → name (8), fields, key field (0: none), then each field: name (8), type, length → A = table |
| `DB_USE` | E = the table the calls below use |
| `DB_INFO` | E = table, HL → 124 bytes: its descriptor → A = tables |
| `DB_ADD` | HL → record → DE = rid |
| `DB_GET`, `DB_PUT` | DE = rid, HL → the record |
| `DB_DEL` | DE = rid |
| `DB_FIND` | HL → key as in a record (room for a record), E = bytes that count (0: all) → DE = the first record with that key or after it |
| `DB_FIRST`, `DB_LAST`, `DB_NEXT`, `DB_PREV` | HL → room for the record, or 0 → DE = rid, in key order; carry at the end |
| `DB_COUNT` | → HL = records |

Errors: carry and A (`DB_ERR_*`, and the disc's errors), which `VOS_ERROR` shows. Text is kept as it is typed, in the V-OS character set, the same in every language: one database can hold Greek, French and German together. Only a database of V-OS 0.15 with Latin letters (Latin-1) is different: `DB_OPEN` then gives A = 1; show `DB_ERR_ALPHABET` with `VOS_ERROR`. Sorting and FIND compare bytes: in a `DB_TEXT` key capitals and small letters, and accented ones, are different. A `DB_ALPHA` field (type 2, from version 23) is text like `DB_TEXT`, but as a key it is sorted and found without case or accents: ΕΛΕΝΗ, Ελένη and ελένη, or Élodie and ELODIE, are the same; the record keeps the text as it was typed. Examples are STREETS (`myapps/streets`), a street index, and DATABASE (`myapps/database`), a whole database program with tables, a list and a form; `tools/vdb.py` shows and checks a `.VDB` file on the PC.

### Formulas (version 24)

`VOS_EXT` with A = `VX_CALC` and C = a `CALC_*` call works out formulas, as a spreadsheet does. The kernel loads the engine, `CALC.SYS`, from drive A: the first time. A number is 32 bits, in hundredths (1234 is 12.34), from -21474836.46 to 21474836.46. A formula has `+ - * /`, brackets, numbers (`12`, `3.5`, `.25`; a third decimal rounds), cells (`A1` to `Z255`) and the functions SUM, AVG, MIN, MAX, COUNT (of values, cells and ranges such as `B2:D9`, between `,` or `;`), ABS(x), INT(x) (down to a whole number) and ROUND(x) or ROUND(x, 0–2), in capitals or not. Products and quotients are rounded to the hundredth.

DE → the program's block, `CB_SIZE` (10) bytes: `CB_RESULT` (a number, 4 bytes), `CB_COLS`, `CB_ROWS`, `CB_GRID` (dw), `CB_BANK`, `CB_AT`. The cells are a grid of the program's: `CB_COLS` × `CB_ROWS` numbers of 4 bytes, row after row, at `CB_GRID`, in its data bank when `CB_BANK` = `VOS_DATA`. A cell `CALC_NONE` has no number (empty, or text: 0 in `+ - * /`, left out by the functions); `CALC_BAD` has an error.

| Call | In → out |
|---|---|
| `CALC_EVAL` | HL → formula, 0 (`=` first or not) → `CB_RESULT` and DE:HL (DE high) |
| `CALC_NUMBER` | HL → text: only a number? → as `CALC_EVAL` |
| `CALC_TEXT` | `CB_RESULT` → text at HL (13 bytes of room: `-12.5`), A = its length |
| `CALC_CELL` | HL → text: a cell (`b12`) at its start? → D = column, E = row (from 0), A = its characters |

Errors: carry and A (`CALC_ERR_*`: 30 a wrong formula, 31 division by zero, 32 a number too big, 33 a cell outside the grid, 34 a cell it uses has an error, 29 `CALC.SYS` is not on A:), which `VOS_ERROR` shows; then `CB_RESULT` = `CALC_BAD` and `CB_AT` = where in the text. The example is SHEET (`myapps/sheet`), a spreadsheet that keeps its values in its data bank and works the formulas out again after each change.

Full details, e.g. on the background, the accessory and `VOS_SPLIT`, are in `src/api/vos_api.inc`. For examples, see `apps/demo/demo.asm` (mode 0, motion), `apps/clock/clock.asm` (accessory) and `apps/mixed/mixed.asm` (mixed screen). A whole game with sprites, a stage from a file and sound is `myapps/vrouves/`.

An AI assistant writing a program should read [`AI.md`](AI.md): the same rules, shorter, with the traps of RASM and of the data bank.

## Testing

`make test-sdk` builds the template as TEMPLATE.BIN and opens it from the Launcher in Caprice32, with key presses defined by `src/kernel/test_script.asm` (script 15). It takes screenshots in `build/shots`: its screen, the box after it moves, its menu, the ABOUT dialog, and the return to the Launcher.

For your own automated test, copy script 15 and the `test-sdk` target of the Makefile.

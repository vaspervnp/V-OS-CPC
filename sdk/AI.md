# V-OS SDK: instructions for AI assistants

You are writing a program for **V-OS**, a windowed operating system for the Amstrad CPC 6128 (Z80, 4 MHz, 128K, optional 512K expansion). Programs are Z80 assembly, assembled with **RASM**, and talk to V-OS only through the API in `src/api/vos_api.inc`. This file is the short, strict version of `sdk/README.en.md` (human guide) plus the traps found while writing the programs in `myapps/`. When the two disagree, `src/api/vos_api.inc` wins.

## 1. Start and build

```bash
make new-app NAME=myprog      # myapps/myprog/: myprog.asm, texts.txt, icon.txt (from sdk/template)
make app NAME=myprog          # build/MYPROG.BIN (+ relocation table), onto build/apps.dsk
make run                      # Caprice32, build/vos.dsk in A:, build/apps.dsk in B:; Launcher, TAB
```

- NAME: 1–8 lowercase letters/digits, starting with a letter, not the name of a V-OS program.
- Plain `make` builds every `myapps/*` too.
- Extra `.asm` files in the program's folder can be `include`d by name; the build tracks them.
- `myapps/<name>/disc/*` are copied as they are onto `build/apps.dsk` (data files for `VOS_LOAD`).
- `myapps/<name>/owndisc/` instead gives the program **its own disc**, `build/<name>.dsk` (the `.BIN` plus the files of `owndisc/`), and keeps it off `apps.dsk`. The Launcher shows drive B: with TAB.
- Every disc given out must fit a real 3" disc (180 blocks of 1K): `tools/dsk_ext.py --fit` stops the build otherwise. `apps.dsk` has about 70K free; anything bigger goes on its own disc.

## 2. The shape of a program

```asm
        include "api/vos_api.inc"
        org VOS_APP_ADDR
        jp init                 ; +0  A = 0 new start, 2 back to the front (state kept), 1 accessory
        jp event                ; +3  HL -> 8 bytes: db type, code, char, mods; dw x, y
        jp redraw               ; +6  draw everything again (language change, accessory closed)
        db "VA", VOS_API_VERSION
        include "app_icon.asm"  ; +12, from icon.txt (made by the build)
init:   ; VOS_TEXTS, VOS_MODE, VOS_PALETTE, VOS_SET_BAR, VOS_SET_WIDGETS, VOS_TICKS ... then draw
event:  ld a,(hl)
        cp VE_FRAME : jp z,frame
        push hl : call VOS_UI_EVENT : pop hl
        or a : jp nz,command    ; a menu item, button or CONTROL+letter: A = its command
        call VOS_MENU_OPEN : ret nz
        ...                     ; your keys (VE_KEY_DOWN / VE_KEY_REPEAT) and clicks (VE_PTR_*)
command: ...                    ; yours, then: jp VOS_COMMAND (the shared VIEW and HELP menus)
```

Rules that are easy to break:

- **Never loop waiting for input or time.** `event` handles one event and returns. For time, `VOS_TICKS` A = 1 gives `VE_FRAME` 50 times a second; keep state in variables.
- **Do not draw while a menu is open** (`VOS_MENU_OPEN` → NZ), also in `VE_FRAME`. Dialogs (`VOS_DIALOG`, `VOS_INPUT`, `VOS_FILE_PICK`) run their own loop and return.
- **On `init` with A = 2** set mode, palette, bar, widgets and `VOS_TICKS` again and redraw from your state. Do not reset the state.
- **Number your commands from `VC_APP` (32) up** (`CMD_NEW equ VC_APP + 1`). The VIEW and HELP menus send 6–19 to your `command`; a command of yours with one of those numbers runs when the user picks SWITCH LANGUAGE, KEYS or ABOUT V-OS. (NOTEPAD, PAINT and VROUVES had this bug.)
- **Exit** with `VOS_EXIT` (e.g. from a BACK item with shortcut `"Q"`).
- **Registers:** every call may change all registers except IX. If you use IX or IY yourself, save them around code that the kernel interrupts or calls (`push ix` / `pop ix`). Arguments: A, BC, DE, HL; IX for `VOS_RECT` and `VOS_BLIT`. Errors: carry set, A = error number, show it with `VOS_ERROR`.
- **Event `char`** is the character in the keyboard's language (lowercase letters by default); `code` is the key number (`VK_*`, row·8 + bit). Check `code` for arrows, DEL (`VK_DEL`), CLR (16), RETURN; check `char` for letters. In tests and harnesses a letter's `code` is non-zero; `VK_UP` is 0.

## 3. Memory

- A program with a relocation table (the SDK default) gets **at most 12K** (48 pages from `#5000`), **code and data together**. Its `ds` buffers are inside the file, so they count, and the `.BIN` on disc is that big too. It is the code without the table that must fit: check `build/myapp_<name>/lo.bin` ≤ 12288.
- All data must be labels in your own bytes. Never use fixed addresses in `#4000–#7FFF`. Absolute addresses are fixed up by the table; `label & 255` or other halves of an address break relocation (`mkreloc.py` stops with an error).
- **The data bank** (16K, bank 4): `VOS_BANK_GET` / `VOS_BANK_PUT` (HL from, DE to, BC bytes, both addresses `#4000–#7FFF` of that bank), `VOS_LOAD` / `VOS_SAVE` with `drive + VOS_DATA`. It is **shared**: views and other programs overwrite it while you are behind them. Use it only for things you can load again (e.g. a level file, reloaded in `init` with A = 2), never as the only copy of the user's work. With a RAM expansion (API 21) each program has a data bank of its own instead, taken at its first data call (while two banks are free), which keeps its contents until the program ends: `VOS_EXT` with `A = VX_DATA` returns A = 1 then, 0 for the shared bank 4. Rely on the bank only after A = 1.
- The screen is not yours to read; keep your own copy of anything you need to redraw.

## 4. Data formats

- Menu bar: `db count; dw menu, ...` (fill the VIEW/HELP slots from `VOS_MENU_VIEW` / `VOS_MENU_HELP`).
- Menu: `db title, count`, then per item `db text, command, letter, 0` (`VOS_SEPARATOR` for a line; letter = CONTROL+letter shortcut or 0).
- Buttons: `db count`, then per button `dw x, y; db width_in_chars, text, command, 0`.
- Dialog: `db title, text, buttons (1–3), button, ...` with `VM_OK`, `VM_YES`, `VM_NO` → A = button index (0 = first, ESC = last).
- Texts: `texts.txt`, lines `NAME | English | Greek`, UTF-8, stored in the V-OS character set (`tools/voscs.py`: ASCII; 128..255 ISO 8859-7 with the Latin letters of FR ES DE IT in its free codes; `´` is stored as `΄` #B4, `µ` as `μ` #EC; no `ÿ Œ œ`); the build makes `T_NAME` and `texts:` (≤ 64 texts). `|` without spaces = new line in a dialog. Dialog lines ≤ 20 characters; mode 0 has 24 columns, mode 1 has 48.
- `VOS_MSG` A = text → HL → the text in the current language. Trick for language-dependent data: a text `LANG | E | G` tells you which language is on.
- Rectangle (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`. Blit (`VOS_BLIT`, IX →): `dw x, y; db bytes, rows; dw source; db stride`, source = (mask, pixels) byte pairs per row; x rounds down to a byte (2 pixels in mode 0, 4 in mode 1).
- Mode 0 pixels in a byte: left pixel bits 7,3,5,1 (pen bits 0..3), right pixel bits 6,2,4,0. Both pixels in pen p: see `pen_bytes` in `myapps/paint/paint.asm`.
- File names: 11 bytes `"NAME    EXT"`; drive 0 = A:, 1 = B:, 2 = DISK, the SD card of an M4 board (API 28: `VOS_CATALOG`/`LOAD`/`SAVE`/`DELETE` and `VX_FREE` work there, in the folder the Desktop or Commander last went into; its catalog lists folders too, byte 13 = 1; 8.3 names; no M4 board: carry, A = 35). The M4 code is `M4.SYS` (src/kernel/m4.asm), loaded into bank 7 from A: on first use; databases too from API 29 (kernel/ext2.asm: dk_* with db_drive 2 open the file, C_SEEK to page * 1024 and read or write 8 pieces of 128 bytes; a new page is written past the end with FatFS mode #93, open always, which also grows the file in the 1984 emulator). API 29: `VOS_CAT_EXT` keeps the folders and `VOS_FILE_PICK` goes into a folder chosen, catalogs it again with the last `VOS_CATALOG`'s arguments (kept in GAP1+796..799) and reopens, so it always returns a file; `VX_DRIVE` C = drive → A = next (A: → B: → DISK if an M4 board → A:); include `src/api/vos_drive.inc` for `vos_next_drive` (falls back to `xor 1`) and `vos_drive_text` ("DISK:" for 2).
- Icon: `icon.txt`, 16 rows of 16 hex pens (Launcher palette) or `.`. The Launcher reads it from the disc, so while the program runs the 256 bytes at `VOS_APP_ADDR + VOS_ICON + 2` are free RAM for buffers that need no initial value (`icon_ram` in `myapps/paint`). Use `equ`s based on `VOS_APP_ADDR` so they relocate.

## 5. API versions 12 to 22

- `VOS_SELF` (an address, `#8800`): `db drive, 11-byte name` of the running program. Read it in `init` (A = 0) to load your files from your own drive.
- `VOS_CATALOG` with `A = drive + VOS_CAT_EXT` and `HL -> "EXT"`: the catalog keeps only that extension; `VOS_FILE_PICK` then lists only those files.
- `VOS_TICKS` with `A + VOS_PTR_KEYS`: the cursor keys and COPY also drive the pointer (for drawing programs without a mouse). Without it a program's cursor keys are its own.
- `VOS_COLOURS` with `A = pen + VOS_BOLD / VOS_ITALIC / VOS_UNDERLINE` (version 13): styled text from the normal font, in every language. A run of one style is one `VOS_COLOURS` and one `VOS_PRINT`; clear long empty areas with `VOS_RECT`, which is much faster than printing spaces (`myapps/markdown`).
- `VOS_OPEN` (`#B000`, version 14): `db 1, drive, 11-byte name` when RETURN in the Desktop or Commander opened a file in your program. Check it in `init` for A = 0 **and** A = 2 (it may already be running; ask about unsaved work first), then write 0. See `open_arg` in `myapps/notepad`. New types go in `ft_open` in `src/kernel/files_ext.asm`.
- `VOS_EXT` (version 15): the jump table is closed; new calls go through `VOS_EXT` with A = a `VX_*` number (`VX_VERSION`, `VX_FREE`, …) and the arguments in BC, DE, HL. Check `VOS_API_VERSION` ≥ 15 first. In the kernel, a call is a `dw` in `xa_table` (`src/kernel/api.asm`); one that lives in the extension (bank 7, `files_ext.asm`) cannot see the program's memory and takes HL from `xa_hl`. `myapps/sysinfo` uses both kinds.
- The M4 board (version 17): `VX_M4` sends a command packet (HL: db size, dw command, data; size counts the command and the data, including a string's 0) and copies BC bytes of the response to DE (db size, dw command, then the data from +3). The commands are in spinpoint.org/cpc/m4info.txt; HTTP only. The kernel finds the M4 ROM and maps it at `#C000` only while copying, with interrupts off. See `myapps/webget` (C_NETSTAT, C_HTTPGETMEM, C_COPYBUF). Caprice32 has no M4: test the logic in the Python harness, the real thing in CPCEMU.
- `VX_MEM` (version 18): HL = the RAM in K (128, and 64 for each block of a RAM expansion), DE = the K still free for programs in bank 5 and the expansion banks. `myapps/sysinfo` shows both.
- `VX_BEHIND` (version 19): DE -> `db drive, 11-byte name` of a file; soon after (in the main loop) the kernel starts the file's program, by type as the Desktop opens it, behind the caller, or finds it running. Its `init` gets A = 3 with the file in `VOS_OPEN`: draw nothing, ask nothing, take the file, call `VOS_BACKGROUND` with A = 1 (`myapps/music`). It goes through the data bank (what the caller kept there is lost) and needs room beside the caller (a RAM expansion, for most). Studio's MUSIC block uses it (`rt_music` in `blocks/runtime.asm`).
- `VOS_SAVE` with `A = drive + VOS_LOAD_IX` (#40, version 20; with `VOS_DATA` too, from the data bank): the file's header says it loads at IX instead of DE. A CPC screen (`.SCR`, 16K, mode 0 160×200, line L at `(L >> 3) * 80 + (L & 7) * #800`, the palette in the unused bytes from `#07D0`) is saved with IX = #C000; build it in the data bank with `VOS_BANK_PUT` (`export` in `myapps/paint`). RASM's `/` is not integer division in such address sums: use `>>`.
- `VX_DATA` (version 21): -> A = 1 if the data bank is the program's own (a RAM expansion; it keeps its contents while other programs and views run), 0 if it is the shared bank 4. NOTEPAD uses it to keep up to 16K of text: a 4K window in its memory, the rest in the bank (`myapps/notepad`, `win_go`).
- `VX_DB` (version 22): databases. `VOS_EXT` with A = `VX_DB`, C = a `DB_*` call (`src/api/vos_api.inc`), DE and HL as it says. One `NAME.VDB` file open at a time, for the program that opened it: up to 8 tables, each up to 10 fields (`DB_TEXT` up to 255 bytes, `DB_NUMBER` 2 bytes), fixed-length records (the fields one after the other, text padded by the program, e.g. with spaces), an optional key field with an index. `DB_OPEN` gives error 7 (`DB_ERR_NO_FILE`) when there is no file: then `DB_CREATE`, `DB_TABLE`. `DB_USE` picks the table for the calls after it. `DB_FIND` takes a key laid out as in a record and the number of its bytes that count (a prefix), and returns the record into the same buffer: give it room for a whole record. `DB_NEXT`/`DB_PREV` go on from the table's cursor (`DB_FIND`, `DB_FIRST`, `DB_LAST` set it) in key order; carry and `DB_ERR_END` at the end. Every call writes to the disc before it returns (slow on a floppy: do not call it every frame). Text is stored as typed, in the V-OS character set (any mix of languages); `DB_OPEN` returns A = 1 only for a database of V-OS 0.15 with Latin-1 text (H_ALPHABET 1): show `DB_ERR_ALPHABET` (28) with `VOS_ERROR`. Comparisons are by byte (case and accents count) for `DB_TEXT` keys; a `DB_ALPHA` field (type 2, version 23) is text whose index ignores case and accents (Greek and Latin: ΕΛΕΝΗ = ελένη, Élodie = ELODIE; `src/db/fold.inc` from `tools/voscs.py fold`). Examples: `myapps/streets` (small), `myapps/database` (tables of any fields from DB_INFO, a list that scrolls with DB_NEXT/DB_PREV from the cursor at its last row, a form; its test `tools/database_check.py` stubs the API and reads the screen back as text, a good pattern for testing a program). Tests: `make test-db` (the engine in a Z80 emulator), `make test-db-disc` (with the kernel's file system on a DSK image); `tools/vdb.py dump|check` reads a `.VDB` on the PC.
- `VX_UTF8` (version 23): HL → text, BC = bytes, E = 0 (program memory) or `VOS_DATA` (its data bank). If the text is valid UTF-8 with at least one character over 127, it is converted in place to the V-OS set (unknown characters `?`, the BOM dropped) → BC = new length, A = 1; otherwise A = 0 and nothing changes. Call it after loading a file a PC or the web may have written (NOTEPAD, READER). Before API 23 `VOS_EXT` returns carry and BC is unchanged, so the call is safe. The conversion code is `src/kernel/utf8.asm` (test: `make test-utf8`); on the PC `tools/voscv.py` converts files to and from V-OS.
- A program with a relocation table over 12K (up to 16K) no longer fails on a 6128: it runs alone at `#4000`, like one without a table (`app_place` in `src/kernel/ext.asm`); with a memory expansion it gets a bank of its own.
- Mode 2 (version 25): `VOS_MODE` with A = 2: 768×259, pens 0 and 1 (higher pens wrap), 96 text columns (x a multiple of 8). Menus, dialogs and the pointer draw in pen 1 on pen 0: set pen 0 white (26) and pen 1 black (0) for paper. The kernel draws mode 2 from the same tables as 0 and 1 (`src/gfx/gfx.asm`: `gfx_mode2`). Not with `VOS_SPLIT`. A full screen of 96-column text is slow to redraw: fill the empty end of a row with one `VOS_RECT`, not spaces (NOTEPAD's `row_rest`). The page view of NOTEPAD, MARKDOWN, READER and SHEET (^M) is the example.
- `VX_CALC` (version 24): formulas. `VOS_EXT` with A = `VX_CALC`, C = `CALC_EVAL`, `CALC_NUMBER`, `CALC_TEXT` or `CALC_CELL`, DE → a 10-byte block (`CB_*` in `src/api/vos_api.inc`), HL → text (0 at its end, 127 characters at most). Numbers are 32-bit hundredths, low byte first (12.34 = 1234); `CALC_NONE` (#80000000: empty or text) and `CALC_BAD` (#80000001: an error) are no numbers. Cells in a formula are read from the caller's grid (`CB_COLS` × `CB_ROWS` × 4 bytes at `CB_GRID`, in the data bank with `CB_BANK` = `VOS_DATA`): the program keeps the values there and works the formulas out again itself (SHEET: numbers first, then passes over the formulas until nothing changes, at most 10; cells that still change, which use each other, become `CALC_BAD`). After an error `CB_RESULT` is `CALC_BAD` and `CB_AT` where the text went wrong. The decimal point is `.`; an argument list takes `,` or `;`. Example: `myapps/sheet`; tests: `make test-calc-sys` (the engine against a Python model, `tools/calc_check.py`) and `make test-sheet-z80` (`tools/sheet_check.py` runs a program with the real engine in a second emulator: copy the block, the text and the grid across for each call).
- `VX_LANG` (version 26): `VOS_EXT` with A = `VX_LANG` → HL = the code of the language V-OS shows ("EN", "EL", "FR", "ES", "DE", "IT"; L the first letter). A program's own `VOS_TEXTS` table still has English and one other language; VBRUN uses `VX_LANG` for Studio programs, whose `.VBS` (version 4) keeps their texts in all six languages after the costumes (db 0, or 6 and per language dw code, 32 texts of 16 bytes; an empty one keeps the program's own). In `.vbt`: `LANG FR`, then lines `"text" "translation"` (`tools/mkvbs.py`).
- `VX_IRQ` (version 27): `VOS_EXT` with A = `VX_IRQ`, HL = a routine of the program: the kernel calls it once a frame from the interrupt (in front or behind, paused or not) with the program's bank at #4000, interrupts off and a 94-byte stack of its own. It must be short (a few scan lines), keep IY, EXX and AF' of the interrupted code, write only its own memory and the AY, and call no V-OS function. HL = 0 stops it; the program's end stops it too; one program's at a time. Carry: an accessory, or a program running alone in bank 5. A disc transfer keeps interrupts off (16 ms a sector), so the routine waits then. `myapps/music` (`irq_play`) plays its song this way and falls back to `VE_FRAME` on an older V-OS (carry).
- Keyboards: every pack holds all five pack keyboards; CONTROL+SHIFT goes EN → the pack's → (with Setup's KEYBOARDS = ALL SIX, `CFG_KBDS` 1) the other four. `char` in key events is already in the keyboard in use; a program needs nothing for this.
- Kernel room: the kernel (#0000-#3DFF) has 11 bytes free and bank 7's extension 5 (M75): both are full (its clipboard and program slots after its code are not in VOS.BIN: `xb_detect` empties them at boot, so its image can stay at #8000, which `bank_put` needs). New kernel code that does not run a program's code goes in `src/kernel/ext2.asm`, in base RAM bank 1 at `EXT2_ADDR` (free after boot), called with `ext2_call`; it may call kernel routines that map banks and come back with `ram_home`. The test scripts live there too (`test_inject` maps it from the interrupt). Bank 1 before it: `VOS_SPLIT`'s setting at `LOW_ADDR` (#4000, where the loader was; `boot_x` moves it there). Bank 1 after it: `CALC.SYS` from `CALC_ADDR` (#4F00; the largest test build of `ext2` must end below it, an assert says so), `DB.SYS` from `DB_ADDR` (#5800), its cache of 4 pages from #7000: the bank is full. Bank 7: the language pack (up to 6K), `M4.SYS` at #5800 (up to 1.5K), the Commander's lists, `ENGLISH.MSG` (up to 2.5K), the extension. VX_PRINT (`prt_entry`) and its ASCII table are in `ext2` too. With a RAM expansion, `wm_bank` (the bank before the desk picture's) holds `gfx/view.asm` (`VX_VIEW`), called with `wm_call`; and `WM.SYS` (the windows, M74) from `WM_SYS_ADDR` (#4200), loaded by `boot_x`. The test discs of Caprice32 are full (the V-OS file system has 180 blocks; files past block 179 on a 42-track image fail): `CALC.SYS` is only on SHEET's (`TEST_SCRIPT` 32), and a program under test goes last, on A:, or on its own disc in B:.
- `VX_VIEW` (version 33): `VOS_EXT` with A = `VX_VIEW`, HL → dw x, y, w, h: the program then draws with (0, 0) at (x, y), clipped to that rectangle (cut to the screen); `VOS_CLS` fills it, `VOS_RECT` is cut, `VOS_PLOT`, `VOS_CHAR`, each character of `VOS_PRINT` and `VOS_BLIT` only when all inside. HL = 0 ends it; so does the program's end or another program in front (set it again in `redraw`), and after `VOS_MODE` set it again (pixels of the mode). Carry: no memory expansion. The kernel's `api_*` entries copy the arguments into `vw_*` (GAP2 + 700) and call `wm_call`; with no view they go straight to `gfx_*` as before. `make test-view` (`apps/viewt`, `tools/view_check.py`).
- `VX_WINDOW` (version 34): `VOS_EXT` with A = `VX_WINDOW`, HL → dw w, h, first thing in init, every time (A = 0 and A = 2): the program runs in a window on the desk (WM.SYS, `src/wm/wm.asm`, in `wm_bank` at `WM_SYS_ADDR`), its inside w × h as its view, its pointer events with x, y from that inside. The windows behind are drawn again through their programs' init with A = 2, so init must draw everything, its bar included (`VOS_DRAW_BAR`), and nothing that waits. Its title moves it, X ends it (`api_end`), + or F7 full screen (`wm_on` = 2, no view) and back; a click on another brings that program to the front (`app_wake`, as F6). Mode 1, the theme's colours; no `VOS_PALETTE`, no widgets yet. Version 35: the size the inside has now is written back at HL (bank_put into the program's bank; full screen: the screen under the bar, as a view), so init lays out for it; the frame's bottom right corner resizes (`wm_resize`, then everything again through init). With `VOS_BACKGROUND`, a program whose window no window in front of it covers draws there from behind: `bg_find` (kernel/ext.asm) calls `wm_bg`, which sets its view and opens `VOS_CLS`..`VOS_CHAR` and `VOS_BLIT` (not `VOS_MSG`: texts are the front program's), and puts the front one's view and text colours back after. Examples: `apps/clock`, `myapps/sysinfo` (they lay out for the size they get). Carry: no memory expansion or no WM.SYS on A: (it runs full screen). In test scripts, `view_start` sets `ptr_keys_on` to 0: set COPY as the button again (line #80) after a program starts, and drag with the cursor keys (`ui_drag` needs `EV_PTR_MOVE`). `make test-wm` (`apps/wint`, `tools/wm_check.py`).
- Setup's THEME (CFG_THEME, SETUP.CFG version 4): DARK swaps the UI pens after `ui_set_mode` (`ui_dark` in ext2: bar <-> text, selection <-> its text, shadow = bar, frame = text), so a program's menus, dialogs and file lists from V-OS follow it; its own drawing keeps its own colours. BACKGROUND (CFG_WALL drive, CFG_WALL_NAME): a `.SCR` in `wall_bank`, the last bank of a RAM expansion, which `boot/expand.asm` keeps out of `bk_list` (so programs have 16K less of an expansion); `shell/wall.asm` (in the Desktop) loads it, maps a PAINT mode 0 picture onto the four Desktop pens and draws it centred (8 bytes, 36 lines in).
- The clipboard (version 16): `VX_CLIP_PUT` (HL = text, BC = bytes, 1K kept) and `VX_CLIP_GET` (DE = where, BC = room; BC = 0 gives the size in HL). Text uses LF between lines, as NOTEPAD and MARKDOWN keep it. Selection, cut and paste: `sel_range`, `sel_delete`, `do_paste` in `myapps/notepad`. Key events carry the mods at +3: `VMOD_SHIFT`, `VMOD_CONTROL`.
- `VOS_BACKGROUND` A = 1: you keep getting `VE_FRAME` behind other views and programs; every other call does nothing there (`MUSIC` uses this to keep playing).

The full table of calls is in `sdk/README.en.md` and `src/api/vos_api.inc`.

## 6. RASM traps (all of these happened)

- Hex is `#C000`, not `&C000` (`&` is AND).
- Labels are **case-insensitive**: `sel_bg` and `SEL_BG` collide, so does a routine and a constant.
- Reserved words cannot be labels: `label`, `save`, `stop`, `lx`, `ly`, `hx`, `hy` (register halves), and other directives. Pick names like `print_lab`, `save_file`, `stop_song`, `lnx`.
- **Operator precedence**: `CW / 2 * CH` did not give `(CW / 2) * CH`. Always use parentheses in expressions with `/` and `*`.
- `jr` reaches ±127 bytes; use `jp` when RASM says "relative offset too far".
- Local labels start with `.` and belong to the last global label.
- After an error RASM may write a short `.BIN`; read `build/myapp_<name>/rasm.log`.

## 7. Hardware notes

- The AY sound chip is reached through the PPI, which the keyboard scan also uses every interrupt. Write AY registers only with interrupts off, and keep bit 6 of register 7 at 0 (port A input) or the keyboard dies. `VOS_SOUND` is the simple way; `myapps/music` shows direct AY output (the Arkos AKM player from the interrupt with `VX_IRQ`, or between `di` / `ei` on `VE_FRAME`).
- Players or routines that move SP must run with interrupts off.

## 8. Testing

- **Off the emulator first.** Load `build/myapp_<name>/lo.bin` at `#4000` in a Python Z80 (`pip install z80`; `z80.Z80Machine`), put a breakpoint and `RET` on each API entry (`#0108 + 3·n`), emulate the calls you need (files in a dict, `VOS_BANK_*` on a bytearray, `VOS_MSG` from your `texts` table), call `init` and `event` and check your variables. Label addresses come from `rasm … -s -sl` (a `.sym` file). This finds most logic bugs in seconds.
- **Then Caprice32**, headless, with a key script: add `IF TEST_SCRIPT == n` to `src/kernel/test_script.asm` (keys as `dw from_frame, to_frame : db row, bitmask`) and a `test-…` target like `test-paint` in the Makefile; screenshots land in `build/shots/<delay>/`. The delay counts typed Z keys, about 2.5–3.5 frames each, so take a few shots around the moment you want.
- Look at every screenshot. Check: nothing drawn over menus, the right pens, text not overflowing, the program returns to the Launcher with ^Q.

## 9. Documentation

Every change to V-OS updates `README.md`, `docs/REQUIREMENTS.md`, the manual in six languages (`docs/manual/`, `docs/manual/<code>/`), `sdk/README*.md` when the API changes, and the PDFs (`make docs`). Comments in code are English, short, like the existing code; each file starts with a block saying what it does.

## 10. Examples to copy from

| Program | Shows |
|---|---|
| `sdk/template/app.asm` | the minimum: mode 1, menu, button, dialog, counter |
| `myapps/notepad` | text editing, cursor, files through the data bank, `VOS_CAT_EXT`, `VOS_INPUT` |
| `myapps/streets` | a database (`VX_DB`): a table with a key, `DB_FIND` with a prefix, `DB_NEXT`, `DB_ADD`, `DB_DEL` |
| `myapps/paint` | mode 0 pixels, `VOS_BLIT`, pointer drawing with `VOS_PTR_KEYS`, flood fill, layers |
| `myapps/vrouves` | a game: sprites, stage files on its own disc, 25 Hz logic, save file, high scores |
| `myapps/markdown` | a parser that keeps its place, text styles, word wrap, a page drawn in runs |
| `myapps/reader` | MARKDOWN's page shared through `include` (`page.asm`, `page_data.asm`, `PV_LINKS`; call `pv_new` for a new text), paragraphs, scroll checkpoints, links with TAB, pages from the web with `VX_M4` |
| `myapps/music` | direct AY output, a third-party player, relocating loaded data, background playing |
| `apps/clock` | a desk accessory |
| `apps/mixed` | the mixed mode 0 / mode 1 screen (`VOS_SPLIT`) |

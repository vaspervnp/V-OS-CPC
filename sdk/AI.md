# V-OS SDK: instructions for AI assistants

You are writing a program for **V-OS**, a windowed operating system for the Amstrad CPC 6128 (Z80, 4 MHz, 128K, optional 512K expansion). Programs are Z80 assembly, assembled with **RASM**, and talk to V-OS only through the API in `src/api/vos_api.inc`. This file is the short, strict version of `sdk/README.en.md` (human guide) plus the traps found while writing the programs in `myapps/`. When the two disagree, `src/api/vos_api.inc` wins.

## 1. Start and build

```bash
make new-app NAME=myprog      # myapps/myprog/: myprog.asm, texts.txt, icon.txt (from sdk/template)
make app NAME=myprog          # build/MYPROG.BIN (+ relocation table), onto build/vos.dsk
make run                      # Caprice32 with build/vos.dsk; the program is in the Launcher
```

- NAME: 1–8 lowercase letters/digits, starting with a letter, not the name of a V-OS program.
- Plain `make` builds every `myapps/*` too.
- Extra `.asm` files in the program's folder can be `include`d by name; the build tracks them.
- `myapps/<name>/disc/*` are copied as they are onto `build/vos.dsk` (data files for `VOS_LOAD`).
- `myapps/<name>/owndisc/` instead gives the program **its own disc**, `build/<name>.dsk` (the `.BIN` plus the files of `owndisc/`), and keeps it off `vos.dsk`. The Launcher shows drive B: with TAB.
- The V-OS disc is nearly full (a few K free). Anything big goes on its own disc.

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
- **The data bank** (16K, bank 4): `VOS_BANK_GET` / `VOS_BANK_PUT` (HL from, DE to, BC bytes, both addresses `#4000–#7FFF` of that bank), `VOS_LOAD` / `VOS_SAVE` with `drive + VOS_DATA`. It is **shared**: views and other programs overwrite it while you are behind them. Use it only for things you can load again (e.g. a level file, reloaded in `init` with A = 2), never as the only copy of the user's work.
- The screen is not yours to read; keep your own copy of anything you need to redraw.

## 4. Data formats

- Menu bar: `db count; dw menu, ...` (fill the VIEW/HELP slots from `VOS_MENU_VIEW` / `VOS_MENU_HELP`).
- Menu: `db title, count`, then per item `db text, command, letter, 0` (`VOS_SEPARATOR` for a line; letter = CONTROL+letter shortcut or 0).
- Buttons: `db count`, then per button `dw x, y; db width_in_chars, text, command, 0`.
- Dialog: `db title, text, buttons (1–3), button, ...` with `VM_OK`, `VM_YES`, `VM_NO` → A = button index (0 = first, ESC = last).
- Texts: `texts.txt`, lines `NAME | English | Greek`; the build makes `T_NAME` and `texts:` (≤ 64 texts). `|` without spaces = new line in a dialog. Dialog lines ≤ 20 characters; mode 0 has 24 columns, mode 1 has 48.
- `VOS_MSG` A = text → HL → the text in the current language. Trick for language-dependent data: a text `LANG | E | G` tells you which language is on.
- Rectangle (`VOS_RECT`, IX →): `dw x, y, w, h; db pen`. Blit (`VOS_BLIT`, IX →): `dw x, y; db bytes, rows; dw source; db stride`, source = (mask, pixels) byte pairs per row; x rounds down to a byte (2 pixels in mode 0, 4 in mode 1).
- Mode 0 pixels in a byte: left pixel bits 7,3,5,1 (pen bits 0..3), right pixel bits 6,2,4,0. Both pixels in pen p: see `pen_bytes` in `myapps/paint/paint.asm`.
- File names: 11 bytes `"NAME    EXT"`; drive 0 = A:, 1 = B:.
- Icon: `icon.txt`, 16 rows of 16 hex pens (Launcher palette) or `.`.

## 5. API versions 12 and 13

- `VOS_SELF` (an address, `#8800`): `db drive, 11-byte name` of the running program. Read it in `init` (A = 0) to load your files from your own drive.
- `VOS_CATALOG` with `A = drive + VOS_CAT_EXT` and `HL -> "EXT"`: the catalog keeps only that extension; `VOS_FILE_PICK` then lists only those files.
- `VOS_TICKS` with `A + VOS_PTR_KEYS`: the cursor keys and COPY also drive the pointer (for drawing programs without a mouse). Without it a program's cursor keys are its own.
- `VOS_COLOURS` with `A = pen + VOS_BOLD / VOS_ITALIC / VOS_UNDERLINE` (version 13): styled text from the normal font, in every language. A run of one style is one `VOS_COLOURS` and one `VOS_PRINT`; clear long empty areas with `VOS_RECT`, which is much faster than printing spaces (`myapps/markdown`).
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

- The AY sound chip is reached through the PPI, which the keyboard scan also uses every interrupt. Write AY registers only with interrupts off, and keep bit 6 of register 7 at 0 (port A input) or the keyboard dies. `VOS_SOUND` is the simple way; `myapps/music` shows direct AY output (Arkos AKM player between `di` / `ei`).
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
| `myapps/paint` | mode 0 pixels, `VOS_BLIT`, pointer drawing with `VOS_PTR_KEYS`, flood fill, layers |
| `myapps/vrouves` | a game: sprites, stage files on its own disc, 25 Hz logic, save file, high scores |
| `myapps/markdown` | a parser that keeps its place, text styles, word wrap, a page drawn in runs |
| `myapps/music` | direct AY output, a third-party player, relocating loaded data, background playing |
| `apps/clock` | a desk accessory |
| `apps/mixed` | the mixed mode 0 / mode 1 screen (`VOS_SPLIT`) |

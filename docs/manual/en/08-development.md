# 8. Developing V-OS

For those who work on V-OS itself. Programs *for* V-OS are described in the [SDK](../../../sdk/README.en.md).

## What you need

- [RASM](https://github.com/EdouardBERGE/rasm), the assembler
- [iDSK](https://github.com/cpcsdk/idsk), for the disk images
- Python 3, for the tools. `make docs` also needs `markdown` and `pymupdf`.
- GNU make 4.3 or newer
- for testing, Caprice32 (snap `caprice32`)

## Build

| Command | What it does |
|---|---|
| `make` | `build/vos.dsk` (A:): the kernel, the views, the languages, DEMO, MIXED, STUDIO, CLOCK and the `.VBS` sources; `build/apps.dsk` (B:): the other programs and `myapps/*`; and the disc of each program with `owndisc/`. If a file does not fit on a real disc (180K), it stops with an error |
| `make run` | opens the disk in Caprice32 (`RUN"VOS"`) |
| `make shot` | starts without a window and takes a screenshot |
| `make docs` | the manual as PDFs: `docs/V-OS.pdf` (Greek) and `docs/V-OS-en.pdf`, `-fr`, `-es`, `-de`, `-it` |
| `make windows` | `build/V-OS-windows.zip`: `V-OS.exe` for Windows, with CPCEMU 3.0.2 (CPC 6128, 576K, AMX mouse, M4 board), `vos.dsk` in A:, `apps.dsk` in B: and the programs' own discs beside them. V-OS starts by itself. Needs WSL and the portable CPCEMU zip (`CPCEMU_ZIP=…`) |
| `make linux` | `build/V-OS-linux.tar.gz`: the `V-OS` script for Linux (x86_64), with CPCEMU 2.5 (3.0.2 is not out for Linux) and the same settings and discs. Needs SDL2 on the system and CPCEMU's Linux tar.gz (`CPCEMU_TGZ=…`) |
| `make songs` | the songs of Arkos Tracker 3 as `.MUS` files in `myapps/music/owndisc` (`tools/mkmusic.py`; needs Arkos Tracker 3, `ARKOS=…`) |
| `make new-app NAME=x`, `make app NAME=x` | your own program (SDK) |
| `make clean` | deletes `build/` |

## Repo layout

| Folder | Contents |
|---|---|
| `src/vos.asm` | the root of the build: loader and kernel, writing to the disk |
| `src/boot/` | the loader that AMSDOS runs at `#4000`, RAM expansion detection |
| `src/kernel/` | vectors, interrupts, file system, views, API (`api.asm`), settings, kernel extension (`ext.asm`), test scripts (`test_script.asm`) |
| `src/drivers/` | Gate Array, CRTC, keyboard, AMX mouse, FDC, AY |
| `src/gfx/` | overscan graphics, text, mixed screen |
| `src/ui/` | menus, buttons, dialogs, text input, file picker |
| `src/shell/` | the views as overlays: Desktop, Launcher, Commander, Setup |
| `src/api/vos_api.inc` | the API for programs |
| `lang/` | the languages (texts, keyboards, fonts) |
| `apps/` | the programs in assembly: DEMO, MIXED, STUDIO, CLOCK, and their icons |
| `blocks/` | the web editor, `vbc.py`, `runtime.asm`, the Studio player (`player.asm`), examples |
| `sdk/` | the SDK: guide and program template |
| `tools/` | tools: fonts, languages, texts, icons, relocation, `.VBS` from text, screenshots, PDF |
| `docs/` | this manual in Greek (`manual/`) and in English, French, Spanish, German and Italian (`manual/en/`, `fr/`, `es/`, `de/`, `it/`), the PDFs, the requirements (`REQUIREMENTS.md`) |

## Memory, in brief

| Area | What it holds |
|---|---|
| `#0000–#3DFF` | the kernel. In page zero, after the restart vectors, the API table at `#0108` |
| up to `#4000` | the kernel stack |
| `#4000–#7FFF` | the bank "window" |
| `#8000–#FFFF` | the 32K overscan screen. In its gaps, kernel buffers |

The banks that go into the window:

| Bank | What it holds |
|---|---|
| 4 | file and load buffer, and the data bank of the running program |
| 5 | the view at `#4000–#4FFF`, and from `#5000` the programs with a relocation table (or one program without a table in the whole bank) |
| 6 | whatever the menus and dialogs hide, and from `#7000` the desk accessory |
| 7 | the language pack, the Commander lists, the English texts, and from `#7000` the kernel extension |

With a memory expansion, its banks take programs. The details, address by address, are in `docs/REQUIREMENTS.md` (§4.2 and in each "Υλοποίηση M…" (implementation) section).

## Conventions

- **RASM:** hex is written `#C000` and not `&C000`, because RASM reads `&` as AND. Labels are not case-sensitive.
- **Comments:** in English, short, as in the existing code. Each file starts with a block that says what it does.
- **Documentation:** in Greek. `MILESTONES.md` (English), `MILESTONES.el.md` (Greek) and `docs/REQUIREMENTS.md` have a section for each milestone. The manual is written in Greek and translated into the other five languages of V-OS.
- **Texts:** the system texts are in `lang/*/messages.txt`, and the programs' texts in `texts.txt` (for `tools/mktexts.py`).

## Testing

The tests run V-OS in Caprice32 without a window and take screenshots in `build/shots/<delay>/`.

**How they work:**

- Caprice32 without a window cannot press arrows, COPY or f keys. That is why the key presses are made by a special build: a `-DTEST_SCRIPT=n` puts script n into `src/kernel/test_script.asm`, a table of keys per frame.
- Each `make test-…` target builds a disk with its script and takes a screenshot at each delay in `…_SHOTS`.
- The delay is measured in "Z" presses: about 2.5–3.5 frames each. The mapping is not fixed, so you catch a moment with two or three delays around it.
- Once V-OS writes to the disk, Caprice32 does not close by itself, and the test ends with a timeout. This is expected in test-vars, test-costume and others.
- You look at the screenshots yourself, e.g. combined into one image with `ffmpeg … hstack/vstack`.

| Target | What it tests |
|---|---|
| `test-input` | keys, Studio: blocks, files, running |
| `test-calc` | CALC with clicks, then `CALC.VBS` in Studio |
| `test-costume` | costume in Studio, running, reopening |
| `test-acc` | the clock as a desk accessory |
| `test-multi`, `test-switch`, `test-expand`, `test-behind` | several programs, F6, memory expansion, background |
| `test-drag` | dragging windows |
| `test-langs`, `test-lang` | the languages, saving the language |
| `test-mines`, `test-bricks` | the games |
| `test-vars` | the 128 variables, SAVE/LOAD VARS |
| `test-sdk` | the SDK template |
| `test-apps` | the two discs as given out, `vos.dsk` (with the test keys) in A: and `apps.dsk` in B:: the Launcher shows B: and PONG runs from there |
| `test-vrouves` | VROUVES from its disc in B:, through the Launcher (TAB): building, wave 1, the funds, HIGH SCORES |
| `test-notepad` | NOTEPAD: typing, DEL, the save dialog, OPEN with only `.TXT` files; then ^M: the page (mode 2) |
| `test-notepad-big` | NOTEPAD's text window in a Z80 emulator (`tools/notepad_check.py`): a 12K file with its own data bank, moving, typing and SAVE, text up to 16K, and 4K on a 6128 |
| `test-data` | (576K) NOTEPAD with a 15K text down to line 33, MARKDOWN meanwhile, then NOTEPAD back up to the start: the lines from its own data bank |
| `test-paint` | PAINT: line, box, fill, the menus, then the layers (hiding one), OTHER DRIVE and EXPORT .SCR to B: ("SAVED AS .SCR") |
| `test-scr` | PAINT's EXPORT .SCR (its code in a Z80 emulator, `tools/scr_check.py`) loaded in BASIC from a disc, with the palette; every pixel of the screen checked |
| `test-about` | HELP > ABOUT V-OS |
| `test-music` | MUSIC from `music.dsk` in B:: a song plays, and goes on behind the Launcher |
| `test-markdown` | MARKDOWN from `markdown.dsk` in B:: `README.MD` opened, the page with ^P, a screen down, back to the text; then ^M: the page (mode 2) |
| `test-open` | opening by type in the Commander: `README.MD` in MARKDOWN from B:, a `.TXT` in NOTEPAD from A: |
| `test-sysinfo` | SYSINFO from the Commander: version, API, memory, free K on A: and B:, ^R, ^Q. With `SYSINFO_RAM=576`, with a 512K expansion |
| `test-clip` | the clipboard: selecting with SHIFT, ^C and ^V in NOTEPAD, ^A, ^X, ^V, then ^V in MARKDOWN |
| `test-webget` | by hand, in the CPCEMU of `make linux` (M4 board; needs a screen and the internet): WEBGET downloads `example.com/index.html`. Close CPCEMU with F12 when SAVED shows, and `INDEX.HTM` is looked for on the disc |
| `test-reader` | READER from `reader.dsk` in B: opens `INDEX.MD`, TAB selects a link, RETURN opens `ABOUT.MD`, DEL goes back, and an `https://` link gives a message; then ^M: the page (mode 2) |
| `test-db` | the database engine in a Z80 emulator (`tools/db_check.py`): thousands of random calls on four tables, checked against a model, the file page by page (`tools/vdb.py`), until the disc is full |
| `test-db-disc` | `DB.SYS` with the kernel's file system on a DSK image (`tools/db_disc_check.py`) |
| `test-streets` | STREETS from `streets.dsk` in B:: a new `STREETS.VDB` with 24 streets, finding, a new street |
| `test-database-z80` | DATABASE in a Z80 emulator, with the database in Python and the screen as text: two tables, 47 records from the form, the order without case or accents, finding, a change, a deletion, scrolling |
| `test-database` | DATABASE in Caprice32: a new database on B:, a table, three records from the form, the list, finding, a change |
| `test-calc-sys` | the formula engine `CALC.SYS` in a Z80 emulator (`tools/calc_check.py`): fixed formulas and 40,000 random ones, numbers and texts, checked against a model in Python |
| `test-sheet-z80` | SHEET in a Z80 emulator with `CALC.SYS` itself and the screen as text: values, `#ERR`, cells that use each other, scrolling, SAVE and OPEN, a UTF-8 file, `BUDGET.VSH`, a full sheet; then ^M: the page (mode 2) |
| `test-sheet` | SHEET in Caprice32: numbers and a formula typed, `CALC.SYS` from A:, the sheet saved on B:; then ^M: the page (mode 2) |
| `test-kbds` | KEYBOARDS: ALL SIX in Setup, then in NOTEPAD the `:` and Z keys with each keyboard: `:z`, `:ζ`, `mw`, `ñz`, `öy`, `òz` |
| `test-charset`, `test-reader-utf8` | UTF-8 files in Greek, French, Spanish, German and Italian in NOTEPAD and in READER |
| `test-utf8` | the code of `VX_UTF8` in a Z80 emulator, against `tools/voscs.py` |
| `test-styles` | STYLES.VBN (`blocks/examples/styles.vbt`) from the Commander: plain, bold, italic, underlined and all three, with the STYLE block |
| `test-music-block` | with 576K: TUNE.VBN (`blocks/examples/tune.vbt`) starts MUSIC (from B:) behind it with AGANAMEM.MUS; F6 shows "> TUNE" and MUSIC, and RETURN brings MUSIC to the front: A:AGANAMEM, PLAYING. With `MBLOCK_RAM=128`: "CLOSE ANOTHER PROGRAM FIRST" |
| `test-amsdos`, `test-reboot`, `test-system` | V-OS files in BASIC, reboot, SYSTEM disk |

**New script:**

1. Add an `IF TEST_SCRIPT == n` at the start of the chain in `test_script.asm`, with `ELSE` before the next one and one more `ENDIF` at the end.
2. Add a target to the Makefile, like `test-sdk`.

Each key is written as `dw from, to : db row, bit` of the keyboard. The key number is row·8 + bit, e.g. RETURN = 18 = row 2, bit 2.

**Without an emulator:** a program's code also runs on a Z80 inside Python (the `z80` package). You load the `.BIN` at `#4000` and make the API calls return immediately (or do whatever is needed, e.g. files in a dictionary). Then you call init and event and read the memory. It is much faster than screenshots for errors in numbers, files and jumps. The label addresses come from `rasm … -s -sl` (a `.sym` file).

## Every milestone

1. Code, and a test in Caprice32: new or existing, with screenshots.
2. The tests the change touches.
3. A section in `MILESTONES.md` and `MILESTONES.el.md`, and a "Υλοποίηση M…" (implementation) section in `docs/REQUIREMENTS.md`.
4. **Update the manual in all six languages** (`docs/manual/` in Greek, `docs/manual/<code>/` for en, fr, es, de, it, and `sdk/README.md`, `sdk/README.<code>.md` if the API changes), then `make docs` for all the PDFs.
5. Commit and push.

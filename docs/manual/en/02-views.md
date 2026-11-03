# 2. The views

V-OS has four "views": ways to see the files and programs, and the settings. You switch view with F1–F4 or from the VIEW menu. Each view remembers which file was selected, and the next one selects the same file.

## The common menus

The last two menus are the same in all views and in programs:

| VIEW | | HELP | |
|---|---|---|---|
| DESKTOP | F1 | KEYS | ^K |
| LAUNCHER | F2 | ABOUT V-OS | |
| COMMANDER | F3 | | |
| SETUP | F4 | | |
| PROGRAMS (running) | F6 | | |
| SWITCH LANGUAGE | ^L | | |

HELP > ABOUT V-OS shows the version (0.15 beta; each milestone adds 0.01), the date of the build, the maker (Revive8bit, 2026) and the architect (Vasper).

## Desktop, F1

Mode 1. A FILES window shows the files of a drive as icons, four in each row. The type is written inside the icon and the name below it, and a `.VBN` has a "play" mark next to it. On the right, two icons choose A: or B:. The title bar shows the disc format and the number of files, and the free space is shown at the bottom.

| Key | What it does |
|---|---|
| arrows | choose a file (↑/↓ one row) |
| TAB | the next drive: A:, B:, DISK (with an M4 board) |
| RETURN, ENTER | open: a program runs, a file of a known type opens in its program, others show their info |
| ^C | copy to the next drive (from DISK: to A:) |
| ^D | delete (asks first) |
| ^N | rename |
| ^R | read the discs again |
| mouse | click on a file: select, again: open. Click on a drive: opens it |

- **FILE menu:** OPEN, FILE INFO (^I), COPY TO NEXT DRIVE, DELETE, RENAME, READ DISCS AGAIN, EXIT TO BASIC.
- **The FILES window** can be dragged by its title and stays there, even when you switch view.
- **At first there is no window and no drive is chosen:** the desk (and its picture) shows. A drive (a click on its icon, or TAB) opens its window; the X on its title closes it, and so does a click on the open drive. The small square in the corner below on the right makes the window larger or smaller in whole icons (2–5 in a row, 1–5 rows; four by five at first), and the bar on the right shows which part of the list is in view: a click above or below its dark part scrolls a window's worth up or down. The size is kept, like the place.
- **Opening by type** (also in the Commander): `.TXT` files open in NOTEPAD, `.MD` in MARKDOWN, `.PIC` and `.LYR` in PAINT, `.VDB` in DATABASE, `.VSH` in SHEET, `.MUS` in MUSIC, which starts playing them. The program is looked for on the file's drive, then on A:, then on B:. If it is not found, "NO PROGRAM FOR THIS FILE" is shown. If the program has unsaved changes, it asks first.

## Launcher, F2

Mode 0, 16 colors. Shows only the programs of one drive (`.BIN`, `.VBN`, `.BAS`), A: at first, as tiles in a 3×3 grid, with the next pages below. The page line starts with the drive (`A:`, `B:`). Every program that has an icon shows it on its tile. The selected tile is white.

| Key | What it does |
|---|---|
| arrows | choose (↑/↓ one row. Past the edge, the next or previous page) |
| RETURN, ENTER | runs the program. If it is already running, it resumes where it was |
| ^A | loads it as the desk accessory (AS ACCESSORY). F5 then opens it |
| ^R | read the disc again |
| TAB | the next drive (NEXT DRIVE): A:, B:, DISK. A program started from B: comes back to B: |
| mouse | click: select, again: run |

**FILE menu:** RUN, AS ACCESSORY, NEXT DRIVE, READ DISCS AGAIN, EXIT TO BASIC.

## Commander, F3

Mode 1, two panels with file lists: A: on the left, B: on the right. Each panel shows the format and the number of files in its title, and the free space at the bottom. The active panel has a dark title and a selection.

| Key | What it does |
|---|---|
| ↑/↓ | choose (with SHIFT: one page) |
| TAB, ←/→ | the other panel |
| RETURN, ENTER | open, as in the Desktop. The info (size, type, load address, the first bytes) with ^I |
| ^C | copy to the other panel, of any size. If there is a file with the same name, it asks first |
| ^D | delete |
| ^N | rename |
| ^R | read both discs again |
| ^G | the next drive for the active panel: A:, B:, DISK (also a click on its title) |
| mouse | click: select, again: open |

**FILE menu:** OPEN, FILE INFO (^I), COPY TO OTHER PANEL, DELETE, RENAME, READ DISCS AGAIN, NEXT DRIVE (^G), FORMAT DISC (DATA), EXIT TO BASIC.

> FORMAT erases all the files on the disc of the active panel. It asks first.

## DISK: the M4 board's SD card

With an M4 board, the Desktop has a third drive icon, DISK, under A: and B:, and TAB goes A: → B: → DISK. The Launcher and the Commander's panels (^G) reach it too. The title shows the folder you are in, e.g. `DISK:/GAMES/`.

- **Folders** show as folders (an icon with a tab, or DIR in the Commander). RETURN on one goes into it, and `..`, the first entry, goes back up. In the Launcher, folders are there too, so that you can reach the programs inside them.
- **Everything as on a disc:** programs run from it, files open in their programs, and ^C, ^D and ^N copy, delete and rename. Copies between DISK and a disc go up to 16K. Folders and files are named as on the CPC (8.3: `NAME.EXT`); names that are longer do not show.
- **M4.SYS** (on `vos.dsk`) is loaded from A: the first time DISK is used.
- **In the programs:** OTHER DRIVE (^W in SHEET) goes A: → B: → DISK, and the bottom line says `DISK:NAME.TXT`. OPEN's list shows the folders too: RETURN on one (or on `..`) lists that folder, and SAVE writes in the folder you opened from. READER writes the card as `C:` in its places.
- **Databases** go on DISK too: DATABASE's ^W reaches it, and STREETS run from the card keeps its STREETS.VDB there.
- **Not yet:** the SD card is not formatted from V-OS. V-OS itself still starts from a disc in A: (type `|DISC` before `RUN"VOS"`: with an M4 board, the CPC starts on the SD card).

## Setup, F4

Mode 1. One line for each setting. Changes take effect at once. When saved (RETURN or ^S) they are written to `A:SETUP.CFG` and also apply at the next start-up.

| Setting | Values |
|---|---|
| START VIEW | DESKTOP, LAUNCHER, COMMANDER |
| LANGUAGE | ENGLISH, ΕΛΛΗΝΙΚΑ, FRANÇAIS, ESPAÑOL, DEUTSCH, ITALIANO |
| REPEAT DELAY | how long you hold a key before it starts repeating: SHORT, MEDIUM, LONG |
| REPEAT SPEED | SLOW, MEDIUM, FAST |
| AMX MOUSE | ON, OFF |
| AMX READING | LEVELS (at first) or PULSES: how the mouse is read. LEVELS counts every read with movement, PULSES only the starts of the pulses. If the pointer moves too fast or too slowly, try the other one |
| DESK COLOUR | BLUE, BLACK, GREEN, RED |
| KEYBOARDS | EN + PACK, ALL SIX (the ones CONTROL+SHIFT goes through) |
| THEME | LIGHT, DARK (bars, menus, dialogs, windows and lists in black with white text; in programs, their menus and dialogs) |
| BACKGROUND | NONE, or a `.SCR` picture: LEFT/RIGHT go through NONE, A:, B: and DISK, and on a drive its `.SCR` files are listed to choose one. The Desktop shows it in the middle of the desk, the desk colour around it; a PAINT picture (mode 0, 16 colours) in the desk's four colours. It needs a memory expansion (the last 16K bank of it keeps the picture); without one: NEEDS A MEMORY EXPANSION |

| Key | What it does |
|---|---|
| ↑/↓ | choose a setting |
| ←/→ | change the value (also a click on the line) |
| RETURN, ^S | save |

Changing the LANGUAGE loads the language pack from A: at once. See [chapter 4](04-languages.md).

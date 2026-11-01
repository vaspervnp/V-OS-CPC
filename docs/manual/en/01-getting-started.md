# 1. Getting started

## What you need

- An Amstrad CPC 6128 or an emulator of it. V-OS is tested on Caprice32.
- The V-OS disc in drive A:, that is, the `build/vos.dsk` that `make` builds, and the programs' disc, `build/apps.dsk`, in B:.
- Optionally:
  - an AMX mouse
  - a second drive (B:)
  - a memory expansion (e.g. 512K), for more programs at once

## Starting up

From BASIC:

```
RUN"VOS
```

V-OS loads the kernel, switches off the ROMs and takes over the whole machine. It detects the memory expansion by itself.

- **First view:** the Desktop. You can change it in Setup, on the START VIEW line.
- **Language:** English. If there is a `SETUP.CFG` on the disc, it starts with the language and settings saved there.
- **Exit:** FILE > EXIT TO BASIC (CONTROL+Q in the views). It asks for confirmation and restarts the CPC.

## The screen

V-OS uses the whole screen (overscan): 384×272 pixels in mode 1 (4 colors) or 192×272 in mode 0 (16 colors).

- **Menu bar** (top): the menus of the view or program, usually FILE or the program's menu, VIEW and HELP. On the right is the keyboard language (EN, ΕΛ, …).
- **Bottom line:** in each view, the keys that work there.

## Keys that work everywhere

| Key | What it does |
|---|---|
| F1 | Desktop |
| F2 | Launcher |
| F3 | Commander |
| F4 | Setup |
| F5 | opens and closes the desk accessory (ACCESSORY) |
| F6 | the running programs, to choose one |
| ESC | opens the first menu. In the menus, ←/→ change menu, ↑/↓ choose an item, RETURN runs it, ESC closes |
| CONTROL+letter | the menu shortcuts (e.g. ^Q, ^L) |
| CONTROL+L | switch language (VIEW > SWITCH LANGUAGE) |
| CONTROL+K | the dialog with the keys (HELP > KEYS) |
| CONTROL+SHIFT | switches the keyboard: English, the pack's, and, with KEYBOARDS: ALL SIX in Setup, the other languages' |
| TAB, SHIFT+TAB | move the focus between buttons. RETURN, ENTER or SPACE press the button that has the focus |

F1–F6 are the f1–f6 keys on the CPC's numeric keypad.

## The pointer and the mouse

- **With an AMX mouse:** the pointer moves with the mouse, and its button clicks. The mouse is switched on and set up in Setup (AMX MOUSE, AMX READING).
- **Without a mouse:** the pointer moves with the arrow keys, and COPY clicks. In views that use the arrow keys for choosing (Desktop, Launcher, Commander), the arrows choose files and programs instead of moving the pointer.

Most things work with both: one click on a file or program selects it, and a second click opens it.

## Windows and dialogs

- **Dragging:** every window can be dragged by its title bar: the dialogs, the Desktop's FILES window, the desk accessory, and the windows of block programs. While you hold the button a dashed outline is shown, and the window is redrawn where you let go.
- **Dialogs:** wait for an answer. TAB and ←/→ change the button, RETURN presses it, and ESC chooses the last one (usually NO or CANCEL).
- **Text input** (e.g. renaming): you type at the end, DEL deletes, RETURN accepts and ESC cancels. You can also type in the language of the pack.

## Discs and files

- **Format:** V-OS reads and writes AMSDOS discs (DATA or SYSTEM format) in A: and B:. BASIC can read its files too.
- **Names:** 8 characters plus 3 for the type (`NAME.TYP`).

Types you will come across:

| Type | What it is |
|---|---|
| `.BIN` | a V-OS program (or a binary file) |
| `.VBN` | a V-OS program made with blocks |
| `.VBS` | a Studio program (its source) |
| `.OVL`, `.MSG`, `.LNG` | parts of V-OS itself: views, texts, languages |
| `.SYS` | system files (e.g. `VBRUN.SYS`, the Studio player) |
| `SETUP.CFG` | the settings |

The settings, languages and views are read from A:, so the V-OS disc must stay there.

## Error messages

Disc errors are shown in a dialog: DRIVE NOT READY, WRITE PROTECTED, FILE NOT FOUND, DISC FULL, DIRECTORY FULL, NAME ALREADY USED, INVALID NAME and others.

Two more concern programs:

- **NOT A V-OS PROGRAM:** the file does not have the header of a program.
- **CLOSE ANOTHER PROGRAM FIRST:** there is no room. See [chapter 3](03-programs.md).

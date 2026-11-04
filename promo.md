# V-OS — a graphical operating system for the Amstrad CPC 6128

**A desktop for a computer from 1985.** V-OS gives the Amstrad CPC 6128
windows, menus, a mouse pointer, a file manager and a set of programs to
use every day: a text editor, a paint program, a spreadsheet, a database,
a diary and programs that use the network. It is written entirely in Z80
assembly and starts from an ordinary 3" disc with `RUN"VOS"`, in six
languages.

## New in 0.43

- **The M4 board's clock** on the menu bar, and dates in the file lists.
- **DIARY:** a month on one screen, with the days that have notes marked.
- **TELNET:** a BBS or any line-based server, on a CPC.
- **Letters from a database:** DATABASE fills a NOTEPAD text with each record, ready to print.
- **NOTEPAD** with FIND and REPLACE, **PAINT** with circles.
- **A look into a `.SCR`** before opening it, page numbers on printouts, and **KEEP THE DESKTOP**, which remembers the files window for the next start.
- **WEBGET** no longer locks up when the M4 board answers with an error.

## A real desktop, from 128K to 576K

- **Four views, one key each:**
  - **F1, the Desktop:** file icons in a window that moves, resizes and scrolls, over a picture of your own;
  - **F2, the Launcher:** your programs with their icons;
  - **F3, the Commander:** two panels side by side, for copying and tidying;
  - **F4, Setup.**
- **Menus, dialogs and file lists**, with the keyboard or an AMX mouse.
- **A light and a dark theme.** A `.SCR` picture can be the background, and the same picture becomes the screen saver.
- **The whole screen used:** a 384×272 overscan, with modes 0, 1 and 2, and two modes on one screen at the same time.
- **Several programs at once.** Each one comes back as you left it, and F6 moves between them. Music keeps playing while you work, and a desk accessory such as the clock opens over anything.
- **With a 512K expansion (576K in all),** every program has a 16K bank of its own.

## Your files, on every drive

- **Drives A:, B: and the SD card of an M4 board, with folders.** Copy, delete, rename, find with `*` and `?`, look into a file without opening it, or copy a whole disc.
- **AMSDOS compatible:** BASIC reads the files V-OS writes, and V-OS reads BASIC's.
- **A file opens in its program:** a `.TXT` in NOTEPAD, a `.VDB` in DATABASE, a `.VSH` in SHEET, a `.MUS` in MUSIC.
- **Printing** on the CPC's printer port, page by page with a heading.
- **Files from a PC:** UTF-8 texts and `.CSV` tables go straight in.

## The programs

| | |
|---|---|
| **NOTEPAD** | Texts up to 16K, a clipboard shared by all programs, UNDO, FIND and REPLACE |
| **PAINT** | The whole CPC screen in 16 colours, layers, lines, boxes, circles, UNDO; `.SCR` files that BASIC loads too; SHOW for a slide show |
| **SHEET** | Formulas (SUM, AVG, MIN, MAX, ROUND…), bar charts, `.CSV` |
| **DATABASE** | "A small Access": tables, indexes, forms, search, imported `.CSV`, letters for each record |
| **DIARY** | The month, the days with notes, the notes of each day |
| **MARKDOWN, READER** | Markdown pages, from the disc or from the web |
| **MUSIC** | Arkos Tracker songs, without a break while other programs load |
| **WEBGET, TELNET** | The internet through the M4 board: downloads and text sessions |
| **Games** | VROUVES (a tower defence game in 7 stages), MINES, BRICKS, PONG and more |

## Make your own

- **Studio:** programs made of blocks, in the style of Scratch, on the CPC itself. It has sprites, costumes, music and 128 variables, and saves `.VBN` programs that run on their own.
- **The same blocks in a web browser** (Blockly), with a compiler.
- **An SDK for Z80 assembly:**
  - a project template and relocatable programs;
  - a documented API for files, windows, dialogs, menus, sound, the clipboard, databases, formulas, UTF-8, the network and a routine on every interrupt.

## Six languages, one character set

- **Greek, English, French, Spanish, German and Italian.** The language changes in Setup, without a restart.
- **Languages mix in the same text,** each keyboard is a key away, and sorting ignores case and accents.
- **The manual is in all six languages,** as PDF too.

## Try it

- **On a real CPC 6128:** write the discs from the release (`vos.dsk` with the system, `apps.dsk` with the programs, and a few more with programs and their files) and type `RUN"VOS"`.
- **In an emulator:** the Linux and Windows packages start V-OS straight away.
- **Demo videos:** about eight minutes in each of the six languages, recorded with 576K and an M4 board.

## Screenshots

In the dark theme, in English:

| | |
|---|---|
| ![The desk with its picture](docs/promo/01-desktop-picture.png) | ![The Desktop's window on B:](docs/promo/02-desktop-window.png) |
| ![NOTEPAD](docs/promo/03-notepad.png) | ![PAINT](docs/promo/04-paint.png) |
| ![The Launcher](docs/promo/05-launcher.png) | ![The Commander](docs/promo/06-commander.png) |
| ![The Commander's FILE menu](docs/promo/07-commander-menu.png) | ![Setup](docs/promo/08-setup.png) |
| ![F6: the programs running](docs/promo/09-programs.png) | |

---

*V-OS 0.43, by Revive8bit, 2026. Open source, under the MIT licence: [github.com/vaspervnp/V-OS-CPC](https://github.com/vaspervnp/V-OS-CPC).*

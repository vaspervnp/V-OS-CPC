# 9. On a real CPC

V-OS has only been tested in emulators: Caprice32, 1984 and CPCEMU. A real CPC can behave differently in its disc drive, its keyboard, its CRTC, its monitor, or with an AMX mouse. This chapter is a list of things to try, and what each should do. If something does something else, please tell us. Even "everything worked" helps.

## Getting V-OS onto the CPC

The release has two disc images, `vos.dsk` (A:) and `apps.dsk` (B:). Each fits on a 3" disc (180K). Some ways to use them:

- **Gotek or HxC** in place of a drive: copy the `.dsk` files to its USB stick.
- **A PC with a 3.5" drive** connected to the CPC as drive B:: write the images to discs (for example with SAMdisk or DiskImager on Windows).
- **An M4 board:** copy the images to its SD card and mount them from its menu.

Then, in BASIC: `RUN"VOS`.

## What to write down first

- The model (CPC 6128, or a 6128 Plus), and if you know it the CRTC type (0 to 4).
- The memory expansion (none, 64K, 512K…), the drives, the mouse, an M4 board.
- The monitor (CTM644 colour, GT65 green, a TV through a converter…).

## The list

Each line: what to do, and what you should see.

**Starting**
- [ ] `RUN"VOS` from A:. In a few seconds: the desk, the menu bar at the top, the drive icons on the right. Nothing flickers or jumps.
- [ ] The screen fills the whole tube (overscan, 384×272), with nothing cut off at the sides or at the bottom.
- [ ] HELP > ABOUT V-OS shows the version of the release.
- [ ] SYSINFO (in the Launcher, F2) shows the memory you have.

**The disc drive**
- [ ] TAB on the Desktop opens A:'s window, with its files as icons. A second TAB: B:.
- [ ] In the Commander (F3), copy a file from A: to B: (^C). Then leave V-OS (CONTROL+Q) and, in BASIC, `CAT` on B: shows it and `LOAD` reads it.
- [ ] Rename (^N) and delete (^D) a file on B:.
- [ ] FORMAT DISC (DATA) in the Commander's FILE menu, on a disc you do not need. Then `CAT` in BASIC: an empty disc.
- [ ] A disc in SYSTEM format (the CP/M one) is read too.
- [ ] Setup (F4): change the language, ^S. Start again with `RUN"VOS`: V-OS starts in that language.
- [ ] Without a disc in B:, the Commander says so, and V-OS does not hang.

**The keyboard**
- [ ] Every key in NOTEPAD: letters, digits, symbols, SHIFT, CAPS LOCK, the arrows, DEL, CLR, COPY.
- [ ] CONTROL+SHIFT changes the keyboard's language (EN, ΕΛ, …, on the right of the menu bar). Greek and accented letters come out right.
- [ ] Holding a key repeats it at the speed of Setup's REPEAT DELAY and REPEAT SPEED.
- [ ] The function keys: F1 Desktop, F2 Launcher, F3 Commander, F4 Setup, F6 the programs running.

**The AMX mouse**
- [ ] Setup: AMX MOUSE on. The pointer follows the mouse at the same speed across and down, in mode 1 (the Desktop) and in mode 0 (the Launcher).
- [ ] If it jumps or goes the wrong way, try the other AMX READING setting.
- [ ] Left button: a click; on a window's title, drag it; the corner below on the right, resize it.

**Memory**
- [ ] Without an expansion: NOTEPAD and PONG together, F6 between them; STUDIO runs on its own.
- [ ] With an expansion: four programs at once, each where it was left. PAINT with a big picture. A picture on the desk (Setup, BACKGROUND).

**The screen**
- [ ] PAINT and the Launcher in mode 0 (16 colours): the colours are right.
- [ ] READER or NOTEPAD with a page in mode 2 (80 columns): legible, also on a colour monitor.
- [ ] Studio's mixed screen (mode 0 above, mode 1 below): the split line stays still, nothing flickers.
- [ ] The dark theme (Setup, THEME).

**Sound**
- [ ] MUSIC plays a song; it keeps playing while you go to the Desktop and start another program.
- [ ] The games (VROUVES, BRICKS, PONG) have their sounds.

**The M4 board** (if you have one)
- [ ] TAB on the Desktop goes on from B: to DISK, the SD card, with its folders.
- [ ] NOTEPAD saves a file on DISK, and opens it again.
- [ ] The menu bar shows the M4's time; FILE INFO on a file on DISK gives its date.
- [ ] WEBGET downloads a file; READER opens a page from the web.
- [ ] TELNET connects to a server (a BBS) and shows what it sends.

**Speed** (how long, with a watch)
- [ ] From `RUN"VOS` to the desk.
- [ ] From F2 to the Launcher, and from a program's icon to the program.
- [ ] SHEET: BUDGET.VSH open and worked out.

## Telling us

Open an issue at <https://github.com/vaspervnp/V-OS-CPC/issues> with:

- what you wrote down first (the model, the memory, the monitor…);
- the lines that did something else, and what they did;
- a photo of the screen, if something looks wrong.

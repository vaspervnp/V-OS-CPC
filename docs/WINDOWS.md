# Programs in windows

Asked 2026-11-04: every program can also run in a window, so that several
show on the desk at once as overlapping windows, or full screen as now.
The menu bar stays at the top and is always the bar of the window in
front; it changes when another window (another program) comes to the
front.

This is the plan and what has been decided. The milestones (M73 on) are
in [TODO.md](../TODO.md) and, as each is done, in
[MILESTONES.md](../MILESTONES.md).

## What there is already

- **Several programs run at once**, each in a bank of its own, and F6
  goes from one to another (kernel/ext.asm: the switcher). One is in
  front: it gets the keys and the pointer and draws; the others wait,
  or run in the background (`VOS_BACKGROUND`: frames only).
- **Every program can draw everything again**: `jp redraw` at +6 of its
  header.
- **The desk accessory** (CLOCK) is already a window over a program:
  `VOS_DRAG` moves it, and the program under it draws everything again
  when it closes. Its menu bar and texts are its own while it is open
  (`acc_swap` swaps `ui_bar`, `app_texts`, `ui_widgets`, `view_ticks`).
- **The Desktop's files window** moves, is resized in whole icons, and
  scrolls.

## The limits that shape it

- **One screen mode and one palette.** Overlapping windows are possible
  only in mode 1, with the theme's four colours. A program in mode 0
  (PAINT, the Launcher, the games, Studio's programs) or mode 2
  (NOTEPAD's page, MARKDOWN's preview), or one that sets its own palette
  or a mixed screen (`VOS_SPLIT`), runs full screen. A windowed program
  that changes mode goes full screen by itself.
- **Memory.** The kernel has about 60 bytes free, every gap in the
  screen's RAM is in use, and base RAM bank 1 (the second extension,
  CALC.SYS, DB.SYS and its cache) is full. Only short entry routines go
  in the kernel. The work is done in a bank of the memory expansion
  (`wm_bank`, the one before the desk picture's), which gets its code
  from VOS.BIN at boot (M73: `gfx/view.asm`). Windows therefore **need a
  memory expansion** (576K); with 128K everything stays full screen as
  now. The window manager (M74) is too big for VOS.BIN: `WM.SYS`, loaded
  from A: into that bank at boot.
- **Speed.** A Z80 at 4 MHz takes about half a second to two seconds to
  draw three or four windows again. Windows move as an outline (as the
  accessory does) and are drawn once, where they land. Later, each
  window can keep a copy of itself in a bank (§5).
- **A program's memory is at #4000-#7FFF, as is every extension.** While
  the view's code runs, the program's bank is not mapped. So the
  kernel's entry routines copy what a call points to (a rectangle, an
  image's header) into the gaps before they call it.

## Decisions

1. **Coordinates are the window's** (`VX_VIEW`, M73). A windowed program draws at
   (0, 0) = the top left of its window's inside. The kernel adds the
   window's place (the origin), and draws nothing outside the window's
   inside (the clip). With no window, the origin is (0, 0) and the clip
   is the whole screen, so nothing changes for programs as they are now.
   - Clipped are `VOS_CLS` (only the clip is filled), `VOS_PLOT`,
     `VOS_RECT` (cut to the clip), `VOS_CHAR` and `VOS_PRINT` (a
     character is drawn only if its whole 8 × 8 cell is inside), and
     `VOS_BLIT` (drawn only if it is all inside).
   - Menus, dialogs, the bar and the pointer draw on the whole screen, as
     now.
2. **Programs say if they can be windowed.** A program that cannot runs
   full screen as now. One that can calls `VX_WINDOW` (M74) with its
   size first in its init, every time: it gets its window, or carry and
   the whole screen. Its init must draw everything, its bar too: that is
   how the windows behind are drawn again (init with A = 2, the one in
   front last). Later (M75) a new event, `VE_SIZE`, tells it that the
   size changed; it then draws everything again.
3. **The bar is the front window's.** A click on a window brings it to
   the front, gives it the keys and puts its menu bar at the top. This
   is `acc_swap` for every running program, not only for the accessory.
4. **What is uncovered is drawn again.** When a window moves, closes or
   comes to the front, the windows under the place it left are drawn
   from the back to the front. Each one is clipped to that place.
   (Later, with copies in banks, it is only copied back: §5.)
5. **Only windows that nothing covers draw by themselves.** A window in
   front, or one that no other window overlaps, can draw at any time
   (TELNET receiving, CLOCK ticking). A covered one is marked, and draws
   everything again when it is uncovered or comes to the front.
6. **A window's frame:**
   - a title line with the program's name, a close box and a full screen
     box;
   - a border of one pixel;
   - a corner that resizes it, as the Desktop's window has.
   - The title moves it with `VOS_DRAG`'s outline.
   - Full screen gives the program the whole screen as now, and its
     header's box brings the window back.
7. **The Desktop is underneath.** Its desk, picture and drive icons are
   the background; its files window becomes one window among the others
   (M78).

## As M74 left it

- `WM.SYS` keeps up to six windows. A click on one that is behind brings
  its program to the front as F6 does: it starts again (init with
  A = 2) and asks for its window, which then comes to the front, and
  everything is drawn again from the back.
- The frame: a title line 10 pixels high (the name, + and X at its right
  end, 12 pixels each), a border of 4 pixels; the title is in the
  selection's colours in front. The inside's width is a multiple of 8.
- Not yet: resizing (M75), `VOS_PALETTE` and widgets in a window, asking
  the program before X ends it. The accessory (F5, CLOCK) over windows
  has not been tried yet.

## Milestones

| | What | Done when |
|---|---|---|
| **M73** ✓ | **Origin and clip** for programs' drawing: `VX_VIEW` (API 33) sets them; `VOS_CLS`, `PLOT`, `RECT`, `CHAR`, `PRINT` and `BLIT` respect them. The work is in `wm_bank` (576K); the kernel gets entry routines only, with room made by moving `VOS_SPLIT`'s setting to where the loader was in bank 1. | `make test-view`: VIEWT draws through a view, checked pixel by pixel; 128K: carry. Programs without `VX_VIEW` draw as before (the existing tests). |
| **M74** ✓ | **Windows**, in `WM.SYS` (576K): a list in depth order, the frame, moving with an outline, the front window, its bar at the top, the full screen box (and F7), closing. `VX_WINDOW` (API 34). | `make test-wm`: WINA and WINB (`apps/wint`) in windows: brought to the front with a click, the bar changes, a click inside from its corner, moved, full screen and back, closed; seven screenshots checked (`tools/wm_check.py`). |
| M75 | **Programs in windows**: resizing with the frame's corner, the header's size, `VE_SIZE`, what is uncovered drawn again, drawing by uncovered windows; F6 brings a window to the front. **CLOCK, CALC, SYSINFO.** | Three of them on the desk at once, overlapping; CLOCK ticks when nothing covers it. |
| M76 | **DIARY, TELNET, WEBGET, DATABASE** in windows. | TELNET receives in a window next to DIARY. |
| M77 | **NOTEPAD, SHEET, READER, MARKDOWN** in windows, laid out for the size they are given; their mode 2 pages full screen. | NOTEPAD resized, its lines rewrapped to the window. |
| M78 | **Copies in banks** (576K): a window keeps a copy of itself, so moving it or bringing it to the front only copies; the Desktop's files window becomes a window like the others. | A window moved over three others: no program draws again. |

Each milestone adds 0.01 to the version and updates the manual in its
six languages, the SDK's documentation and its tests.

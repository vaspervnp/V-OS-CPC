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
  window keeps a copy of itself in a bank (M78).
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
   front last). `VX_WINDOW` writes back the size the window has now
   (M75), so a program lays out for it in init; when the window is
   resized, every program draws again through its init, so no event
   of its own is needed (there is no room in the kernel for one).
3. **The bar is the front window's.** A click on a window brings it to
   the front, gives it the keys and puts its menu bar at the top. This
   is `acc_swap` for every running program, not only for the accessory.
4. **What is uncovered is drawn again.** When a window moves, closes or
   comes to the front, the windows under the place it left are drawn
   from the back to the front. Each one is clipped to that place.
   With copies in banks (M78), one that has a copy is only copied back.
5. **Only windows that nothing covers draw by themselves.** A window in
   front, or one that no window in front of it overlaps, can draw at any
   time (TELNET receiving, CLOCK ticking): a program that goes on in the
   background (`VOS_BACKGROUND`) draws in its window then (M75). A
   covered one draws nothing, and draws everything again (init) when it
   is uncovered or comes to the front.
6. **A window's frame:**
   - a title line with the program's name, a close box and a full screen
     box;
   - a border of one pixel;
   - a corner that resizes it, as the Desktop's window has.
   - The title moves it with `VOS_DRAG`'s outline.
   - Full screen gives the program the whole screen as now, and its
     header's box brings the window back.
7. **The Desktop is underneath.** Its desk, picture and drive icons are
   the background; its files window is one window among the others
   (M78, M79).

## As M80 left it

- `WM.SYS` keeps up to eight windows (the Desktop's two among them). A click on one that is behind, or F6,
  brings its program to the front: it starts again (init with A = 2)
  and asks for its window, which then comes to the front, and
  everything is drawn again from the back.
- The frame: a title line 10 pixels high (the name, + and X at its right
  end, 12 pixels each), a border of 4 pixels, and its bottom right
  corner (8 × 8) resizes it; the title is in the selection's colours in
  front. The inside's width is a multiple of 8, at least 64 × 24.
- Full screen (+ or F7) is the screen under the menu bar, as a view of
  that size; the windows' palette and mode 1 are set again when the
  windows are drawn after another view.
- CLOCK and SYSINFO run in windows (with a memory expansion); CLOCK goes
  on in the background and ticks while uncovered.
- **A part of a program's screen** (M76, API 36): `VX_WINDOW`'s x0, y0
  say which part of its screen the window shows, so a program made for
  the whole screen draws as it did. DIARY, TELNET, WEBGET and DATABASE
  ask for their screen under the bar; made smaller, the window shows its
  top left part.
- **Laid out for their size** (M77): NOTEPAD, MARKDOWN, READER and SHEET
  take as many columns and rows as their window has room for (w / 8
  characters; SHEET as many of its columns of 9), with the status line
  under the rows, and do so again whenever the window is resized. Their
  mode 2 page (^M), SHEET's chart too, leaves the windows (`VX_WINDOW`
  with w = 0) and runs full screen; ^M again brings the window back,
  where and as large as it was.
- **Widgets in windows** (M76): they are drawn from the view's corner
  and clicked there. A Studio program in mode 1 with a WINDOW shows that
  window's inside in a V-OS window (CALC).
- **Copies in banks** (M78): eight banks of the memory expansion (128K)
  are taken at boot for copies of the windows' insides. A window that
  nothing covers is copied when another view starts (the kernel's
  `view_start` calls `wm_snap`), before one is moved or resized, and
  after its program has drawn it from behind. Drawn again, a window with
  a copy is copied back, and its program is not called: a window moved
  over the others draws none of them again. A window that drew behind
  while uncovered (CLOCK) is copied again the next time. Windows start
  at an x that is a multiple of 4, so a copy is whole bytes. A window
  with no copy (no bank free for it, or after it was resized or full
  screen) is drawn by its program as before.
- **The desk** under the windows shows the Desktop's picture (Setup's
  BACKGROUND), as the Desktop does.
- **The Desktop among the windows** (M79): the Desktop stays a view,
  but its files window and its drive icons are two records of the list
  (the icons at the back), drawn from their copies when a program is in
  front. On the Desktop the programs' windows are drawn on its desk,
  under its files window. A click on a program's window brings it to the
  front; a click on the Desktop's window or icons brings the Desktop.
- **M80:** `VOS_PALETTE` is quiet while a program is in front in a
  window (the windows keep the Desktop's colours); full screen it works
  as before. X asks the program: it gets CONTROL+Q, BACK in every V-OS
  program, so NOTEPAD asks about unsaved changes first; if it ends, the
  next program's window comes to the front. A program behind in a window
  that nothing covers has `VOS_EXT` too, so TELNET (now going on in the
  background in a window) receives there; covered, it waits. The
  accessory (F5) and the switcher (F6) open over the windows, which are
  copied first and drawn again when they close.
- After the plan: MAIL (M81) and FTP (M82) open in a window as TELNET
  does (`dw 376, 232, 0, 12`) and go on receiving behind, uncovered;
  their network code (`src/api/vos_net.inc`) marks `net_socks` with #FF
  before each `VOS_EXT`, as TELNET marks `socks`.
- Not yet: windows in mode 0 or 2, a program's own palette in a window.

## Milestones

| | What | Done when |
|---|---|---|
| **M73** ✓ | **Origin and clip** for programs' drawing: `VX_VIEW` (API 33) sets them; `VOS_CLS`, `PLOT`, `RECT`, `CHAR`, `PRINT` and `BLIT` respect them. The work is in `wm_bank` (576K); the kernel gets entry routines only, with room made by moving `VOS_SPLIT`'s setting to where the loader was in bank 1. | `make test-view`: VIEWT draws through a view, checked pixel by pixel; 128K: carry. Programs without `VX_VIEW` draw as before (the existing tests). |
| **M74** ✓ | **Windows**, in `WM.SYS` (576K): a list in depth order, the frame, moving with an outline, the front window, its bar at the top, the full screen box (and F7), closing. `VX_WINDOW` (API 34). | `make test-wm`: WINA and WINB (`apps/wint`) in windows: brought to the front with a click, the bar changes, a click inside from its corner, moved, full screen and back, closed; seven screenshots checked (`tools/wm_check.py`). |
| **M75** ✓ | **Programs in windows**: resizing with the frame's corner, the size written back by `VX_WINDOW` (API 35), drawing by uncovered windows behind (`wm_bg`); F6 brings a window to the front. **CLOCK, SYSINFO.** | `make test-wm-apps`: CLOCK, SYSINFO and WINA on the desk at once, overlapping; CLOCK ticks behind SYSINFO when nothing covers it; SYSINFO resized (`tools/wm_apps_check.py`). |
| **M76** ✓ | **Widgets in windows**, so **CALC** (a Studio program, VBRUN) is windowed; **DIARY, TELNET, WEBGET, DATABASE** in windows, each showing the part of its screen it asks for (`VX_WINDOW`'s x0, y0, API 36). | `make test-wm-apps2`: DIARY, TELNET over it, CALC in a window, and its buttons clicked there: 1 + 2 = 3 (`tools/wm_apps2_check.py`). TELNET's receiving is tested as before (`make test-telnet`, off the emulator): Caprice32 has no network. |
| **M77** ✓ | **NOTEPAD, SHEET, READER, MARKDOWN** in windows, laid out for the size they are given; their mode 2 pages full screen (`VX_WINDOW` with w = 0 leaves the windows). | `make test-wm-notepad`: NOTEPAD resized, its columns and rows cut to the window, the status under them; its page full screen and the window back (`tools/wm_notepad_check.py`). `make test-wm-pages`: MARKDOWN, its preview, READER (wrapped at the window's width) and SHEET (4 columns, 18 rows); SHEET's page and back (`tools/wm_pages_check.py`). |
| **M78** ✓ | **Copies in banks** (576K): a window keeps a copy of itself, so moving it or drawing it again from behind only copies; the desk under the windows shows the Desktop's picture. | `make test-wm-copies`: WINB moved away from SYSINFO and WINA, over them and away again; WINA and WINB, which write how many times they have drawn, still say 001 (`tools/wm_copies_check.py`). |
| **M85** ✓ | A program started from the Launcher (mode 0) gets a window of its size: WM.SYS goes to mode 1 before it measures and places it. | `make test-wm-launch`: NOTEPAD from the Launcher, 376 × 232, typed into. |
| **M84** ✓ | **MAIL and FTP** (M81, M82) in windows as TELNET: tested together. | `make test-wm-net`: FTP over MAIL; FTP's X ends it (^Q), MAIL in front; MAIL's X: the Commander. |
| **M80** ✓ | `VOS_PALETTE` in a window; X asking the program; TELNET receiving behind; F5 and F6 among windows. | `make test-wm-keys`: the switcher and the accessory over WINA and WINB, closed: drawn again; WINA's reds quiet; its X ends it (^Q), WINB in front. `make test-wm-notepad`: X on a changed text: NOTEPAD asks. `make test-telnet`: frames with `VOS_EXT` quiet take nothing. |
| **M79** ✓ | **The Desktop's files window** as a window among the others, the desk's drive icons under them. The Desktop stays a view (the kernel has no byte left): WM.SYS keeps its window and icons as records drawn from their copies, and the Desktop asks WM.SYS to draw the programs' windows on its desk. | `make test-wm-desktop`: WINA with the Desktop's window and icons behind it; the Desktop (F1) with WINA's window on its desk; each brought to the front with a click (`tools/wm_desktop_check.py`). |

Each milestone adds 0.01 to the version and updates the manual in its
six languages, the SDK's documentation and its tests.

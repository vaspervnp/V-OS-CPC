# V-OS: to do

Done in M58–M64 (see MILESTONES.md):

1. **A release to hand out** (M58): the MIT licence, `make release`, chapter 9 of the manual, "On a real CPC".
2. **Printer** (M59): `VX_PRINT` (API 30), PRINT in NOTEPAD, SHEET and DATABASE.
3. **Finding files** (M60): FIND (^F) and SHOW THE TEXT (^V) in the Commander.
4. **Charts in SHEET** (M61): CHART (^G), saved as a `.SCR`.
5. **Undo** (M62): ^Z in NOTEPAD and PAINT.
6. **The M4's time** (M63): the real time and date in CLOCK.
7. **Smaller** (M64): SHOW (a slideshow), COPY THE DISC (^E), CSV into SHEET and DATABASE, the Desktop's screen saver.

Still open:

- **A real CPC:** everything above was tested in emulators only; chapter 9 of the manual is the list to try.
- **A GitHub Release:** `make release` builds the archive; publishing it needs a push and a tag.
- **A clock on the menu bar, and dates on DISK's files:** the kernel has no room (4 bytes left); they need code moved out of it first.
- **A preview of a `.SCR`** in the Commander (SHOW THE TEXT shows text only).
- **PAINT's UNDO for FILL on the whole screen** (it may go past the window kept).
- **Page breaks** when a printout is longer than a page.

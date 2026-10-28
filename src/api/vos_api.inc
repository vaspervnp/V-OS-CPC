; =====================================================================
; vos_api.inc - the V-OS API for programs
;
; A program is a binary file (AMSDOS header, type 2) assembled for
; VOS_APP_ADDR. The Launcher loads it into bank 5 (up to 16K, code and
; data) and it starts with
;   +0  jp init     set the mode, palette and menus, draw everything
;   +3  jp event    HL -> the event (VOS_EV_SIZE bytes, below)
;   +6  jp redraw   draw everything again (the language changed)
;   +9  db "VA", VOS_API_VERSION
; Each entry returns to the kernel, which calls event once per event:
; a program never waits for input itself. With VOS_TICKS on it also gets
; a VE_FRAME event 50 times a second, for animation.
;
; Calls: CALL VOS_xxx. Arguments in A, BC, DE, HL (IX for VOS_RECT);
; results in A or HL, carry set on failure with A = error number
; (VOS_ERROR shows it). All registers but IX may be destroyed. Screen
; coordinates: x in pixels of the current mode, y 0..258.
; Do not map another bank at #4000: the program would be unmapped.
; =====================================================================

VOS_API_VERSION equ 6               ; 2: KEY_HELD, 3: BLIT, SOUND, 4: SPLIT,
                                    ; 5: RUN, KEEP, 6: the data bank
VOS_APP_ADDR    equ #4000
VOS_API         equ #0108           ; the jump table (after "VOS",0, versions)

; ---- system ---------------------------------------------------------
VOS_EXIT        equ VOS_API + 0 * 3     ; back to the view that started it
VOS_TICKS       equ VOS_API + 1 * 3     ; A = 1: VE_FRAME events, 0: none
VOS_FRAMES      equ VOS_API + 2 * 3     ; -> HL = frames since boot (50 Hz)
VOS_RANDOM      equ VOS_API + 3 * 3     ; -> A = 0..255
VOS_COMMAND     equ VOS_API + 4 * 3     ; A = VC_*: a shared menu command
VOS_ERROR       equ VOS_API + 5 * 3     ; A = error number: error dialog
; ---- graphics -------------------------------------------------------
VOS_MODE        equ VOS_API + 6 * 3     ; A = 0 or 1, with the UI pens
VOS_PALETTE     equ VOS_API + 7 * 3     ; HL -> 17 firmware colours
VOS_CLS         equ VOS_API + 8 * 3     ; A = pen
VOS_PLOT        equ VOS_API + 9 * 3     ; HL = x, DE = y, A = pen
VOS_RECT        equ VOS_API + 10 * 3    ; IX -> dw x, y, w, h; db pen
VOS_COLOURS     equ VOS_API + 11 * 3    ; A = text pen, C = background pen
VOS_PRINT       equ VOS_API + 12 * 3    ; HL = x, DE = y, BC -> text, 0
VOS_CHAR        equ VOS_API + 13 * 3    ; HL = x, DE = y, A = character
; ---- texts and UI ---------------------------------------------------
VOS_MSG         equ VOS_API + 14 * 3    ; A = system text number -> HL
VOS_SET_BAR     equ VOS_API + 15 * 3    ; HL -> menu bar (as ui/ui.asm)
VOS_DRAW_BAR    equ VOS_API + 16 * 3
VOS_UI_EVENT    equ VOS_API + 17 * 3    ; the current event -> A = command
VOS_DIALOG      equ VOS_API + 18 * 3    ; HL -> dialog -> A = button
VOS_INPUT       equ VOS_API + 19 * 3    ; A = title, HL -> text, C = max
VOS_SET_WIDGETS equ VOS_API + 20 * 3    ; HL -> buttons
VOS_DRAW_WIDGETS equ VOS_API + 21 * 3
VOS_MENU_VIEW   equ VOS_API + 22 * 3    ; -> HL = the shared VIEW menu
VOS_MENU_HELP   equ VOS_API + 23 * 3    ; -> HL = the shared HELP menu
; ---- files ----------------------------------------------------------
VOS_CATALOG     equ VOS_API + 24 * 3    ; A = drive -> A = files, HL -> list
VOS_LOAD        equ VOS_API + 25 * 3    ; A = drive, HL = name, DE = to
VOS_SAVE        equ VOS_API + 26 * 3    ; A = drive, HL = name, DE, BC
VOS_DELETE      equ VOS_API + 27 * 3    ; A = drive, HL = name
VOS_FILE_PICK   equ VOS_API + 28 * 3    ; after VOS_CATALOG: A = title
VOS_TEXTS       equ VOS_API + 29 * 3    ; HL -> the program's texts
VOS_MENU_OPEN   equ VOS_API + 30 * 3    ; -> NZ while a menu is open (its
                                        ; keys are not the program's)
VOS_KEY_HELD    equ VOS_API + 31 * 3    ; A = key number -> NZ while held
; ---- images and sound (version 3) -----------------------------------
VOS_BLIT        equ VOS_API + 32 * 3    ; IX -> dw x, y; db bytes, rows;
                                        ; dw source; db source stride
VOS_SOUND       equ VOS_API + 33 * 3    ; A = channel 0..2, HL = period
                                        ; (bit 15: noise), C = volume
                                        ; 0..15 (0: stop), B = frames
; ---- mixed screen (version 4) ---------------------------------------
VOS_SPLIT       equ VOS_API + 34 * 3    ; HL -> dw y1, y2; db 4 + 4 colours
                                        ; (HL = 0: off)
; ---- programs that run programs (version 5) ------------------------
VOS_RUN         equ VOS_API + 35 * 3    ; A = drive, HL -> 11-byte name
                                        ; ("NAME    BIN"): run it after
                                        ; this event; when it exits,
                                        ; this program starts again
VOS_KEEP        equ VOS_API + 36 * 3    ; -> HL -> 16 bytes the kernel
                                        ; keeps between programs (0 at
                                        ; boot; any program may use them)
; ---- the data bank (version 6) --------------------------------------
VOS_BANK_GET    equ VOS_API + 37 * 3    ; HL = source in the data bank,
                                        ; DE = destination, BC = bytes
VOS_BANK_PUT    equ VOS_API + 38 * 3    ; HL = source, DE = destination
                                        ; in the data bank, BC = bytes
VOS_DATA        equ #80                 ; drive + VOS_DATA: VOS_LOAD and
                                        ; VOS_SAVE use the data bank
VOS_API_COUNT   equ 39

; The data bank: 16K more for the program (bank 4), seen at the same
; addresses #4000-#7FFF but never mapped there: the program copies to
; and from it (VOS_BANK_GET, VOS_BANK_PUT) or loads and saves files in
; it (drive + VOS_DATA). At the start it holds a copy of the program's
; file; it lasts until the program ends. Call these on the kernel's
; stack (in init and event), not on a stack inside #4000-#7FFF.

; VOS_BLIT draws an image, whole bytes of screen memory (2 pixels in
; mode 0, 4 in mode 1; x is rounded down to a byte). The source is, per
; row, pairs of bytes: a mask (1 = the image's pixel) and the pixels.
; Pixels outside the mask keep what is on the screen. The image must be
; on the screen. VOS_SOUND: notes stop by themselves after B frames;
; VOS_EXIT silences everything.
;
; VOS_SPLIT: lines y1..y2-1 are shown in mode 0, the rest in mode 1
; (0 < y1 < y2 <= 259). The colours are firmware colours for pens 0..3,
; first in the mode 1 bands, then in the mode 0 band; pens 4..15 come
; from VOS_PALETTE. VOS_MODE then only picks how the program draws:
; draw each band in its own mode, and leave mode 0 selected for
; dialogs. The kernel draws its menu bar in mode 1 and its menus in
; mode 0; with menus, y1 must be 12. Event x is in pixels of the band
; the pointer is in. A boundary right below line 22, 74, 126, 178 or
; 230 costs nothing; any other line waits for it in the interrupt (at
; y1 = 12: 14% of the time). Disc transfers may disturb the split
; for a moment. VOS_EXIT ends it.

; Icon (optional): "IC" at +12 (VOS_ICON), then 16 rows of 8 (mask,
; pixels) pairs, as VOS_BLIT draws them: 16 x 16 pixels in mode 0, in
; the Launcher's palette. The Launcher shows it on the program's tile.
; tools/mkicon.py makes it from text. Init then starts at +270.
VOS_ICON        equ 12
VOS_ICON_SIZE   equ 256

; Program texts: numbers VT_FIRST and up, in menus, dialogs, VOS_MSG.
; VOS_TEXTS table: db count, then per text dw English, dw other (the
; language pack's language; 0 = the English one). Texts end with 0;
; "|" starts a new line in dialogs.
VT_FIRST        equ #C0

; ---- events (HL -> type, code, char, mods, dw x, dw y) ---------------
VOS_EV_SIZE     equ 8
VE_KEY_DOWN     equ 1               ; code = key number, char = character
VE_KEY_UP       equ 2
VE_KEY_REPEAT   equ 3
VE_PTR_MOVE     equ 4
VE_PTR_DOWN     equ 5
VE_PTR_UP       equ 6
VE_LANG         equ 7               ; the keyboard language changed
VE_FRAME        equ 8               ; with VOS_TICKS on

; key numbers (the CPC keyboard matrix: line * 8 + bit)
VK_UP           equ 0
VK_RIGHT        equ 1
VK_DOWN         equ 2
VK_ENTER        equ 6
VK_LEFT         equ 8
VK_COPY         equ 9
VK_RETURN       equ 18
VK_SPACE        equ 47
VK_ESC          equ 66
VK_TAB          equ 68
VK_DEL          equ 79

; shared commands for VOS_COMMAND and the VIEW / HELP menus
VC_QUIT         equ 6
VC_LANG         equ 7
VC_KEYS         equ 8
VC_ABOUT        equ 9
VC_DESKTOP      equ 16
VC_LAUNCHER     equ 17
VC_COMMANDER    equ 18
VC_SETUP        equ 19

; menu separators, and system texts a program may use (in dialogs, as
; buttons, or with VOS_MSG)
VOS_SEPARATOR   equ #FF
VM_OK           equ 17              ; = MSG_BTN_OK (kernel/api.asm checks)
VM_YES          equ 18
VM_NO           equ 19

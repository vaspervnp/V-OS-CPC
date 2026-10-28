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

VOS_API_VERSION equ 1
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
VOS_API_COUNT   equ 31

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

; menu separators, and system texts a program may use
VOS_SEPARATOR   equ #FF

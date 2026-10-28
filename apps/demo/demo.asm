; =====================================================================
; demo.asm - a small V-OS program: the first one, and an API example
;
; Mode 0. A square moves on its own (VE_FRAME events) and bounces off
; the edges; the cursor keys steer it, SPACE changes its colour. A menu
; of its own (DEMO: next colour, back) next to the shared VIEW and HELP
; menus. Its texts come in English and Greek (VOS_TEXTS).
;
; Built on its own, with only the API include (Makefile):
;   rasm apps/demo/demo.asm -I src -o build/demo
; =====================================================================

        include "api/vos_api.inc"

SQ              equ 16              ; the square, in mode 0 pixels
TOP             equ 16
BOTTOM          equ 236             ; above the hint line
RIGHT           equ 192
BG              equ 2               ; pens (VOS_MODE 0 palette)
HINT_Y          equ 248

T_MENU          equ VT_FIRST
T_COLOUR        equ VT_FIRST + 1
T_BACK          equ VT_FIRST + 2
T_HELLO         equ VT_FIRST + 3
T_HINT          equ VT_FIRST + 4

CMD_COLOUR      equ 1
CMD_BACK        equ 2

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "icon_demo.asm"       ; VOS_ICON, from apps/icons/demo.txt

init:
        ld hl,texts
        call VOS_TEXTS
        xor a
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        call VOS_MENU_VIEW          ; the bar: ours, then the shared ones
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        ld a,1
        call VOS_TICKS
        ; fall through

redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        ld a,1                      ; white on blue
        ld c,BG
        call VOS_COLOURS
        ld a,T_HELLO
        call VOS_MSG
        ld b,h
        ld c,l
        ld hl,0
        ld de,TOP + 4
        call VOS_PRINT
        ld a,T_HINT
        call VOS_MSG
        ld b,h
        ld c,l
        ld hl,0
        ld de,HINT_Y
        call VOS_PRINT
        jp draw

; HL -> event
event:
        ld a,(hl)
        push hl
        cp VE_FRAME
        jr z,.frame
        call VOS_UI_EVENT           ; menus and shortcuts first
        pop hl
        or a
        jr nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(hl)
        cp VE_KEY_DOWN
        ret nz
        inc hl
        ld a,(hl)                   ; key
        ld de,#FE00                 ; D = dy, E = dx
        cp VK_UP
        jr z,.steer
        ld de,#0200
        cp VK_DOWN
        jr z,.steer
        ld de,#00FE
        cp VK_LEFT
        jr z,.steer
        ld de,#0002
        cp VK_RIGHT
        jr z,.steer
        cp VK_SPACE
        ret nz
        ; fall through to the next colour
.colour:
        ld a,(pen)
        inc a
        cp 16
        jr c,.pen
        ld a,3
.pen:
        ld (pen),a
        jr draw
.steer:
        ld (dx),de                  ; dx then dy
        ret
.frame:
        pop hl
        call erase
        ld a,(x)                    ; x += dx, bounce off the sides
        ld b,a
        ld a,(dx)
        add a,b
        cp RIGHT - SQ + 1
        jr c,.x_ok
        ld a,(dx)
        neg
        ld (dx),a
        ld a,b
.x_ok:
        ld (x),a
        ld a,(y)                    ; y += dy, bounce off top and bottom
        ld b,a
        ld a,(dy)
        add a,b
        cp TOP + 12
        jr c,.y_bounce
        cp BOTTOM - SQ + 1
        jr c,.y_ok
.y_bounce:
        ld a,(dy)
        neg
        ld (dy),a
        ld a,b
.y_ok:
        ld (y),a
        jr draw

; A = command
command:
        cp CMD_COLOUR
        jr z,event.colour
        cp CMD_BACK
        jp z,VOS_EXIT
        jp VOS_COMMAND              ; VIEW and HELP menus

erase:
        ld a,BG
        jr square
draw:
        ld a,(pen)
square:
        ld (rect + 8),a
        ld a,(x)
        ld (rect),a
        ld a,(y)
        ld (rect + 2),a
        push ix
        ld ix,rect
        call VOS_RECT
        pop ix
        ret

; ---- data -----------------------------------------------------------
palette:        db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 0

bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 3
                db T_COLOUR, CMD_COLOUR, "C", 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0

texts:          db 5
                dw t_menu_en, t_menu_el
                dw t_colour_en, t_colour_el
                dw t_back_en, t_back_el
                dw t_hello_en, t_hello_el
                dw t_hint_en, t_hint_el
t_menu_en:      db "DEMO", 0
t_colour_en:    db "NEXT COLOUR", 0
t_back_en:      db "BACK", 0
t_hello_en:     db "HELLO FROM A PROGRAM!", 0
t_hint_en:      db "ARROWS STEER  SPACE COL", 0
; Greek in ISO 8859-7 (the pack's charset)
t_menu_el:      db #C5, #D0, #C9, #C4, #C5, #C9, #CE, #C7, 0      ; ΕΠΙΔΕΙΞΗ
t_colour_el:    db #C1, #CB, #CB, #CF, " ", #D7, #D1, #D9, #CC, #C1, 0 ; ΑΛΛΟ ΧΡΩΜΑ
t_back_el:      db #C5, #D0, #C9, #D3, #D4, #D1, #CF, #D6, #C7, 0 ; ΕΠΙΣΤΡΟΦΗ
t_hello_el:     db #C3, #C5, #C9, #C1, " ", #C1, #D0, #CF, " "    ; ΓΕΙΑ ΑΠΟ
                db #D0, #D1, #CF, #C3, #D1, #C1, #CC, #CC, #C1, "!", 0 ; ΠΡΟΓΡΑΜΜΑ!
t_hint_el:      db #C2, #C5, #CB, #C7, " ", #CF, #C4, #C7, #C3, #C7, #D3, #C7 ; ΒΕΛΗ ΟΔΗΓΗΣΗ
                db " SPACE ", #D7, #D1, #D9, #CC, #C1, 0          ; SPACE ΧΡΩΜΑ

; ---- state ----------------------------------------------------------
x:              db 88
y:              db 120
dx:             db 2
dy:             db 2
pen:            db 8
rect:           dw 0, 0, SQ, SQ
                db 8
demo_end:
        save "build/DEMO.BIN", VOS_APP_ADDR, demo_end - VOS_APP_ADDR

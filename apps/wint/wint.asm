; =====================================================================
; wint.asm - WINA and WINB, programs in windows for make test-wm
; (VX_WINDOW): built twice, with -DSIDE=1 (WINA: 160 x 80, pen 2) and
; -DSIDE=2 (WINB: 136 x 64, pen 3). Each asks for its window first in
; init (each time: A = 2 too), fills it with its pen and writes its name;
; a click in it marks the place and writes it, from the window's corner.
; Its menu bar: WINA (or WINB) > BACK ^Q, VIEW, HELP. Without windows
; (128K) it says NO WINDOWS, full screen.
;   rasm apps/wint/wint.asm -I src -I build -DSIDE=1 -o build/wina
; =====================================================================

        include "api/vos_api.inc"

        IF SIDE == 1
W               equ 160
H               equ 80
PEN             equ 2
        ELSE
W               equ 136
H               equ 64
PEN             equ 3
        ENDIF

T_MENU          equ VT_FIRST
T_BACK          equ VT_FIRST + 1
CMD_BACK        equ 1

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION

init:
        ld a,VX_WINDOW              ; first: the window
        ld hl,size
        call VOS_EXT
        ld a,0
        jr nc,.window
        inc a
.window:
        ld (full),a
        ld hl,texts
        call VOS_TEXTS
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        call VOS_DRAW_BAR
redraw:
        ld a,PEN
        call VOS_CLS
        ld a,1
        ld c,PEN
        call VOS_COLOURS
        ld hl,8
        ld de,8
        ld bc,name
        ld a,(full)
        or a
        jr z,.name
        ld bc,no_windows
.name:
        call VOS_PRINT
        ld a,(clicked)
        or a
        ret z
        jr mark

event:
        push hl
        call VOS_UI_EVENT           ; menus and shortcuts first
        pop hl
        or a
        jr nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(hl)
        cp VE_PTR_DOWN
        ret nz
        ld de,4                     ; x, y in the window
        add hl,de
        ld de,where
        ld bc,4
        ldir
        ld a,1
        ld (clicked),a
        ; fall through
; a square where it was clicked, and its x, y in the window
mark:
        ld hl,(where)
        ld (dot),hl
        ld hl,(where + 2)
        ld (dot + 2),hl
        ld ix,dot
        call VOS_RECT
        ld hl,(where)               ; "X,Y": three digits each
        ld de,text
        call digits
        ld a,","
        ld (de),a
        inc de
        ld hl,(where + 2)
        call digits
        xor a
        ld (de),a
        ld a,1
        ld c,PEN
        call VOS_COLOURS
        ld hl,8
        ld de,24
        ld bc,text
        jp VOS_PRINT

; HL = 0..999 -> three digits at DE on
digits:
        ld bc,100
        call .digit
        ld bc,10
        call .digit
        ld bc,1
.digit:
        ld a,"0" - 1
.sub:
        inc a
        or a
        sbc hl,bc
        jr nc,.sub
        add hl,bc
        ld (de),a
        inc de
        ret

command:
        cp CMD_BACK
        jp z,VOS_EXIT
        jp VOS_COMMAND              ; VIEW and HELP menus

size:           dw W, H, 0, 0      ; VX_WINDOW: w, h, x0, y0
full:           db 0
clicked:        db 0
where:          dw 0, 0
dot:            dw 0, 0, 4, 4
                db 1
text:           ds 8
        IF SIDE == 1
name:           db "WINA", 0
        ELSE
name:           db "WINB", 0
        ENDIF
no_windows:     db "NO WINDOWS", 0
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 1
                db T_BACK, CMD_BACK, "Q", 0
texts:          db 2, "EL"
                dw name, name
                dw t_back_en, t_back_el
t_back_en:      db "BACK", 0
t_back_el:      db #C5, #D0, #C9, #D3, #D4, #D1, #CF, #D6, #C7, 0   ; ΕΠΙΣΤΡΟΦΗ

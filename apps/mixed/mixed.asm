; =====================================================================
; mixed.asm - the mixed screen (VOS_SPLIT): mode 1 bands above and
; below a mode 0 band
;
; The menu bar and a status line at the bottom are in mode 1 (384
; pixels, 4 colours), the middle in mode 0 (192 pixels, 16 colours)
; with a square that bounces on its own. A click shows the event's x
; and y in the status line: x is in pixels of the band clicked.
; SPACE or MIXED > BACK ends it.
;
; Built on its own, with only the API include (Makefile):
;   rasm apps/mixed/mixed.asm -I src -I build -o build/mixed
; and again with -DVOS_RELOC_PASS=1 for its relocation table (Makefile)
; =====================================================================

        include "api/vos_api.inc"

Y1              equ 12              ; mode 0 from under the menu bar
Y2              equ 230             ; mode 1 again: no wait at this line
SQ              equ 16
TOP             equ 100             ; the square's room
BOTTOM          equ Y2 - 4
RIGHT           equ 192
BG              equ 2               ; mode 0 pens
STATUS_PEN      equ 1               ; mode 1 pens
STATUS_TEXT     equ 2

T_MENU          equ VT_FIRST
T_BACK          equ VT_FIRST + 1
T_MODE0         equ VT_FIRST + 2
T_MODE1         equ VT_FIRST + 3

CMD_BACK        equ 1

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "icon_mixed.asm"       ; VOS_ICON, from apps/icons/mixed.txt

init:
        ld hl,texts
        call VOS_TEXTS
        xor a
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        ld hl,split
        call VOS_SPLIT
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        ld a,1
        call VOS_TICKS
        ; fall through

redraw:
        ld a,BG                     ; mode 0: the middle
        call VOS_CLS
        ld a,1
        ld c,BG
        call VOS_COLOURS
        ld a,T_MODE0
        ld hl,0
        ld de,20
        call print_msg
        ld ix,swatch                ; pens 0..15
        xor a
.swatch:
        ld (swatch + 8),a
        push af
        call VOS_RECT
        pop af
        ld hl,(swatch)
        ld de,12
        add hl,de
        ld (swatch),hl
        inc a
        cp 16
        jr c,.swatch
        ld hl,0
        ld (swatch),hl
        call VOS_DRAW_BAR           ; drawn in mode 1 by the kernel
        call status                 ; mode 1: the bottom band
        jp draw

; the status band, in mode 1
status:
        ld a,1
        call VOS_MODE
        push ix
        ld ix,status_rect
        call VOS_RECT
        pop ix
        ld a,STATUS_TEXT
        ld c,STATUS_PEN
        call VOS_COLOURS
        ld a,T_MODE1
        ld hl,8
        ld de,Y2 + 4
        call print_msg
        jr mode0

; HL = x, DE = y of a click: show them in the status band
show_xy:
        push de
        ld de,xy_text + 2
        call number
        pop hl
        ld de,xy_text + 8
        call number
        ld a,1
        call VOS_MODE
        ld a,STATUS_TEXT
        ld c,STATUS_PEN
        call VOS_COLOURS
        ld hl,8
        ld de,Y2 + 16
        ld bc,xy_text
        call VOS_PRINT
mode0:
        xor a
        jp VOS_MODE

; A = text, HL = x, DE = y
print_msg:
        push hl
        push de
        call VOS_MSG
        ld b,h
        ld c,l
        pop de
        pop hl
        jp VOS_PRINT

; HL = 0..999 -> three digits at DE
number:
        ld bc,100
        call .digit
        ld bc,10
        call .digit
        ld bc,1
.digit:
        ld a,"0" - 1
.count:
        inc a
        or a
        sbc hl,bc
        jr nc,.count
        add hl,bc
        ld (de),a
        inc de
        ret

; HL -> event
event:
        ld a,(hl)
        cp VE_FRAME
        jr z,frame
        push hl
        call VOS_UI_EVENT           ; menus and shortcuts first
        pop hl
        or a
        jr nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(hl)
        cp VE_PTR_DOWN
        jr z,.click
        cp VE_KEY_DOWN
        ret nz
        inc hl
        ld a,(hl)
        cp VK_SPACE
        ret nz
        jp VOS_EXIT
.click:
        ld de,4
        add hl,de
        ld e,(hl)                   ; x
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)                   ; y
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        jp show_xy

; A = command
command:
        cp CMD_BACK
        jp z,VOS_EXIT
        jp VOS_COMMAND              ; VIEW and HELP menus

frame:
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
        ld a,(y)                    ; y += dy between TOP and BOTTOM
        ld b,a
        ld a,(dy)
        add a,b
        cp TOP
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
        ld hl,pen                   ; a new colour every frame
        inc (hl)
        ld a,(hl)
        cp 16
        jr c,draw
        ld (hl),3
        ; fall through
draw:
        ld a,(pen)
        jr square
erase:
        ld a,BG
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
split:          dw Y1, Y2
                db 1, 26, 0, 11     ; mode 1 bands, as on the Desktop
                db 0, 26, 1, 2      ; mode 0 band, pens 0..3

bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 1
                db T_BACK, CMD_BACK, "Q", 0

texts:          db 4
                dw t_menu_en, t_menu_el
                dw t_back_en, t_back_el
                dw t_mode0_en, t_mode0_el
                dw t_mode1_en, t_mode1_el
t_menu_en:      db "MIXED", 0
t_back_en:      db "BACK", 0
t_mode0_en:     db "MODE 0: 16 COLOURS", 0
t_mode1_en:     db "MODE 1: 4 COLOURS, 384 PX. SPACE: BACK", 0
; Greek in ISO 8859-7 (the pack's charset)
t_menu_el:      db #CC, #C9, #CA, #D4, #C7, 0                       ; ΜΙΚΤΗ
t_back_el:      db #C5, #D0, #C9, #D3, #D4, #D1, #CF, #D6, #C7, 0   ; ΕΠΙΣΤΡΟΦΗ
t_mode0_el:     db "MODE 0: 16 ", #D7, #D1, #D9, #CC, #C1, #D4, #C1, 0 ; ΧΡΩΜΑΤΑ
t_mode1_el:     db "MODE 1: 4 ", #D7, #D1, #D9, #CC, #C1, #D4, #C1   ; ΧΡΩΜΑΤΑ
                db ", 384 PX. SPACE: "
                db #C5, #D0, #C9, #D3, #D4, #D1, #CF, #D6, #C7, 0     ; ΕΠΙΣΤΡΟΦΗ

; ---- state ----------------------------------------------------------
x:              db 88
y:              db 140
dx:             db 2
dy:             db 2
pen:            db 8
rect:           dw 0, 0, SQ, SQ
                db 8
swatch:         dw 0, 40, 12, 40
                db 0
status_rect:    dw 0, Y2, 384, 259 - Y2
                db STATUS_PEN
xy_text:        db "X=000 Y=000", 0
mixed_end:
        IFDEF VOS_RELOC_PASS            ; Makefile: two builds, one table
        save "build/mixed_hi.bin", VOS_APP_ADDR, mixed_end - VOS_APP_ADDR
        ELSE
        save "build/mixed_lo.bin", VOS_APP_ADDR, mixed_end - VOS_APP_ADDR
        ENDIF

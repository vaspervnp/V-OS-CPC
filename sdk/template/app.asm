; =====================================================================
; appname.asm - APPNAME, a V-OS program (from sdk/template)
;
; Mode 1. The arrow keys move a box, the BEEP button (TAB, then RETURN,
; or a click) plays a note, a counter shows the seconds since it
; started (VE_FRAME events). Its own menu (ABOUT, BACK) comes before
; the shared VIEW and HELP menus; its texts, in English and Greek, are
; in texts.txt, its icon in icon.txt.
;
; The API is src/api/vos_api.inc; sdk/README.md tells how a program
; works and lists the calls.
;   make app NAME=appname     build/APPNAME.BIN, and build/vos.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
BOX_PEN         equ 3
WIDTH           equ 384             ; the screen in mode 1
BOX             equ 16              ; the box, in pixels
TOP             equ 48              ; where it may go
BOTTOM          equ 240
STEP            equ 4

CMD_ABOUT       equ VC_APP + 1      ; menu items and buttons: commands,
CMD_BACK        equ VC_APP + 2      ; from VC_APP (VIEW and HELP send 6-19)
CMD_BEEP        equ VC_APP + 3

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start; A = 2: back after a view or another program, the
; state as it was
init:
        ld hl,texts
        call VOS_TEXTS
        ld a,1
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        call VOS_MENU_VIEW          ; the bar: ours, then the shared ones
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        ld hl,widgets
        call VOS_SET_WIDGETS
        ld a,1                      ; VE_FRAME events, 50 a second
        call VOS_TICKS
        ; fall through

; everything, again (also when the language changes)
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        call VOS_DRAW_WIDGETS
        ld a,T_HELLO
        ld hl,8
        ld de,18
        call print_msg
        ld a,T_SECONDS
        ld hl,56
        ld de,30
        call print_msg
        ld a,T_HINT
        ld hl,8
        ld de,248
        call print_msg
        call show_seconds
        jp draw_box

; HL -> the event
event:
        ld a,(hl)
        cp VE_FRAME
        jp z,frame
        push hl
        call VOS_UI_EVENT           ; menus, buttons, shortcuts first
        pop hl
        or a
        jr nz,command
        call VOS_MENU_OPEN          ; a menu is open: the keys are its
        ret nz
        ld a,(hl)
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_KEY_REPEAT            ; a key held down
        ret nz
.key:
        inc hl
        ld a,(hl)                   ; the key number (VK_*)
        ld b,0
        cp VK_LEFT
        ld de,-STEP
        jr z,move
        cp VK_RIGHT
        ld de,STEP
        jr z,move
        ld de,0
        cp VK_UP
        ld b,-STEP
        jr z,move
        cp VK_DOWN
        ld b,STEP
        ret nz
        ; fall through

; DE = steps right, B = steps down: the box moves, if it stays inside
move:
        push de
        push bc
        call erase_box
        pop bc
        pop de
        ld hl,(box_x)
        add hl,de
        bit 7,h
        jr nz,.y                    ; left of the screen: x stays
        push hl
        ld de,WIDTH - BOX + 1
        or a
        sbc hl,de
        pop hl
        jr nc,.y
        ld (box_x),hl
.y:
        ld a,(box_y)
        add a,b
        cp TOP
        jr c,.draw
        cp BOTTOM - BOX + 1
        jr nc,.draw
        ld (box_y),a
.draw:
        jp draw_box

; A = command (a menu item or a button)
command:
        cp CMD_BEEP
        jr z,beep
        cp CMD_ABOUT
        jr z,about
        cp CMD_BACK
        jp z,VOS_EXIT
        jp VOS_COMMAND              ; the VIEW and HELP menus

beep:
        xor a                       ; channel 0, 440 Hz (period 142),
        ld hl,142                   ; volume 12, for 15 frames
        ld c,12
        ld b,15
        jp VOS_SOUND

about:
        ld hl,dlg_about
        jp VOS_DIALOG               ; -> A = the button (here OK)

; 50 frames a second: the counter
frame:
        ld hl,frames
        inc (hl)
        ld a,(hl)
        cp 50
        ret c
        ld (hl),0
        ld hl,(seconds)
        inc hl
        ld (seconds),hl
        call VOS_MENU_OPEN          ; a menu over the screen: draw
        ret nz                      ; nothing now (it would go over it)
        ; fall through

; the seconds, in five digits
show_seconds:
        ld hl,(seconds)
        ld de,number
        ld bc,-10000
        call .digit
        ld bc,-1000
        call .digit
        ld bc,-100
        call .digit
        ld c,-10
        call .digit
        ld c,b
        call .digit
        xor a
        ld (de),a
        call colours
        ld hl,8
        ld de,30
        ld bc,number
        jp VOS_PRINT
.digit:
        ld a,"0" - 1
.count:
        inc a
        add hl,bc
        jr c,.count
        sbc hl,bc
        ld (de),a
        inc de
        ret

; A = text, HL = x, DE = y: print it
print_msg:
        push hl
        push de
        call VOS_MSG                ; -> HL -> the text
        push hl
        call colours
        pop bc
        pop de
        pop hl
        jp VOS_PRINT

colours:
        ld a,INK
        ld c,BG
        jp VOS_COLOURS

erase_box:
        ld a,BG
        jr paint_box
draw_box:
        ld a,BOX_PEN
paint_box:
        ld (rect + 8),a
        ld hl,(box_x)
        ld (rect),hl
        ld a,(box_y)
        ld (rect + 2),a
        push ix
        ld ix,rect
        call VOS_RECT
        pop ix
        ret

; ---- data -----------------------------------------------------------
; 16 pens and the border, as firmware colours: black, white, blue,
; bright yellow (mode 1 uses pens 0..3)
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1

bar:            db 3                ; three menus: ours, VIEW, HELP
                dw menu, 0, 0
menu:           db T_MENU, 3        ; title, items: text, command,
                db T_ABOUT, CMD_ABOUT, 0, 0     ; CONTROL+letter, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0

widgets:        db 1                ; buttons: dw x, y; db width in
                dw 296, 18          ; characters, text, command, 0
                db 8, T_BEEP, CMD_BEEP, 0

dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK  ; title, text, buttons

        include "app_texts.asm"     ; T_* and texts:, from texts.txt

; ---- state ----------------------------------------------------------
box_x:          dw 184
box_y:          db 140
frames:         db 0
seconds:        dw 0
number:         ds 6
rect:           dw 0, 0, BOX, BOX   ; VOS_RECT: x, y, w, h, pen
                db 0

; =====================================================================
; show.asm - SHOW, the .SCR pictures of a drive one after the other
; (made with the SDK)
;
; Mode 0. The .SCR files of the drive it was started from (OTHER DRIVE
; ^W: A:, B:, DISK), up to MAX_PICS, each loaded into the data bank and
; drawn in the middle of the screen (160 x 200, as PAINT's whole screen)
; with its inks, if it has PAINT's at #07D0 (else the ones below). The
; next one comes every STEP_FRAMES, or with RIGHT; LEFT the one before,
; SPACE stops and goes on. The top line: its name and number.
;   SHOW menu: NEXT PICTURE, PREVIOUS PICTURE, STOP / GO ON, OTHER
;   DRIVE ^W, ABOUT, BACK ^Q
;   make app NAME=show        build/SHOW.BIN, on build/apps.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 0               ; pens
INK             equ 1
MAX_PICS        equ 48
STEP_FRAMES     equ 250             ; 5 seconds
PIC_X           equ 16              ; the picture on the screen (mode 0)
PIC_Y           equ 30
NAME_Y          equ 16
HINT_Y          equ 249
DATA            equ #4000           ; the picture, in the data bank
SCR_SIZE        equ #4000

CMD_NEXT        equ VC_APP + 1      ; menu items: commands
CMD_PREV        equ VC_APP + 2
CMD_PAUSE       equ VC_APP + 3
CMD_DRIVE       equ VC_APP + 4
CMD_ABOUT       equ VC_APP + 5
CMD_BACK        equ VC_APP + 6

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start, on its own drive; 2: back, the same picture
init:
        push af
        ld hl,texts
        call VOS_TEXTS
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        ld a,1                      ; VE_FRAME events
        call VOS_TICKS
        pop af
        cp 2
        jr z,redraw
        ld a,(VOS_SELF)
        ld (drive),a
        ; fall through

; the drive's .SCR files, from the first
read_list:
        xor a
        ld (pics),a
        ld (pic),a
        ld a,(drive)
        or VOS_CAT_EXT
        ld hl,ext_scr
        call VOS_CATALOG
        jr c,redraw
        or a
        jr z,redraw
        ld b,a                      ; 16 bytes a file: its name, and a
        ld de,names                 ; folder (on DISK) left out
.file:
        push bc
        push hl
        ld bc,13                    ; (M4_FOLDER)
        add hl,bc
        ld a,(hl)
        pop hl
        or a
        jr nz,.skip
        ld a,(pics)
        cp MAX_PICS
        jr nc,.skip
        inc a
        ld (pics),a
        push hl
        ld bc,11
        ldir
        pop hl
.skip:
        ld bc,16
        add hl,bc
        pop bc
        djnz .file
        ; fall through

; everything again: the picture (loaded again: the data bank may have
; been another program's), its name, the keys
redraw:
        xor a
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld a,T_HINT
        ld hl,0
        ld de,HINT_Y
        call print_msg
        xor a
        ld (frames),a
        ld a,(pics)
        or a
        jr nz,show
        ld a,T_NONE
        ld hl,0
        ld de,NAME_Y
        jp print_msg

; pic: loaded and drawn, with its name and number
show:
        ld a,(pic)                  ; its name
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,bc
        add hl,de                   ; * 11
        ld de,names
        add hl,de
        ld (name_at),hl
        ld a,(drive)
        or VOS_DATA
        ld de,DATA
        call VOS_LOAD
        jp c,VOS_ERROR
        ld hl,DATA + #07D0          ; its inks, if they are inks
        ld de,inks
        ld bc,17
        call VOS_BANK_GET
        ld hl,inks
        ld b,17
.ink:
        ld a,(hl)
        inc hl
        cp 27
        jr nc,.own
        djnz .ink
        ld hl,inks
        call VOS_PALETTE
.own:
        ld b,0                      ; the rows: (row & 7) * #800 +
.row:                               ; (row / 8) * 80
        push bc
        ld a,b
        and 7
        add a,a
        add a,a
        add a,a
        add a,DATA >> 8
        ld d,a
        ld a,b
        and #F8
        ld l,a
        ld h,0
        add hl,hl
        ld c,l
        ld b,h
        add hl,hl
        add hl,hl
        add hl,bc                   ; (row & #F8) * 10
        ld e,0
        add hl,de
        ld de,row
        ld bc,80
        call VOS_BANK_GET
        ld hl,row                   ; as pairs: all of each byte shown
        ld de,pairs
        ld b,80
.pair:
        ld a,#FF
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        djnz .pair
        pop bc
        ld a,b
        add a,PIC_Y
        ld (blt + 2),a
        push bc
        ld ix,blt
        call VOS_BLIT
        pop bc
        inc b
        ld a,b
        cp 200
        jr c,.row
        ld de,line                  ; "B:NAME.SCR  3/7"
        ld a,(drive)
        call vos_drive_text
        ld hl,(name_at)
        ld b,8
.name:
        ld a,(hl)
        inc hl
        cp " "
        jr z,.dot
        ld (de),a
        inc de
        djnz .name
.dot:
        ld hl,dot_scr
        ld bc,6
        ldir
        ld a,(pic)
        inc a
        call number
        ld a,"/"
        ld (de),a
        inc de
        ld a,(pics)
        call number
        xor a
        ld (de),a
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,NAME_Y
        ld bc,line
        jp VOS_PRINT

; A = 1..99 -> its digits at DE
number:
        ld b,"0" - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,"0" + 10
        ld c,a
        ld a,b
        cp "0"
        jr z,.one
        ld (de),a
        inc de
.one:
        ld a,c
        ld (de),a
        inc de
        ret

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

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        ld a,(hl)
        cp VE_FRAME
        jr z,frame
        push hl
        call VOS_UI_EVENT           ; menus and CONTROL+letter first
        pop hl
        or a
        jr nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(hl)
        cp VE_KEY_DOWN
        ret nz
        inc hl
        ld a,(hl)
        cp VK_RIGHT
        jr z,next
        cp VK_LEFT
        jr z,prev
        cp VK_SPACE
        jr z,pause
        ret

; every STEP_FRAMES the next one, unless stopped
frame:
        ld a,(paused)
        or a
        ret nz
        ld hl,frames
        inc (hl)
        ld a,(hl)
        cp STEP_FRAMES
        ret c
        ; fall through
next:
        ld a,(pics)
        or a
        ret z
        ld b,a
        ld a,(pic)
        inc a
        cp b
        jr c,go
        xor a
go:
        ld (pic),a
        xor a
        ld (frames),a
        jp show

prev:
        ld a,(pics)
        or a
        ret z
        ld a,(pic)
        or a
        jr nz,.back
        ld a,(pics)
.back:
        dec a
        jr go

pause:
        ld hl,paused
        ld a,(hl)
        xor 1
        ld (hl),a
        xor a
        ld (frames),a
        ret

; A = command
command:
        cp CMD_NEXT
        jr z,next
        cp CMD_PREV
        jr z,prev
        cp CMD_PAUSE
        jr z,pause
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,drive
        call vos_next_drive
        jp read_list
.not_drive:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        jp VOS_EXIT

        include "api/vos_drive.inc"

; ---- data -----------------------------------------------------------
; PAINT's inks (a picture without its own), and the border
palette:        db 0, 26, 2, 6, 18, 24, 20, 8, 15, 13, 3, 9, 1, 12, 17, 11
                db 0
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 7
                db T_NEXT, CMD_NEXT, 0, 0
                db T_PREV, CMD_PREV, 0, 0
                db T_PAUSE, CMD_PAUSE, 0, 0
                db T_DRIVE, CMD_DRIVE, "W", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
ext_scr:        db "SCR"
dot_scr:        db ".SCR  "
blt:            dw PIC_X, 0         ; VOS_BLIT: a row of the picture
                db 80, 1
                dw pairs
                db 160

        include "app_texts.asm"     ; T_*, texts, from texts.txt

drive:          db 0
pics:           db 0                ; how many
pic:            db 0                ; the one shown
paused:         db 0
frames:         db 0
name_at:        dw 0
inks:           ds 17
line:           ds 24
row:            ds 80
pairs:          ds 160
names:          ds MAX_PICS * 11

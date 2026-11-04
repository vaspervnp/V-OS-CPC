; =====================================================================
; sysinfo.asm - SYSINFO, what V-OS says about itself (made with the SDK)
;
; Mode 1. The V-OS and API versions (VOS_EXT, VX_VERSION), the memory
; and how much of it is free for programs (VX_MEM), and the free
; space on drives A: and B: (VX_FREE), read again with ^R. An example
; of VOS_EXT, the calls after the API's jump table (API 15).
;   SYSINFO menu: READ AGAIN ^R, ABOUT, BACK ^Q
;   make app NAME=sysinfo     build/SYSINFO.BIN, and build/vos.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
HINT_Y          equ 249             ; full screen

CMD_REFRESH     equ VC_APP + 1      ; menu items: commands
CMD_ABOUT       equ VC_APP + 2
CMD_BACK        equ VC_APP + 3

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

init:
        ld a,VX_WINDOW              ; in a window, if there are windows
        ld hl,wsize                 ; (first, each time); the pens are
        call VOS_EXT                ; the same with the Desktop's colours
        ld hl,place_win
        jr nc,.place
        ld hl,place_full
.place:
        ld de,place
        ld bc,5
        ldir
        ld hl,texts
        call VOS_TEXTS
        ld a,(place + 4)
        or a
        jr z,.bar
        ld a,1
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
.bar:
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        ; fall through

; everything, again: the facts are read each time
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        ld a,HEAD + VOS_BOLD + VOS_UNDERLINE
        ld c,BG
        call VOS_COLOURS
        ld a,T_TITLE
        call VOS_MSG
        ld b,h
        ld c,l
        ld hl,(place)
        ld e,0
        call row
        call VOS_PRINT
        ld a,(place + 4)            ; full screen: the keys at the bottom
        or a
        jr z,.versions
        ld a,T_HINT
        ld hl,0
        ld de,HINT_Y
        call print_lab
.versions:
        ld a,VX_VERSION             ; the versions
        call VOS_EXT
        push af
        ld de,value                 ; BCD: #0010 = 0.10
        ld a,h
        cp 16
        jr nc,.major
        add a,"0"                   ; one digit
        ld (de),a
        inc de
        jr .minor
.major:
        call bcd
.minor:
        ld a,"."
        ld (de),a
        inc de
        ld a,l
        call bcd
        xor a
        ld (de),a
        ld a,T_VERSION
        ld e,20
        call row
        call fact
        pop af
        ld l,a
        ld h,0
        call decimal
        ld a,T_API
        ld e,34
        call row
        call fact
        ld a,VX_MEM                 ; the memory (API 18)
        call VOS_EXT
        jr c,.drives
        push de
        call kilo
        ld a,T_MEMORY
        ld e,48
        call row
        call fact
        pop hl
        call kilo
        ld a,T_MEM_FREE
        ld e,62
        call row
        call fact
.drives:
        ld c,0                      ; the drives
        ld a,T_FREE_A
        ld e,76
        call row
        call free
        ld c,1
        ld a,T_FREE_B
        ld e,90
        call row
        ; fall through

; E = pixels below the title -> DE = y (keeps AF, HL, BC)
row:
        push af
        ld a,(place + 4)
        add a,e
        ld e,a
        ld d,0
        pop af
        ret

; C = drive, A = its label, DE = y: "nK", or NO DISC
free:
        push af
        push de
        ld a,VX_FREE
        call VOS_EXT
        jr c,.none
        ld l,a
        ld h,0
        call kilo
        jr .show
.none:
        ld a,T_NO_DISC
        call VOS_MSG
        ld de,value
        ld bc,16
        ldir
.show:
        pop de
        pop af
        ; fall through

; A = label, DE = y: the label, then value at the value's x
fact:
        push de
        ld hl,(place)
        call print_lab
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        pop de
        ld hl,(place + 2)
        ld bc,value
        jp VOS_PRINT

; A = text, HL = x, DE = y: it, in the ink
print_lab:
        push hl
        push de
        call VOS_MSG
        push hl
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        pop bc
        pop de
        pop hl
        jp VOS_PRINT

; HL = number -> value: "nK"
kilo:
        call decimal
        ld a,"K"
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

; HL = number -> value, in decimal, DE -> after it
decimal:
        push ix
        call .number
        pop ix
        ret
.number:
        ld de,value
        ld b,0                      ; 1: a digit was written
        ld ix,tens
.digit:
        push bc
        ld c,(ix+0)
        ld b,(ix+1)
        ld a,"0" - 1
.more:
        inc a
        or a
        sbc hl,bc
        jr nc,.more
        add hl,bc
        pop bc
        ld c,a
        ld a,(ix+0)
        dec a
        jr z,.write                 ; the units always
        ld a,c
        cp "0"
        jr nz,.write
        ld a,b
        or a
        jr z,.next
.write:
        ld a,c
        ld (de),a
        inc de
        ld b,1
.next:
        inc ix
        inc ix
        ld a,(ix+0)
        or (ix+1)
        jr nz,.digit
        xor a
        ld (de),a
        ret

; A = BCD byte -> two digits at DE, DE -> after them
bcd:
        push af
        rrca
        rrca
        rrca
        rrca
        call .nibble
        pop af
.nibble:
        and 15
        add a,"0"
        ld (de),a
        inc de
        ret

; ---------------------------------------------------------------------
event:
        push hl
        call VOS_UI_EVENT
        pop hl
        or a
        ret z
        cp CMD_REFRESH
        jp z,redraw
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        jp VOS_EXIT

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1: pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 4
                db T_REFRESH, CMD_REFRESH, "R", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
tens:           dw 10000, 1000, 100, 10, 1, 0
wsize:          dw 248, 104, 0, 0   ; its window's inside (VX_WINDOW)
place:          dw 0, 0             ; the labels' x, the values' x,
                db 0                ; the title's y (0: in a window)
place_win:      dw 8, 136
                db 0
place_full:     dw 32, 224
                db 20

        include "app_texts.asm"     ; texts, from texts.txt

value:          ds 17

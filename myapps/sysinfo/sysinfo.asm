; =====================================================================
; sysinfo.asm - SYSINFO, what V-OS says about itself (made with the SDK)
;
; Mode 1. The V-OS and API versions (VOS_EXT, VX_VERSION) and the free
; space on drives A: and B: (VX_FREE), read again with ^R. An example
; of VOS_EXT, the calls after the API's jump table (API 15).
;   SYSINFO menu: READ AGAIN ^R, ABOUT, BACK ^Q
;   make app NAME=sysinfo     build/SYSINFO.BIN, and build/vos.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
LABEL_X         equ 32
VALUE_X         equ 224
TOP_Y           equ 40
HINT_Y          equ 249

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
        ld hl,texts
        call VOS_TEXTS
        ld a,1
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
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
        ld hl,LABEL_X
        ld de,TOP_Y - 20
        call VOS_PRINT
        ld a,T_HINT
        ld hl,0
        ld de,HINT_Y
        call print_lab
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
        ld de,TOP_Y
        call fact
        pop af
        ld l,a
        ld h,0
        call decimal
        ld a,T_API
        ld de,TOP_Y + 14
        call fact
        ld c,0                      ; the drives
        ld a,T_FREE_A
        ld de,TOP_Y + 28
        call free
        ld c,1
        ld a,T_FREE_B
        ld de,TOP_Y + 42
        ; fall through

; C = drive, A = its label, DE = y: "nK", or NO DISC
free:
        push af
        push de
        ld a,VX_FREE
        call VOS_EXT
        jr c,.none
        ld l,a
        ld h,0
        call decimal
        ld a,"K"
        ld (de),a
        inc de
        xor a
        ld (de),a
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

; A = label, DE = y: the label, then value at VALUE_X
fact:
        push de
        ld hl,LABEL_X
        call print_lab
        ld a,HEAD + VOS_BOLD
        ld c,BG
        call VOS_COLOURS
        pop de
        ld hl,VALUE_X
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

        include "app_texts.asm"     ; texts, from texts.txt

value:          ds 17

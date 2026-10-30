; =====================================================================
; webget.asm - WEBGET, files from the web with the M4 board (SDK)
;
; GET A FILE asks for an address (HTTP: host/path, or host:port/path)
; and a name, the M4 board downloads it (C_HTTPGETMEM, up to 16K) and
; WEBGET copies it out (C_COPYBUF, 512 bytes at a time) into the data
; bank, then saves it on the drive it shows (OTHER DRIVE changes it).
; The network status comes from C_NETSTAT. All through VOS_EXT, VX_M4
; (API 17). Mode 1.
;   WEBGET menu: GET A FILE ^G, OTHER DRIVE, ABOUT, BACK ^Q
;   make app NAME=webget      build/WEBGET.BIN, and build/vos.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
HEAD            equ 3
X0              equ 16
VALUE_X         equ 128
TOP_Y           equ 40
HINT_Y          equ 249
DATA            equ #4000           ; the file, in the data bank
FILE_MAX        equ #4000
PIECE           equ 512
URL_MAX         equ 46

C_NETSTAT       equ #4323           ; M4 commands (spinpoint.org/cpc/
C_HTTPGETMEM    equ #4328           ; m4info.txt)
C_COPYBUF       equ #4329

CMD_GET         equ VC_APP + 1      ; menu items: commands
CMD_DRIVE       equ VC_APP + 2
CMD_ABOUT       equ VC_APP + 3
CMD_BACK        equ VC_APP + 4

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

init:
        push af
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
        pop af
        cp 2
        jr z,redraw
        ld a,(VOS_SELF)             ; files on its own drive at first
        ld (fdrive),a
        ; fall through

; everything, again
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
        ld hl,X0
        ld de,TOP_Y - 20
        call VOS_PRINT
        ld a,T_HINT
        ld hl,0
        ld de,HINT_Y
        call print_lab
        ld hl,netstat               ; the network
        ld de,resp
        ld bc,3 + 40
        ld a,VX_M4
        call VOS_EXT
        jr nc,.m4
        ld a,T_NO_M4
        call VOS_MSG
        ld de,value
        call copy_z
        jr .net
.m4:
        ld hl,resp + 3              ; its status, up to the end of line
        ld de,value
        ld b,40
.char:
        ld a,(hl)
        cp 32
        jr c,.end
        ld (de),a
        inc hl
        inc de
        djnz .char
.end:
        xor a
        ld (de),a
.net:
        ld a,T_NETWORK
        ld de,TOP_Y
        call fact
        ld hl,url
        ld de,value
        call copy_z
        ld a,T_URL
        ld de,TOP_Y + 14
        call fact
        ld a,(fdrive)
        add a,"A"
        ld (value),a
        ld a,":"
        ld (value + 1),a
        xor a
        ld (value + 2),a
        ld a,T_DRIVE_L
        ld de,TOP_Y + 28
        jp fact

; A = text: the status line under the facts
state:
        push af
        ld hl,blank
        ld de,TOP_Y + 56
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,TOP_Y + 56
        ld bc,blank
        call VOS_PRINT
        pop af
        ld hl,X0
        ld de,TOP_Y + 56
        ; fall through

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

; A = label, DE = y: the label, then value at VALUE_X in yellow
fact:
        push de
        ld hl,X0
        call print_lab
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        pop de
        ld hl,VALUE_X
        ld bc,value
        jp VOS_PRINT

; HL -> zero-terminated text -> DE (with its zero); DE -> the zero
copy_z:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr copy_z

; ---------------------------------------------------------------------
event:
        push hl
        call VOS_UI_EVENT
        pop hl
        or a
        ret z
        cp CMD_GET
        jr z,get
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,fdrive
        ld a,(hl)
        xor 1
        ld (hl),a
        jp redraw
.not_drive:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        jp VOS_EXIT

; GET A FILE: the address, a name from its end, the download, the copy
; into the data bank, the file
get:
        ld a,T_URL_T
        ld hl,url
        ld c,URL_MAX
        call VOS_INPUT
        ret c
        ld a,(url)
        or a
        ret z
        call name_from_url
        ld a,T_NAME_T
        ld hl,name_in
        ld c,12
        call VOS_INPUT
        jp c,redraw
        call redraw
        call make_name
        ret c
        ld a,T_GETTING
        call state
        ld hl,url                   ; C_HTTPGETMEM: dw size, the address
        ld de,pk_get + 5
        call copy_z
        ex de,hl                    ; the packet's size: up to the zero
        ld de,pk_get
        or a
        sbc hl,de
        ld a,l
        ld (pk_get),a
        ld hl,pk_get
        ld de,resp
        ld bc,3 + 2
        ld a,VX_M4
        call VOS_EXT
        jp c,redraw
        ld hl,(resp + 3)            ; bytes downloaded
        ld (flen),hl
        ld a,h
        or l
        ld a,T_NOTHING
        jp z,state
        ld hl,0                     ; out, a piece at a time
        ld (done),hl
.piece:
        ld hl,(flen)
        ld de,(done)
        or a
        sbc hl,de
        jr z,.copied
        ld de,PIECE
        push hl
        sbc hl,de
        pop hl
        jr c,.short
        ex de,hl
.short:
        ld (cmd_copy + 5),hl        ; this piece's size, and from where
        ld (pc_n),hl
        ld hl,(done)
        ld (cmd_copy + 3),hl
        ld hl,cmd_copy
        ld de,resp
        ld bc,(pc_n)
        inc bc
        inc bc
        inc bc
        ld a,VX_M4
        call VOS_EXT
        jp c,redraw
        ld hl,(done)                ; into the data bank
        ld de,DATA
        add hl,de
        ex de,hl
        ld hl,resp + 3
        ld bc,(pc_n)
        call VOS_BANK_PUT
        ld hl,(done)
        ld de,(pc_n)
        add hl,de
        ld (done),hl
        jr .piece
.copied:
        ld a,(fdrive)
        or VOS_DATA
        ld hl,fname
        ld de,DATA
        ld bc,(flen)
        call VOS_SAVE
        jp c,VOS_ERROR
        ld a,T_SAVED                ; SAVED, BYTES: n
        call state
        ld hl,(flen)
        call decimal
        ld a,HEAD
        ld c,BG
        call VOS_COLOURS
        ld hl,VALUE_X + 16
        ld de,TOP_Y + 56
        ld bc,value
        jp VOS_PRINT

; url -> name_in: the part after the last "/" ("INDEX.HTM" if none)
name_from_url:
        ld hl,url
        ld de,url
.find:
        ld a,(hl)
        or a
        jr z,.found
        inc hl
        cp "/"
        jr nz,.find
        ld d,h
        ld e,l
        jr .find
.found:
        ex de,hl
        ld a,(hl)
        or a
        jr nz,.copy
        ld hl,index_htm
.copy:
        ld de,name_in
        ld b,12
.char:
        ld a,(hl)
        or a
        jr z,.end
        cp "?"
        jr z,.end
        ld (de),a
        inc hl
        inc de
        djnz .char
.end:
        xor a
        ld (de),a
        ret

; name_in "name.ext" -> fname, 11 bytes in capitals; carry if empty
make_name:
        ld hl,fname
        ld b,11
.clear:
        ld (hl)," "
        inc hl
        djnz .clear
        ld hl,name_in
        ld a,(hl)
        or a
        scf
        ret z
        ld de,fname
        ld b,8
        call .part
        ld a,(hl)
        cp "."
        jr nz,.no_ext
        inc hl
        ld de,fname + 8
        ld b,3
        call .part
.no_ext:
        or a
        ret
; up to B characters to DE, until "." or the end
.part:
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        cp "a"
        jr c,.cap
        cp "z" + 1
        jr nc,.cap
        sub 32
.cap:
        ld (de),a
        inc hl
        inc de
        djnz .part
.skip:                              ; the rest of a long part: left out
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        inc hl
        jr .skip

; HL = number -> value, in decimal
decimal:
        ld de,value
        ld b,0                      ; 1: a digit was written
        push ix
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
        jr z,.write
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
        pop ix
        ret

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1: pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 5
                db T_GET, CMD_GET, "G", 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
tens:           dw 10000, 1000, 100, 10, 1, 0
netstat:        db 2
                dw C_NETSTAT
index_htm:      db "INDEX.HTM", 0
blank:          ds 48, " "
                db 0

        include "app_texts.asm"     ; texts, from texts.txt

fdrive:         db 0
url:            db "example.com/index.html", 0
                ds URL_MAX + 2 - 23
name_in:        ds 14
fname:          ds 11
flen:           dw 0
done:           dw 0
pc_n:           dw 0
pk_get:        db 0                ; C_HTTPGETMEM: size, command,
                dw C_HTTPGETMEM     ; bytes wanted, the address
                dw FILE_MAX
                ds URL_MAX + 2
cmd_copy:       db 6                ; C_COPYBUF: size, command, from,
                dw C_COPYBUF        ; bytes
                dw 0, 0
value:          ds 50
resp:           ds 3 + PIECE + 8

; =====================================================================
; music.asm - MUSIC, a player of Arkos Tracker songs for V-OS (made
; with the SDK)
;
; Mode 1. OPEN (^O) lists the .MUS files of a drive (tools/mkmusic.py
; makes them from Arkos Tracker's .aks songs); the song is loaded into
; the data bank, copied here and its pointers moved to where it is now.
; PLAY and STOP (SPACE), the buttons or the menu. The song is played by
; Targhan's AKM player (PlayerAkm.asm, Arkos Tracker 3, MIT licence),
; one frame each interrupt frame (VX_IRQ: irq_play), so it goes on
; evenly behind views, other programs and their drawing. On a V-OS
; without VX_IRQ it plays a frame each VE_FRAME instead, with the
; interrupts off (it borrows the stack, and the keyboard reads the AY
; too), in the background too (VOS_BACKGROUND). Three bars show the
; channels' volumes. Studio's MUSIC block starts it
; behind a program (VX_BEHIND, init A = 3) with a song.
;   make app NAME=music       build/MUSIC.BIN, on build/music.dsk with
;                             the songs of owndisc/ (make songs)
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
BAR_PEN         equ 3
SONG_MAX        equ 6144            ; tools/mkmusic.py
DATA            equ #4000           ; the file, in the data bank
BAR_X           equ 120             ; the volume bars
BAR_Y           equ 160
BAR_H           equ 60

CMD_OPEN        equ VC_APP + 1
CMD_PLAY        equ VC_APP + 2
CMD_STOP        equ VC_APP + 3
CMD_DRIVE       equ VC_APP + 4
CMD_ABOUT       equ VC_APP + 5
CMD_BACK        equ VC_APP + 6

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start; 2: back to the front, the song as it was; 3:
; started behind another program (VX_BEHIND: Studio's MUSIC block) for
; VOS_OPEN's song, which plays there, with nothing drawn or asked
init:
        cp 3
        jr nz,.front
        ld a,1
        ld (quiet),a
        call irq_on
        call VOS_BACKGROUND
        call open_arg
        xor a
        ld (quiet),a
        ret
.front:
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
        ld hl,widgets
        call VOS_SET_WIDGETS
        ld a,1                      ; VE_FRAME events, 50 a second
        call VOS_TICKS
        call irq_on                 ; and behind other programs too, if
        call VOS_BACKGROUND         ; it plays there by them
        pop af
        cp 2
        jr z,.back
        ld a,(VOS_SELF)
        ld (fdrive),a
.back:
        call redraw
        ; fall through

; a song to open from the Desktop or the Commander (VOS_OPEN): taken,
; loaded as OPEN does, and played
open_arg:
        ld hl,VOS_OPEN
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        ld a,(playing)              ; that song playing already: on
        or a
        jr z,.new
        ld a,(fdrive)
        inc hl
        cp (hl)
        jr nz,.new
        ld de,sname
        ld b,8
.same:
        inc hl
        ld a,(de)
        cp (hl)
        jr nz,.new
        inc de
        djnz .same
        ret
.new:
        call stop_song
        ld a,(VOS_OPEN + 1)
        ld (fdrive),a
        ld hl,VOS_OPEN + 2
        ld de,name_tmp
        ld bc,11
        ldir
        jp load_file

; everything, again
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        call VOS_DRAW_WIDGETS
        ld a,T_HINT
        ld hl,8
        ld de,248
        ld c,46
        call print_lab
        ld a,T_BEHIND
        ld hl,8
        ld de,236
        ld c,46
        call print_lab
        xor a                       ; the bars' places
        ld (shown),a
        ld (shown + 1),a
        ld (shown + 2),a
        ; fall through

; the song's name, drive and state (not behind: VX_BEHIND)
draw_state:
        ld a,(quiet)
        or a
        ret nz
        ld de,lbuf
        ld a,(fdrive)
        add a,"A"
        ld (de),a
        inc de
        ld a,":"
        ld (de),a
        inc de
        ld a,(loaded)
        or a
        jr z,.none
        ld hl,sname
        ld b,8
.name:
        ld a,(hl)
        cp " "
        jr z,.named
        ld (de),a
        inc de
        inc hl
        djnz .name
.named:
        ld b,30
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
        xor a
        ld (de),a
        call colours
        ld hl,8
        ld de,24
        ld bc,lbuf
        call VOS_PRINT
        ld a,(playing)
        or a
        ld a,T_STOPPED
        jr z,.state
        ld a,T_PLAYING
.state:
        ld hl,8
        ld de,40
        ld c,30
        jp print_lab
.none:
        xor a
        ld (de),a
        call colours
        ld hl,8
        ld de,24
        ld bc,lbuf
        call VOS_PRINT
        ld a,T_NO_SONG
        ld hl,24
        ld de,24
        ld c,30
        jp print_lab

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        ld a,(hl)
        cp VE_FRAME
        jr z,frame
        push hl
        call VOS_UI_EVENT
        pop hl
        or a
        jp nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(hl)
        cp VE_KEY_DOWN
        ret nz
        inc hl
        ld a,(hl)
        cp VK_SPACE
        ret nz
        ld a,(playing)              ; SPACE: play or stop
        or a
        jp nz,stop_song
        jp play_song

; the song from the interrupt (VX_IRQ: irq_play), if V-OS has it ->
; by_irq; A = 1: it plays by the frame events instead, behind other
; programs too (VOS_BACKGROUND)
irq_on:
        ld hl,irq_play
        ld a,VX_IRQ
        call VOS_EXT
        sbc a,a                     ; carry: 0, else 1
        inc a
        ld (by_irq),a
        xor 1
        ret

; the interrupt, once a frame (VX_IRQ): a frame of the song. IY and the
; other registers (EXX, AF') are kept for the program interrupted
irq_play:
        ld a,(playing)
        or a
        ret z
        ex af,af'
        push af
        exx
        push bc
        push de
        push hl
        push iy
        call PLY_AKM_Play
        pop iy
        pop hl
        pop de
        pop bc
        exx
        pop af
        ex af,af'
        ret

; a frame of the song (without VX_IRQ), and the bars (in front, with no
; menu open)
frame:
        ld a,(playing)
        or a
        ret z
        ld a,(by_irq)
        or a
        jr nz,.bars
        push ix
        push iy
        di
        call PLY_AKM_Play
        ei
        pop iy
        pop ix
.bars:
        call VOS_MENU_OPEN          ; (in the background: Z, and the
        ret nz                      ; drawing does nothing)
        ld hl,PLY_AKM_Track1_Volume
        ld c,0
        call draw_bar
        ld hl,PLY_AKM_Track2_Volume
        ld c,1
        call draw_bar
        ld hl,PLY_AKM_Track3_Volume
        ld c,2
        ; fall through

; HL -> a channel's volume (16: the hardware envelope, as 15), C =
; channel: its bar, if it changed
draw_bar:
        ld a,(hl)
        bit 4,a
        jr z,.soft
        ld a,15
.soft:
        and 15
        ld e,a                      ; height = 4 x volume
        ld b,0
        ld hl,shown
        add hl,bc
        cp (hl)
        ret z
        ld (hl),a
        ld a,c                      ; x = BAR_X + 48 n
        add a,a
        add a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,BAR_X
        ld l,a
        ld h,0
        ld (rect),hl
        ld a,e
        add a,a
        add a,a
        ld d,a
        ld a,BAR_Y + BAR_H          ; the empty part, then the bar
        sub d
        push af
        push de
        ld hl,BAR_Y
        ld (rect + 2),hl
        sub BAR_Y
        ld l,a
        ld (rect + 6),hl
        ld a,BG
        call .rect
        pop de
        pop af
        ld l,a
        ld h,0
        ld (rect + 2),hl
        ld l,d
        ld (rect + 6),hl
        ld a,BAR_PEN
.rect:
        ld (rect + 8),a
        ld hl,(rect + 6)
        ld a,h
        or l
        ret z
        push ix
        ld ix,rect
        call VOS_RECT
        pop ix
        ret

; A = command (a menu item or a button)
command:
        cp CMD_OPEN
        jp z,open
        cp CMD_PLAY
        jr z,play_song
        cp CMD_STOP
        jr z,stop_song
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,fdrive
        ld a,(hl)
        xor 1
        ld (hl),a
        jp draw_state
.not_drive:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        call stop_song
        jp VOS_EXIT

; PLAY: from the start, if there is a song
play_song:
        ld a,(loaded)
        or a
        ret z
        xor a                       ; not from the interrupt meanwhile
        ld (playing),a
        push ix
        push iy
        ld hl,song
        xor a                       ; the first subsong
        call PLY_AKM_Init
        pop iy
        pop ix
        ld a,1
        ld (playing),a
        jp draw_state

; STOP: silence
stop_song:
        ld a,(playing)
        or a
        ret z
        xor a
        ld (playing),a
        push ix
        push iy
        di
        call PLY_AKM_Stop
        ei
        pop iy
        pop ix
        jp draw_state

; ---------------------------------------------------------------------
; OPEN: a .MUS of fdrive into the data bank, then here, its pointers
; moved by song - #4000
; ---------------------------------------------------------------------
open:
        ld a,(fdrive)
        or VOS_CAT_EXT
        ld hl,ext_mus
        call VOS_CATALOG
        jp c,VOS_ERROR
        or a
        ret z
        ld (cat),hl
        ld a,T_OPEN_T
        call VOS_FILE_PICK
        ret c
        call stop_song
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cat)
        add hl,de
        ld de,name_tmp
        ld bc,11
        ldir
load_file:                          ; name_tmp on fdrive
        xor a
        ld (loaded),a
        ld a,(fdrive)
        or VOS_DATA
        ld hl,name_tmp
        ld de,DATA
        call VOS_LOAD
        jp c,error
        ld hl,DATA                  ; the header
        ld de,hdr
        ld bc,8
        call VOS_BANK_GET
        ld hl,(hdr)
        ld de,"M" * 256 + "V"
        or a
        sbc hl,de
        jr nz,.bad
        ld hl,(hdr + 4)             ; the song's size
        ld de,SONG_MAX + 1
        or a
        sbc hl,de
        jr nc,.bad
        ld hl,DATA + 8
        ld de,song
        ld bc,(hdr + 4)
        call VOS_BANK_GET
        ld hl,(hdr + 4)             ; its pointers, one by one
        ld de,DATA + 8
        add hl,de
        ld (rp_from),hl
        ld bc,(hdr + 6)
.ptr:
        ld a,b
        or c
        jr z,.moved
        push bc
        ld hl,(rp_from)
        ld de,rp_buf
        ld bc,2
        call VOS_BANK_GET
        ld hl,(rp_from)
        inc hl
        inc hl
        ld (rp_from),hl
        ld de,(rp_buf)              ; the word at song + offset
        ld hl,song
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld hl,song - DATA
        add hl,de
        ex de,hl
        pop hl
        ld (hl),d
        dec hl
        ld (hl),e
        pop bc
        dec bc
        jr .ptr
.moved:
        ld hl,name_tmp
        ld de,sname
        ld bc,8
        ldir
        ld a,1
        ld (loaded),a
        jp play_song
.bad:
        ld a,(quiet)
        or a
        ret nz
        ld hl,dlg_not_song
        call VOS_DIALOG
        jp draw_state

; A = error: shown, but not behind (VX_BEHIND)
error:
        ld c,a
        ld a,(quiet)
        or a
        ret nz
        ld a,c
        jp VOS_ERROR

; A = text, HL = x, DE = y, C = width: it, then spaces to the width
print_lab:
        push hl
        push de
        push bc
        call VOS_MSG
        pop bc
        ld b,c
        ld de,lbuf
.copy:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .copy
        jr .end
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.end:
        xor a
        ld (de),a
        call colours
        pop de
        pop hl
        ld bc,lbuf
        jp VOS_PRINT

colours:
        ld a,INK
        ld c,BG
        jp VOS_COLOURS

        include "PlayerAkm.asm"     ; Targhan's AKM player (MIT licence)

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1 uses pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1

bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 7
                db T_OPEN, CMD_OPEN, "O", 0
                db T_PLAY, CMD_PLAY, 0, 0
                db T_STOP, CMD_STOP, 0, 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
widgets:        db 3                ; buttons: dw x, y; db width,
                dw 8, 72            ; text, command, 0
                db 12, T_PLAY, CMD_PLAY, 0
                dw 120, 72
                db 12, T_STOP, CMD_STOP, 0
                dw 232, 72
                db 12, T_OPEN, CMD_OPEN, 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_not_song:   db T_MENU, T_NOT_SONG, 1, VM_OK
ext_mus:        db "MUS"

        include "app_texts.asm"     ; texts, from texts.txt

fdrive:         db 0
quiet:          db 0                ; 1: started behind (init A = 3)
loaded:         db 0
playing:        db 0
by_irq:         db 0                ; 1: played from the interrupt (VX_IRQ)
shown:          db 0, 0, 0          ; the bars' heights drawn
sname:          ds 8
name_tmp:       ds 11
cat:            dw 0
hdr:            ds 8
rp_from:        dw 0
rect:           dw 0, 0, 40, 0
                db 0
lbuf:           ds 48
rp_buf:         dw 0
song:           ds SONG_MAX

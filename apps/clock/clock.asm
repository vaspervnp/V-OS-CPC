; =====================================================================
; clock.asm - CLOCK: the time since V-OS started, and the first desk
; accessory (src/api/vos_api.inc)
;
; As a program (Launcher, RUN): mode 1, the time in the middle of the
; screen, a menu of its own and the shared ones. As the accessory
; (Launcher: FILE > AS ACCESSORY, then F5): a small window over what is
; on the screen, in whatever mode is selected; F5 or ESC closes it, its
; title bar drags it (VOS_DRAG).
; The time comes from VOS_FRAMES (50 a second, 24 bits: almost four
; days). With an M4 board it is the real time: C_TIME (VX_M4) gives
; "hh:mm:ss yyyy-mm-dd" (from its NTP server), and the frames count on
; from it; it is asked again when a day ends. The program shows the
; date under it.
;
; Built twice, at #4000 and #4100, for its relocation table (Makefile,
; tools/mkreloc.py):
;   rasm apps/clock/clock.asm -I src -I build -o build/clock
; =====================================================================

        include "api/vos_api.inc"

WW              equ 96              ; the accessory's window (wx, wy)              ; 12 characters (8 pixels in either
WH              equ 34              ; mode)
TIME_Y          equ 120             ; the program's screen (mode 1)
CMD_BACK        equ 1
C_TIME          equ #4324           ; the M4 board (spinpoint.org/cpc/
                                    ; m4info.txt)

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "icon_clock.asm"    ; VOS_ICON, from apps/icons/clock.txt

; A = 1: the accessory, 0: the program, 2: the program again (it has
; nothing to keep)
init:
        and 1
        ld (accessory),a
        ld hl,texts
        call VOS_TEXTS
        ld a,1
        call VOS_TICKS
        call m4_sync
        ld a,(accessory)
        or a
        jr nz,redraw
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
        ; fall through

redraw:
        ld a,#FF                    ; the time is drawn whatever it is
        ld (last),a
        ld a,(accessory)
        or a
        jr z,.program
        ld hl,(wx)                  ; on the screen of this mode
        ld de,(wy)
        ld bc,WW
        ld a,WH
        call VOS_FIT
        ld (wx),hl
        ld (wy),de
        ld bc,WW                    ; a window: a white title bar
        ld a,WH
        ld ix,1
        call box
        ld hl,(wx)                  ; and a body of pen 0
        inc hl
        ld de,(wy)
        ld a,10
        call add_de
        ld bc,WW - 2
        ld a,WH - 11
        ld ix,0
        call box
        ld a,0                      ; "CLOCK" in the title bar
        ld c,1
        call VOS_COLOURS
        ld a,T_CLOCK
        ld hl,(wx)
        ld de,4
        add hl,de
        ld de,(wy)
        inc de
        call print_msg
        jr time
.program:
        xor a
        call VOS_CLS
        call VOS_DRAW_BAR
        ld a,1
        ld c,0
        call VOS_COLOURS
        ld a,T_CLOCK
        ld hl,168
        ld de,TIME_Y - 40
        call print_msg
        ld a,(m4_on)                ; the date, or "since V-OS started"
        or a
        jr z,.since
        ld hl,152
        ld de,TIME_Y - 20
        ld bc,date_text
        call VOS_PRINT
        jr .hint
.since:
        ld a,T_SINCE
        ld hl,120
        ld de,TIME_Y - 20
        call print_msg
.hint:
        ld a,T_HINT
        ld hl,128
        ld de,TIME_Y + 40
        call print_msg
        ; fall through

; the time, if a second has passed
time:
        call VOS_FRAMES             ; A:HL frames
        ld e,a
        ld a,(m4_on)
        or a
        jr z,.since
        ld bc,(f0)                  ; the M4's time: frames since it
        or a                        ; was asked
        sbc hl,bc
        ld a,(f0 + 2)
        ld b,a
        ld a,e
        sbc a,b
        ld e,a
.since:
        ld c,50
        call div24                  ; E:HL seconds
        ld a,(m4_on)
        or a
        jr z,.seconds
        ld bc,(base)                ; and its seconds then
        add hl,bc
        ld a,(base + 2)
        adc a,e
        ld e,a
.seconds:
        ld a,(last)
        cp l
        ret z
        ld a,l
        ld (last),a
        ld c,60
        call div24
        push af                     ; seconds
        ld c,60
        call div24                  ; A minutes, L hours
        push af
        ld a,l
        cp 24
        jr c,.day
        pop af                      ; a day has ended: the M4 again
        pop af
        call m4_sync
        jp redraw
.day:
        ld de,clock_text
        call two
        pop af
        call two
        pop af
        call two
        ld a,1
        ld c,0
        call VOS_COLOURS
        ld bc,clock_text
        ld a,(accessory)
        or a
        jr z,.program
        ld hl,(wx)
        ld de,16
        add hl,de
        ld de,(wy)
        ld a,18
        call add_de
        jp VOS_PRINT
.program:
        ld hl,160
        ld de,TIME_Y
        jp VOS_PRINT

; C_TIME -> m4_on, base (the seconds of the day), f0 (the frames then)
; and date_text; no M4 board, or not its answer: m4_on 0
m4_sync:
        xor a
        ld (m4_on),a
        ld hl,time_cmd
        ld de,resp
        ld bc,3 + 20
        ld a,VX_M4
        call VOS_EXT
        ret c
        ld a,(resp)                 ; size: the command and 19 or more
        cp 2 + 19
        ret c
        ld hl,resp + 3
        ld a,(resp + 5)             ; "hh:"
        cp ":"
        ret nz
        call digits2                ; hours
        ret c
        ld b,a
        ld hl,0
        ld e,l
        inc b
.hours:
        dec b
        jr z,.hours_done
        ld a,b
        ld bc,3600
        add hl,bc
        ld b,a
        jr nc,.hours
        inc e
        jr .hours
.hours_done:
        push hl
        ld hl,resp + 6
        call digits2                ; minutes
        pop hl
        ret c
        ld b,a
        inc b
.minutes:
        dec b
        jr z,.minutes_done
        ld a,b
        ld bc,60
        add hl,bc
        ld b,a
        jr nc,.minutes
        inc e
        jr .minutes
.minutes_done:
        push hl
        ld hl,resp + 9
        call digits2                ; seconds
        pop hl
        ret c
        ld c,a
        ld b,0
        add hl,bc
        jr nc,.base
        inc e
.base:
        ld (base),hl
        ld a,e
        ld (base + 2),a
        call VOS_FRAMES
        ld (f0),hl
        ld (f0 + 2),a
        ld hl,resp + 3 + 9          ; "yyyy-mm-dd"
        ld de,date_text
        ld bc,10
        ldir
        ld a,1
        ld (m4_on),a
        ret

; HL -> two digits -> A = their number; carry if they are not digits
digits2:
        ld a,(hl)
        sub "0"
        ret c
        cp 10
        ccf
        ret c
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        ld b,a
        inc hl
        ld a,(hl)
        sub "0"
        ret c
        cp 10
        ccf
        ret c
        add a,b
        ret

; A = 0..99 -> two digits and a separator at DE (the last stays 0)
two:
        ld b,"0" - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,"0" + 10
        ex de,hl
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        inc hl
        ex de,hl
        ret

; E:HL / C -> E:HL, A = the remainder
div24:
        xor a
        ld b,24
.bit:
        add hl,hl
        rl e
        rla
        cp c
        jr c,.next
        sub c
        inc l
.next:
        djnz .bit
        ret

; DE + A
add_de:
        add a,e
        ld e,a
        ret nc
        inc d
        ret

; HL = x, DE = y, BC = w, A = h, IX = pen: a filled rectangle
box:
        ld (rect),hl
        ld (rect + 2),de
        ld (rect + 4),bc
        ld (rect + 6),a
        ld a,ixl
        ld (rect + 8),a
        ld ix,rect
        jp VOS_RECT

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

; HL -> event
event:
        ld a,(hl)
        cp VE_FRAME
        jp z,time
        ld a,(accessory)
        or a
        jr nz,.acc
        push hl
        call VOS_UI_EVENT           ; menus and shortcuts first
        pop hl
        or a
        jr nz,command
        push hl
        call VOS_MENU_OPEN
        pop hl
        ret nz
        ld a,(hl)
.keys:
        cp VE_KEY_DOWN
        ret nz
        inc hl
        ld a,(hl)
        cp VK_ESC
        ret nz
        jp VOS_EXIT

; the accessory: its title bar drags it (the kernel draws it again)
.acc:
        ld a,(hl)
        cp VE_PTR_DOWN
        jr nz,.keys
        ld hl,(wx)
        ld de,(wy)
        ld bc,WW
        ld a,WH
        call VOS_DRAG
        ret nc
        ld (wx),hl
        ld (wy),de
        ret

; A = command
command:
        cp CMD_BACK
        jp z,VOS_EXIT
        jp VOS_COMMAND              ; VIEW and HELP menus

; ---- data -----------------------------------------------------------
palette:        db 1, 26, 0, 11     ; the Desktop's colours
                db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                db 1

bar:            db 3
                dw menu, 0, 0
menu:           db T_CLOCK, 1
                db T_BACK, CMD_BACK, "Q", 0

        include "clock_texts.asm"   ; T_*, texts, from apps/clock/texts.txt

accessory:      db 0
last:           db 0                ; the seconds drawn (low byte)
wx:             dw 8                ; the accessory's window
wy:             dw 16
clock_text:     db "00:00:00", 0
m4_on:          db 0                ; 1: the M4's time (m4_sync)
base:           ds 3                ; its seconds of the day then,
f0:             ds 3                ; and VOS_FRAMES then
date_text:      db "0000-00-00", 0
time_cmd:       db 2
                dw C_TIME
resp:           ds 3 + 20
rect:           dw 0, 0, 0, 0
                db 0
clock_end:
        IFDEF VOS_RELOC_PASS
        save "build/clock_hi.bin", VOS_APP_ADDR, clock_end - VOS_APP_ADDR
        ELSE
        save "build/clock_lo.bin", VOS_APP_ADDR, clock_end - VOS_APP_ADDR
        ENDIF

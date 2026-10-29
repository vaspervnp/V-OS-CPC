; =====================================================================
; clock.asm - CLOCK: the time since V-OS started, and the first desk
; accessory (src/api/vos_api.inc)
;
; As a program (Launcher, RUN): mode 1, the time in the middle of the
; screen, a menu of its own and the shared ones. As the accessory
; (Launcher: FILE > AS ACCESSORY, then F5): a small window over what is
; on the screen, in whatever mode is selected; F5 or ESC closes it.
; The time comes from VOS_FRAMES (50 a second, 24 bits: almost four
; days).
;
; Built twice, at #4000 and #4100, for its relocation table (Makefile,
; tools/mkreloc.py):
;   rasm apps/clock/clock.asm -I src -I build -o build/clock
; =====================================================================

        include "api/vos_api.inc"

WX              equ 8               ; the accessory's window
WY              equ 16
WW              equ 96              ; 12 characters (8 pixels in either
WH              equ 34              ; mode)
TIME_Y          equ 120             ; the program's screen (mode 1)
CMD_BACK        equ 1

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
        ld hl,WX                    ; a window: a white title bar
        ld de,WY
        ld bc,WW
        ld a,WH
        ld ix,1
        call box
        ld hl,WX + 1                ; and a body of pen 0
        ld de,WY + 10
        ld bc,WW - 2
        ld a,WH - 11
        ld ix,0
        call box
        ld a,0                      ; "CLOCK" in the title bar
        ld c,1
        call VOS_COLOURS
        ld a,T_CLOCK
        ld hl,WX + 4
        ld de,WY + 1
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
        ld a,T_SINCE
        ld hl,120
        ld de,TIME_Y - 20
        call print_msg
        ld a,T_HINT
        ld hl,128
        ld de,TIME_Y + 40
        call print_msg
        ; fall through

; the time, if a second has passed
time:
        call VOS_FRAMES             ; A:HL frames
        ld e,a
        ld c,50
        call div24                  ; E:HL seconds
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
        ld hl,WX + 16
        ld de,WY + 18
        ld a,(accessory)
        or a
        jp nz,VOS_PRINT
        ld hl,160
        ld de,TIME_Y
        jp VOS_PRINT

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
        jr nz,.key
        push hl
        call VOS_UI_EVENT           ; menus and shortcuts first
        pop hl
        or a
        jr nz,command
        push hl
        call VOS_MENU_OPEN
        pop hl
        ret nz
.key:
        ld a,(hl)
        cp VE_KEY_DOWN
        ret nz
        inc hl
        ld a,(hl)
        cp VK_ESC
        ret nz
        jp VOS_EXIT

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
clock_text:     db "00:00:00", 0
rect:           dw 0, 0, 0, 0
                db 0
clock_end:
        IFDEF VOS_RELOC_PASS
        save "build/clock_hi.bin", VOS_APP_ADDR, clock_end - VOS_APP_ADDR
        ELSE
        save "build/clock_lo.bin", VOS_APP_ADDR, clock_end - VOS_APP_ADDR
        ENDIF

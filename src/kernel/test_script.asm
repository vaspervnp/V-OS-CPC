; =====================================================================
; test_script.asm - scripted key presses for emulator tests
;
; Built only with -DTEST_SCRIPT=1 (make test-input). Caprice32 can type
; text into the emulated CPC but cannot press cursor keys or COPY, so
; this script ORs key bits into kbd_now after each matrix scan, by frame
; number since boot. Everything after the scan (events, repeat, pointer)
; runs as for real keys. Keys the harness types itself are masked out:
; Z (used to wait, tools/cap32_shot.sh) and SHIFT, \ and 8 (Caprice32
; types "\(" before taking a screenshot). Otherwise their events would
; keep the pointer hidden at the moment of the shot.
;
; M3 desktop, mode 1, Greek UI. Expected result:
;   frame  100  ESC          -> FILE menu open
;   frame  200  RIGHT        -> VIEW menu
;   frame  260  DOWN         -> "MODE 0" selected
;   frame  320  ESC          -> menu closed
;   frame  360  TAB, 400 TAB -> focus on the third button (KEYS)
;   frame  440  RETURN       -> keys dialog
;   frame  560  RETURN       -> dialog closed, status "KEYS"
;   frame  600  CONTROL+Q    -> exit dialog (YES / NO)
;   frame  700  ESC          -> NO
;   frame  760  ESC, 800 RIGHT, 840 DOWN, 880 RETURN -> mode 0
;   frame  960  ESC          -> FILE menu in mode 0
;   frame 1040  RIGHT        -> VIEW menu in mode 0
;   frame 1120  ESC          -> closed
;   frame 1160  CONTROL+L    -> English UI
;   frame 1200  UP held, 1250 LEFT held -> pointer on the VIEW title
;   frame 1310  COPY         -> VIEW opens (mouse)
;   frame 1340  COPY         -> same title again: closes
;   frame 1370  COPY         -> opens again
;   frame 1400  RETURN       -> MODE 1: mode 1, English, status MODE 1
; =====================================================================

; ---------------------------------------------------------------------
; test_inject - interrupt context, right after the matrix is read
; Destroys: AF, DE, HL, IX
; ---------------------------------------------------------------------
test_inject:
        ld a,(kbd_now + 8)          ; hide Z: the harness types it as a wait
        and %01111111
        ld (kbd_now + 8),a
        ld a,(kbd_now + 2)          ; hide SHIFT and \, and 8 below: Caprice32
        and %10011111               ; types "\(" just before each screenshot
        ld (kbd_now + 2),a
        ld a,(kbd_now + 5)
        and %11111110
        ld (kbd_now + 5),a
        ld hl,(int_frames)
        ld ix,test_keys
.entry:
        ld e,(ix+0)
        ld d,(ix+1)
        ld a,d
        and e
        inc a
        ret z                       ; #FFFF ends the script
        push hl
        or a
        sbc hl,de                   ; before the start?
        pop hl
        jr c,.next
        ld e,(ix+2)
        ld d,(ix+3)
        push hl
        or a
        sbc hl,de                   ; before the end?
        pop hl
        jr nc,.next
        push hl
        ld a,(ix+4)
        ld hl,kbd_now
        ld e,a
        ld d,0
        add hl,de
        ld a,(ix+5)
        or (hl)
        ld (hl),a
        pop hl
.next:
        ld de,6
        add ix,de
        jr .entry

; dw first frame, frame after the last; db matrix line, bits
test_keys:
        dw  100,  104 : db 8, %00000100   ; ESC
        dw  200,  204 : db 0, %00000010   ; RIGHT
        dw  260,  264 : db 0, %00000100   ; DOWN
        dw  320,  324 : db 8, %00000100   ; ESC
        dw  360,  364 : db 8, %00010000   ; TAB
        dw  400,  404 : db 8, %00010000   ; TAB
        dw  440,  444 : db 2, %00000100   ; RETURN
        dw  560,  564 : db 2, %00000100   ; RETURN
        dw  600,  612 : db 2, %10000000   ; CONTROL held ...
        dw  603,  607 : db 8, %00001000   ; ... Q
        dw  700,  704 : db 8, %00000100   ; ESC
        dw  760,  764 : db 8, %00000100   ; ESC
        dw  800,  804 : db 0, %00000010   ; RIGHT
        dw  840,  844 : db 0, %00000100   ; DOWN
        dw  880,  884 : db 2, %00000100   ; RETURN
        dw  960,  964 : db 8, %00000100   ; ESC
        dw 1040, 1044 : db 0, %00000010   ; RIGHT
        dw 1120, 1124 : db 8, %00000100   ; ESC
        dw 1160, 1172 : db 2, %10000000   ; CONTROL held ...
        dw 1163, 1167 : db 4, %00010000   ; ... L
        dw 1200, 1246 : db 0, %00000001   ; UP
        dw 1250, 1273 : db 1, %00000001   ; LEFT (x 96 -> about 61)
        dw 1310, 1313 : db 1, %00000010   ; COPY
        dw 1340, 1343 : db 1, %00000010   ; COPY
        dw 1370, 1373 : db 1, %00000010   ; COPY
        dw 1400, 1404 : db 2, %00000100   ; RETURN
        dw #FFFF

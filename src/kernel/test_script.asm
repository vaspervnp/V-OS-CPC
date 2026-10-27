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
; M4 file commands, mode 1, Greek UI. Expected result:
;   frame  200  CONTROL+S    -> VOSTEST.TXT written, "SAVED" dialog
;   frame  500  RETURN       -> closed
;   frame  600  CONTROL+O    -> file list: VOS.BIN, GREEK.LNG, VOSTEST.TXT
;   frame  800  DOWN, 860 DOWN -> VOSTEST.TXT selected
;   frame  950  RETURN       -> loaded: name, size, type, load, text
;   frame 1250  RETURN       -> closed
;   frame 1300  CONTROL+D    -> file list for deleting
;   frame 1450  DOWN, 1510 DOWN, 1570 RETURN -> "DELETE VOSTEST.TXT?"
;   frame 1650  RETURN       -> YES: deleted, "DELETED" dialog
;   frame 1850  RETURN       -> closed
;   frame 1900  CONTROL+I    -> disc info: DATA, 2 files, free space
;   frame 2050  RETURN       -> closed
;   frame 2100  ESC, 2150 RIGHT, 2200 DOWN, 2250 RETURN -> mode 0
;   frame 2350  CONTROL+O    -> file list in mode 0
;   frame 2450  ESC          -> closed
;   frame 2500  CONTROL+S    -> VOSTEST.TXT written again
;   frame 2700  RETURN       -> closed
;   frame 2750  CONTROL+Q, 2850 RETURN -> restart into BASIC, where the
;               harness can check the file with AMSDOS (CAT, LOAD)
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
        dw  200,  212 : db 2, %10000000   ; CONTROL held ...
        dw  203,  207 : db 7, %00010000   ; ... S
        dw  500,  504 : db 2, %00000100   ; RETURN
        dw  600,  612 : db 2, %10000000   ; CONTROL held ...
        dw  603,  607 : db 4, %00000100   ; ... O
        dw  800,  804 : db 0, %00000100   ; DOWN
        dw  860,  864 : db 0, %00000100   ; DOWN
        dw  950,  954 : db 2, %00000100   ; RETURN
        dw 1250, 1254 : db 2, %00000100   ; RETURN
        dw 1300, 1312 : db 2, %10000000   ; CONTROL held ...
        dw 1303, 1307 : db 7, %00100000   ; ... D
        dw 1450, 1454 : db 0, %00000100   ; DOWN
        dw 1510, 1514 : db 0, %00000100   ; DOWN
        dw 1570, 1574 : db 2, %00000100   ; RETURN
        dw 1650, 1654 : db 2, %00000100   ; RETURN
        dw 1850, 1854 : db 2, %00000100   ; RETURN
        dw 1900, 1912 : db 2, %10000000   ; CONTROL held ...
        dw 1903, 1907 : db 4, %00001000   ; ... I
        dw 2050, 2054 : db 2, %00000100   ; RETURN
        dw 2100, 2104 : db 8, %00000100   ; ESC
        dw 2150, 2154 : db 0, %00000010   ; RIGHT
        dw 2200, 2204 : db 0, %00000100   ; DOWN
        dw 2250, 2254 : db 2, %00000100   ; RETURN
        dw 2350, 2362 : db 2, %10000000   ; CONTROL held ...
        dw 2353, 2357 : db 4, %00000100   ; ... O
        dw 2450, 2454 : db 8, %00000100   ; ESC
        dw 2500, 2512 : db 2, %10000000   ; CONTROL held ...
        dw 2503, 2507 : db 7, %00010000   ; ... S
        dw 2700, 2704 : db 2, %00000100   ; RETURN
        dw 2750, 2762 : db 2, %10000000   ; CONTROL held ...
        dw 2753, 2757 : db 8, %00001000   ; ... Q
        dw 2850, 2854 : db 2, %00000100   ; RETURN
        dw #FFFF

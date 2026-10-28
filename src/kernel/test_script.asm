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
; M5c, Greek UI. Drive A: VOS.BIN, the four view overlays, GREEK.LNG;
; drive B: HELLO.TXT and BIG.BIN (make: build/vos_b.dsk). Expected:
;   frame  300  RIGHT        -> Desktop, A: DESKTOP.OVL selected
;   frame  400  F3           -> Commander, A: active, DESKTOP.OVL still
;                               selected
;   frame  600  TAB          -> B: panel, HELLO.TXT
;   frame  650  CONTROL+C    -> copied to A: ("please wait", then done)
;   frame  850  RETURN       -> closed
;   frame  900  CONTROL+C    -> "REPLACE HELLO.TXT?"
;   frame 1000  RETURN       -> YES: copied again; 1200 RETURN closes
;   frame 1250  ESC, DOWN x5, 1450 RETURN -> FILE / FORMAT DISC
;   frame 1550  RETURN       -> YES: B: formatted, empty, 178K free
;   frame 2500  F4           -> Setup (loading it takes a while)
;   frame 2900  DOWN x6, 3100 RIGHT -> desk colour black
;   frame 3150  UP x6, 3350 RIGHT   -> start view: Launcher
;   frame 3400  CONTROL+S    -> SETUP.CFG saved on A:
;   frame 3600  CONTROL+Q, 3700 RETURN -> restart into BASIC, where the
;               harness checks the discs with AMSDOS and may RUN"VOS
;               again: then V-OS starts in the Launcher, black desk
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
        dw  300,  304 : db 0, %00000010   ; RIGHT
        dw  400,  404 : db 0, %00100000   ; F3
        dw  600,  604 : db 8, %00010000   ; TAB
        dw  650,  662 : db 2, %10000000   ; CONTROL held ...
        dw  653,  657 : db 7, %01000000   ; ... C
        dw  850,  854 : db 2, %00000100   ; RETURN
        dw  900,  912 : db 2, %10000000   ; CONTROL held ...
        dw  903,  907 : db 7, %01000000   ; ... C
        dw 1000, 1004 : db 2, %00000100   ; RETURN
        dw 1200, 1204 : db 2, %00000100   ; RETURN
        dw 1250, 1254 : db 8, %00000100   ; ESC
        dw 1300, 1304 : db 0, %00000100   ; DOWN
        dw 1330, 1334 : db 0, %00000100   ; DOWN
        dw 1360, 1364 : db 0, %00000100   ; DOWN
        dw 1390, 1394 : db 0, %00000100   ; DOWN
        dw 1420, 1424 : db 0, %00000100   ; DOWN
        dw 1450, 1454 : db 2, %00000100   ; RETURN
        dw 1550, 1554 : db 2, %00000100   ; RETURN
        dw 2500, 2504 : db 2, %00010000   ; F4
        dw 2900, 2904 : db 0, %00000100   ; DOWN
        dw 2930, 2934 : db 0, %00000100   ; DOWN
        dw 2960, 2964 : db 0, %00000100   ; DOWN
        dw 2990, 2994 : db 0, %00000100   ; DOWN
        dw 3020, 3024 : db 0, %00000100   ; DOWN
        dw 3050, 3054 : db 0, %00000100   ; DOWN
        dw 3100, 3104 : db 0, %00000010   ; RIGHT
        dw 3150, 3154 : db 0, %00000001   ; UP
        dw 3180, 3184 : db 0, %00000001   ; UP
        dw 3210, 3214 : db 0, %00000001   ; UP
        dw 3240, 3244 : db 0, %00000001   ; UP
        dw 3270, 3274 : db 0, %00000001   ; UP
        dw 3300, 3304 : db 0, %00000001   ; UP
        dw 3350, 3354 : db 0, %00000010   ; RIGHT
        dw 3400, 3412 : db 2, %10000000   ; CONTROL held ...
        dw 3403, 3407 : db 7, %00010000   ; ... S
        dw 3600, 3612 : db 2, %10000000   ; CONTROL held ...
        dw 3603, 3607 : db 8, %00001000   ; ... Q
        dw 3700, 3704 : db 2, %00000100   ; RETURN
        dw #FFFF

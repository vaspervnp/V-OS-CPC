; =====================================================================
; kbd.asm - keyboard matrix scan, key events, auto-repeat
;
; The matrix (10 lines x 8 bits) is read through the PPI and the AY's
; register 14 once per frame, from the interrupt (input_poll). Key
; numbers are line * 8 + bit, the same numbering as the firmware.
; Changes become events in the queue (kernel/events.asm):
;   EV_KEY_DOWN / EV_KEY_UP / EV_KEY_REPEAT, code = key number,
;   char = ASCII from the current map and modifiers (0 if none).
; =====================================================================

KEY_UP          equ 0
KEY_RIGHT       equ 1
KEY_DOWN        equ 2
KEY_F9          equ 3
KEY_F6          equ 4
KEY_F3          equ 5
KEY_ENTER       equ 6               ; small ENTER on the keypad
KEY_FDOT        equ 7
KEY_LEFT        equ 8
KEY_COPY        equ 9
KEY_F7          equ 10
KEY_F8          equ 11
KEY_F5          equ 12
KEY_F1          equ 13
KEY_F2          equ 14
KEY_F0          equ 15
KEY_CLR         equ 16
KEY_RETURN      equ 18
KEY_F4          equ 20
KEY_SHIFT       equ 21
KEY_CONTROL     equ 23
KEY_SPACE       equ 47
KEY_ESC         equ 66
KEY_TAB         equ 68
KEY_CAPS        equ 70
KEY_JOY0        equ 72              ; 72..78: joystick 0 / AMX mouse
KEY_DEL         equ 79
KEY_NONE        equ #FF

MOD_SHIFT       equ %00000001
MOD_CONTROL     equ %00000010
MOD_COPY        equ %00000100
MOD_CAPS        equ %00001000

; ---------------------------------------------------------------------
; kbd_scan - read the matrix, update modifiers, post events.
; Interrupt context. Destroys: AF, BC, DE, HL, IX
; ---------------------------------------------------------------------
kbd_scan:
        ld bc,PPI_A + 14            ; AY register 14 = keyboard port
        out (c),c
        ld bc,PPI_C + #C0           ; AY: select register
        out (c),c
        ld bc,PPI_C                 ; AY: inactive
        out (c),c
        ld bc,PPI_CONTROL + #92     ; PPI port A to input
        out (c),c
        ld hl,kbd_now
        ld e,#40                    ; AY: read, line 0
.line:
        ld b,PPI_C >> 8
        out (c),e
        ld b,PPI_A >> 8
        in a,(c)
        cpl                         ; 1 = pressed
        ld (hl),a
        inc hl
        inc e
        ld a,e
        cp #40 + 10
        jr c,.line
        ld bc,PPI_CONTROL + #82     ; PPI port A back to output
        out (c),c
        ld bc,PPI_C
        out (c),c
        IFDEF TEST_SCRIPT
        call test_inject
        ENDIF

        ; modifiers from the fresh matrix
        ld a,(kbd_caps)
        ld b,a
        ld a,(kbd_now + 2)
        bit 5,a                     ; SHIFT
        jr z,.no_shift
        set 0,b
.no_shift:
        bit 7,a                     ; CONTROL
        jr z,.no_control
        set 1,b
.no_control:
        ld a,(kbd_now + 1)
        bit 1,a                     ; COPY
        jr z,.no_copy
        set 2,b
.no_copy:
        ld a,b
        ld (kbd_mods),a

        call kbd_edges

        ; auto-repeat of the last key pressed
        ld a,(kbd_repeat_key)
        cp KEY_NONE
        ret z
        ld hl,kbd_repeat_timer
        dec (hl)
        ret nz
        ld b,a
        ld a,(kbd_repeat_rate)
        ld (hl),a
        ld a,b
        call kbd_char
        ld c,a
        ld a,EV_KEY_REPEAT
        jp ev_post

; ---------------------------------------------------------------------
; kbd_read_line - A = matrix line 0..9 -> A = its bits (1 = pressed)
; Interrupt context. Destroys: BC
; ---------------------------------------------------------------------
kbd_read_line:
        push af
        ld bc,PPI_A + 14
        out (c),c
        ld bc,PPI_C + #C0
        out (c),c
        ld bc,PPI_C
        out (c),c
        ld bc,PPI_CONTROL + #92
        out (c),c
        pop af
        or #40
        ld b,PPI_C >> 8
        out (c),a
        ld b,PPI_A >> 8
        in a,(c)
        push af
        ld bc,PPI_CONTROL + #82
        out (c),c
        ld bc,PPI_C
        out (c),c
        pop af
        cpl
        ret

; ---------------------------------------------------------------------
; kbd_edges - compare kbd_now with kbd_prev, call press/release
; ---------------------------------------------------------------------
kbd_edges:
        ld hl,kbd_now
        ld ix,kbd_prev
        ld c,0                      ; key number of bit 0 of this line
.line:
        ld a,(hl)
        ld d,a
        xor (ix+0)
        ld (ix+0),d
        ld b,a                      ; changed bits
        ld e,8
        or a
        jr nz,.bit
        ld a,c
        add a,8
        ld c,a
        jr .next_line
.bit:
        bit 0,b
        jr z,.skip
        ld a,c                      ; joystick 0 keys belong to the AMX
        cp KEY_JOY0                 ; mouse while it is enabled
        jr c,.report
        cp KEY_DEL
        jr nc,.report
        ld a,(amx_enabled)
        or a
        jr nz,.skip
.report:
        push bc
        push de
        push hl
        push ix
        ld a,c
        bit 0,d
        jr z,.up
        call kbd_press
        jr .posted
.up:
        call kbd_release
.posted:
        pop ix
        pop hl
        pop de
        pop bc
.skip:
        srl b
        srl d
        inc c
        dec e
        jr nz,.bit
.next_line:
        inc hl
        inc ix
        ld a,c
        cp 80
        jr c,.line
        ret

; A = key
kbd_press:
        ld b,a
        cp KEY_CAPS
        jr nz,.not_caps
        ld a,(kbd_caps)
        xor MOD_CAPS
        ld (kbd_caps),a
        ld a,(kbd_mods)
        xor MOD_CAPS
        ld (kbd_mods),a
        jr .no_repeat
.not_caps:
        cp KEY_SHIFT                ; modifiers do not repeat
        jr z,.no_repeat
        cp KEY_CONTROL
        jr z,.no_repeat
        cp KEY_COPY
        jr z,.no_repeat
        ld (kbd_repeat_key),a
        ld a,(kbd_repeat_delay)
        ld (kbd_repeat_timer),a
.no_repeat:
        ld a,b
        call kbd_char
        ld c,a
        ld a,EV_KEY_DOWN
        jp ev_post

; A = key
kbd_release:
        ld b,a
        ld a,(kbd_repeat_key)
        cp b
        jr nz,.post
        ld a,KEY_NONE
        ld (kbd_repeat_key),a
.post:
        ld c,0
        ld a,EV_KEY_UP
        jp ev_post

; ---------------------------------------------------------------------
; kbd_char - B = key -> A = character for the current modifiers
; (0 = no character). Preserves B.
; Destroys: C, HL
; ---------------------------------------------------------------------
kbd_char:
        ld a,(kbd_mods)
        ld c,a
        ld hl,kbd_map
        bit 0,c
        jr z,.map
        ld hl,kbd_map_shift
.map:
        ld a,b
        call tbl_a
        or a
        ret z
        bit 3,c                     ; CAPS LOCK swaps the case of letters
        jr z,.control
        cp 'a'
        jr c,.upper
        cp 'z' + 1
        jr nc,.control
        sub 32
        jr .control
.upper:
        cp 'A'
        jr c,.control
        cp 'Z' + 1
        jr nc,.control
        add a,32
.control:
        bit 1,c                     ; CONTROL + letter = 1..26
        ret z
        ld c,a
        and %11011111
        cp 'A'
        jr c,.no_letter
        cp 'Z' + 1
        jr nc,.no_letter
        and 31
        ret
.no_letter:
        ld a,c
        ret

; ---- key maps (key number -> ASCII), English CPC 6128 ----------------
; f0-f9, cursor, COPY, SHIFT, CONTROL, CAPS and joystick give no char.
kbd_map:
        db 0, 0, 0, 0, 0, 0, 13, 0                  ; 0  up right down f9 f6 f3 enter f.
        db 0, 0, 0, 0, 0, 0, 0, 0                   ; 8  left copy f7 f8 f5 f1 f2 f0
        db 127, "[", 13, "]", 0, 0, 92, 0           ; 16 clr [ return ] f4 shift \ control
        db "^-@p;:/."                               ; 24
        db "09olkm,", 0                             ; 32 (patched below)
        db "87uyhjn "                               ; 40
        db "65rtgfbv"                               ; 48
        db "43ewsdcx"                               ; 56
        db "12", 27, "q", 9, "a", 0, "z"            ; 64 1 2 esc q tab a caps z
        db 0, 0, 0, 0, 0, 0, 0, 8                   ; 72 joystick 0, del
kbd_map_shift:
        db 0, 0, 0, 0, 0, 0, 13, 0
        db 0, 0, 0, 0, 0, 0, 0, 0
        db 127, "{", 13, "}", 0, 0, 96, 0
        db 0, "=|P+*?>"
        db "_)OILKM<"
        db "(", 39, "UYHJN "
        db "&%RTGFBV"
        db "$#EWSDCX"
        db "!", 34, 27, "Q", 9, "A", 0, "Z"
        db 0, 0, 0, 0, 0, 0, 0, 8

; ---- state ----------------------------------------------------------
kbd_now:            ds 10           ; 1 = pressed
kbd_prev:           ds 10
kbd_mods:           db 0            ; MOD_* bits
kbd_caps:           db 0            ; MOD_CAPS or 0
kbd_repeat_key:     db KEY_NONE
kbd_repeat_timer:   db 0
kbd_repeat_delay:   db 25           ; frames before the first repeat
kbd_repeat_rate:    db 3            ; frames between repeats

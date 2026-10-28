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
        ld b,a                      ; B = key
        ld a,(kbd_repeat_rate)
        ld (hl),a
        ld a,(ev_tail)              ; not while events wait: a slow view
        ld hl,ev_head               ; would fill the queue with repeats
        cp (hl)                     ; and lose the keys after them
        ret nz
        call kbd_char
        cp 8                        ; a held dead key repeats without text
        jr nc,.repeat_char
        xor a
.repeat_char:
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

; A = key. CONTROL+SHIFT (either order) toggles the pack keyboard.
; A dead key gives no character; the next character is combined with it.
kbd_press:
        ld b,a
        cp KEY_SHIFT
        jr nz,.not_shift
        ld a,(kbd_mods)
        and MOD_CONTROL
        jr z,.no_repeat
        jr .toggle
.not_shift:
        cp KEY_CONTROL
        jr nz,.not_control
        ld a,(kbd_mods)
        and MOD_SHIFT
        jr z,.no_repeat
.toggle:
        push bc
        call lang_toggle_input
        pop bc
        jr .no_repeat
.not_control:
        cp KEY_COPY                 ; modifiers do not repeat
        jr z,.no_repeat
        cp KEY_CAPS
        jr nz,.repeatable
        ld a,(kbd_caps)
        xor MOD_CAPS
        ld (kbd_caps),a
        ld a,(kbd_mods)
        xor MOD_CAPS
        ld (kbd_mods),a
        jr .no_repeat
.repeatable:
        ld (kbd_repeat_key),a
        ld a,(kbd_repeat_delay)
        ld (kbd_repeat_timer),a
.no_repeat:
        call kbd_char               ; B = key
        or a
        jr z,.no_char
        cp 8
        jr nc,.char
        ld c,a                      ; CONTROL+A..G: codes, not dead keys
        ld a,(kbd_mods)
        and MOD_CONTROL
        ld a,c
        jr nz,.post
        ld (kbd_dead),a             ; dead key: wait for the next character
        jr .no_char
.char:
        ld c,a
        ld a,(kbd_dead)
        or a
        jr z,.post
        push bc
        call lang_combine
        ld a,c
        pop bc
        ld c,a
        xor a
        ld (kbd_dead),a
        jr .post
.no_char:
        ld c,0
.post:
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
; kbd_char - B = key -> A = character for the current modifiers and
; keyboard language (0 = none, 1..7 = dead key). With CONTROL the
; English map is used, so shortcuts work whatever the keyboard language.
; Preserves B.
; Destroys: C, HL
; ---------------------------------------------------------------------
kbd_char:
        ld a,(kbd_mods)
        ld c,a
        ld a,(lang_input)
        or a
        jr z,.english
        bit 1,c                     ; CONTROL
        jr z,.pack
.english:
        ld hl,kbd_map
        bit 0,c
        jr z,.map
        ld hl,kbd_map_shift
        jr .map
.pack:
        ld hl,lang_keymap
        bit 0,c
        jr z,.map
        ld hl,lang_keymap + 80
.map:
        ld a,b
        call tbl_a
        or a
        ret z
        cp 8                        ; dead keys (1..7) pass through
        ret c
        bit 3,c                     ; CAPS LOCK swaps the case of letters
        jr z,.control
        cp 128
        jr c,.ascii_caps
        call lang_other_case
        jr .control
.ascii_caps:
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
        cp 128
        ret nc
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

; The English key maps (kbd_map, kbd_map_shift) are generated from
; lang/en/keymap.txt into src/lang/lang_en.asm.

; ---- state ----------------------------------------------------------
kbd_now:            ds 10           ; 1 = pressed
kbd_prev:           ds 10
kbd_mods:           db 0            ; MOD_* bits
kbd_caps:           db 0            ; MOD_CAPS or 0
kbd_dead:           db 0            ; pending dead key, 0 = none
kbd_repeat_key:     db KEY_NONE
kbd_repeat_timer:   db 0
kbd_repeat_delay:   db 25           ; frames before the first repeat
kbd_repeat_rate:    db 3            ; frames between repeats

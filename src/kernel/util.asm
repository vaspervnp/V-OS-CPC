; =====================================================================
; util.asm - text formatting helpers
;
; All write at DE and return DE just past what they wrote (no zero).
; =====================================================================

; HL = 0..65535 -> decimal, no leading zeros.  Destroys: AF, BC, HL, IX
util_dec:
        push de
        pop ix
        ld c,0                      ; digits written so far
        ld de,10000
        call .digit
        ld de,1000
        call .digit
        ld de,100
        call .digit
        ld de,10
        call .digit
        ld a,l
        add a,'0'
        ld (ix+0),a
        inc ix
        push ix
        pop de
        ret
.digit:
        ld b,'0'
.sub:
        or a
        sbc hl,de
        jr c,.done
        inc b
        jr .sub
.done:
        add hl,de
        ld a,b
        cp '0'
        jr nz,.emit
        ld a,c
        or a
        ret z
        ld a,'0'
.emit:
        ld (ix+0),a
        inc ix
        inc c
        ret

; HL -> four hex digits.  Destroys: AF
util_hex4:
        ld a,h
        call util_hex2
        ld a,l
        ; fall through
; A -> two hex digits.  Destroys: AF
util_hex2:
        push af
        rrca
        rrca
        rrca
        rrca
        call .nibble
        pop af
.nibble:
        and 15
        add a,'0'
        cp '9' + 1
        jr c,.store
        add a,'A' - '9' - 1
.store:
        ld (de),a
        inc de
        ret

; HL -> zero-terminated text: copy it without the zero.  Destroys: AF, HL
util_copy:
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr util_copy

; A = MSG_*: copy its text.  Destroys: AF, BC, HL
util_msg:
        push de
        call lang_msg
        pop de
        jr util_copy

; HL -> 11-byte name -> "NAME.EXT" without the padding.  Destroys: AF, B, HL
util_fcb_text:
        ld b,8
.name:
        ld a,(hl)
        inc hl
        cp " "
        jr z,.name_pad
        ld (de),a
        inc de
.name_pad:
        djnz .name
        ld a,(hl)                   ; no extension: no dot
        cp " "
        ret z
        ld a,"."
        ld (de),a
        inc de
        ld b,3
.ext:
        ld a,(hl)
        inc hl
        cp " "
        jr z,.ext_pad
        ld (de),a
        inc de
.ext_pad:
        djnz .ext
        ret

; A = character -> DE, "|" -> new dialog line
util_char:
        ld (de),a
        inc de
        ret

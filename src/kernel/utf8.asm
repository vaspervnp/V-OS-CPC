; =====================================================================
; utf8.asm - UTF-8 text into the V-OS character set
;
; In the second extension (kernel/ext2.asm: VX_UTF8, u8_entry); its
; table, utf8.inc, is made by tools/voscs.py. A file from a PC or the
; web may be in UTF-8; one in ISO 8859-7 (Greek) or ASCII is V-OS
; already.
;   u8_start  before a text: nothing seen yet
;   u8_check  HL -> bytes, BC = how many: look at them, the next piece
;             of the text (call it for each piece, in order)
;             -> u8_is: A = 1 if all of it was UTF-8, with at least one
;             character over 127; 0 if not (then leave it as it is)
;   u8_cut    HL -> a piece, BC = its bytes (4 or more) -> BC without a
;             character cut at its end (it starts the next piece)
;   u8_conv   HL -> UTF-8, BC = bytes (whole characters): in place in
;             the V-OS set -> BC = bytes now. A character the set has
;             not becomes "?"; the byte order mark goes.
; Destroy: AF, BC, DE, HL (u8_is: A only)
; =====================================================================

u8_start:
        xor a
        ld (u8_need),a
        ld (u8_bad),a
        ld (u8_seen),a
        ret

u8_check:
        ld a,(u8_bad)
        or a
        ret nz
.byte:
        ld a,b
        or c
        ret z
        ld a,(hl)
        inc hl
        dec bc
        ld d,a
        ld a,(u8_need)
        or a
        jr z,.lead
        ld e,a
        ld a,d                      ; a continuation byte: 10xxxxxx
        and #C0
        cp #80
        jr nz,.bad
        dec e
        ld a,e
        ld (u8_need),a
        jr .byte
.lead:
        ld a,d
        cp #80
        jr c,.byte
        cp #C2
        jr c,.bad
        ld e,1
        cp #E0
        jr c,.multi
        inc e
        cp #F0
        jr c,.multi
        inc e
        cp #F5
        jr nc,.bad
.multi:
        ld a,e
        ld (u8_need),a
        ld a,1
        ld (u8_seen),a
        jr .byte
.bad:
        ld a,1
        ld (u8_bad),a
        ret

u8_is:
        ld a,(u8_bad)
        or a
        ld a,0
        ret nz
        ld a,(u8_need)              ; cut short at its end
        or a
        ld a,0
        ret nz
        ld a,(u8_seen)
        ret

u8_cut:
        push hl
        add hl,bc
        ld e,0                      ; bytes back from the end
.back:
        ld a,e
        cp 3
        jr z,.whole
        dec hl
        inc e
        ld a,(hl)
        and #C0
        cp #80
        jr z,.back                  ; a continuation: further back
        ld a,(hl)
        cp #C0
        jr c,.whole                 ; ASCII
        ld d,2                      ; a lead byte: its length
        cp #E0
        jr c,.length
        inc d
        cp #F0
        jr c,.length
        inc d
.length:
        ld a,e
        cp d
        jr nc,.whole                ; all of it is there
        ld a,c
        sub e
        ld c,a
        jr nc,.whole
        dec b
.whole:
        pop hl
        ret

u8_conv:
        push hl
        ld d,h
        ld e,l
.next:
        ld a,b
        or c
        jr z,.end
        ld a,(hl)
        inc hl
        dec bc
        cp #80
        jr c,.put
        cp #E0
        jr nc,.three
        ld (u8_cp),a                ; 110aaabb 10cccccc
        rrca
        rrca
        and #07
        ld (u8_cp + 1),a
        ld a,(u8_cp)
        rrca
        rrca
        and #C0
        ld (u8_cp),a
        jr .last
.three:
        cp #F0
        jr nc,.four
        rlca                        ; 1110aaaa 10bbbbcc 10dddddd
        rlca
        rlca
        rlca
        and #F0
        ld (u8_cp + 1),a
        ld a,(hl)
        inc hl
        dec bc
        and #3F
        ld (u8_cp),a
        rrca
        rrca
        and #0F
        push hl
        ld hl,u8_cp + 1
        or (hl)
        ld (hl),a
        ld a,(u8_cp)
        rrca
        rrca
        and #C0
        ld (u8_cp),a
        pop hl
.last:
        ld a,(hl)
        inc hl
        dec bc
        and #3F
        push hl
        ld hl,u8_cp
        or (hl)
        ld (hl),a
        pop hl
        call u8_code
        jr nc,.next                 ; the byte order mark: nothing
        jr .put
.four:                              ; over #FFFF: none in the set
        inc hl
        inc hl
        inc hl
        dec bc
        dec bc
        dec bc
        ld a,"?"
.put:
        ld (de),a
        inc de
        jr .next
.end:
        ex de,hl
        pop de
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ret

; u8_cp -> carry and A = its V-OS code ("?" if none); no carry for the
; byte order mark. Keeps BC, DE, HL.
u8_code:
        push hl
        push de
        push bc
        ld de,(u8_cp)
        ld a,d
        cp #FE
        jr nz,.find
        ld a,e
        cp #FF
        jr z,.none
.find:
        ld hl,u8_tab
        ld bc,128 * 256 + 128       ; 128 codes, from 128
.code:
        ld a,(hl)
        inc hl
        cp e
        jr nz,.not
        ld a,(hl)
        cp d
        jr z,.found
.not:
        inc hl
        inc c
        djnz .code
.more:                              ; then the other signs
        ld a,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld c,a
        or b
        ld a,"?"
        jr z,.found_a
        ld a,(hl)
        inc hl
        push af
        ld a,c
        cp e
        jr nz,.again
        ld a,b
        cp d
        jr nz,.again
        pop af
        jr .found_a
.again:
        pop af
        jr .more
.found:
        ld a,c
.found_a:
        pop bc
        pop de
        pop hl
        scf
        ret
.none:
        pop bc
        pop de
        pop hl
        or a
        ret

u8_need:        db 0
u8_bad:         db 0
u8_seen:        db 0
u8_cp:          dw 0
        include "utf8.inc"

; =====================================================================
; split_set.asm - VOS_SPLIT's setting, in the second extension (kernel/
; ext2.asm): the kernel's api_split copies the program's 12 bytes into
; vw_buf first (gfx/split.asm has the rest, in the kernel)
; =====================================================================

; ---------------------------------------------------------------------
; split_set (VOS_SPLIT) - vw_buf = dw y1, y2; db 4 colours for pens 0..3 in
; the mode 1 bands, 4 for pens 0..3 in the mode 0 band (firmware
; colours). 0 < y1 < y2 <= GFX_H (HL = 0, one mode again, is the
; kernel's api_split). Kernel menus need y1 = UI_BAR_H.
; Carry: bad lines. Destroys: all
; ---------------------------------------------------------------------
split_set:
        ld hl,vw_buf
        ld e,(hl)                   ; DE = y1
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)                   ; BC = y2
        inc hl
        ld b,(hl)
        inc hl
        push hl
        push bc
        ld a,d                      ; y1 > 0
        or e
        jr z,.bad
        pop hl                      ; HL = y2
        push hl
        or a                        ; y1 < y2
        sbc hl,de
        jr c,.bad
        jr z,.bad
        pop hl
        push hl
        ld bc,GFX_H + 1             ; y2 <= GFX_H
        or a
        sbc hl,bc
        jr nc,.bad
        ld a,(split_on)
        or a
        call z,ptr_to_mode1
        xor a
        ld (split_on),a             ; the interrupt leaves it alone now
        ld (split_y1),de
        ex de,hl
        call split_slice
        ld (split_s1),bc
        pop hl
        ld (split_y2),hl
        call split_slice
        ld (split_s2),bc
        pop hl                      ; the colours, as Gate Array codes
        ld de,split_band
        ld b,8
.colour:
        ld a,(hl)
        inc hl
        push hl
        ld hl,ga_colours
        call tbl_a
        ld (de),a
        inc de
        pop hl
        djnz .colour
        ld hl,split_s1              ; input on the first slice without a
        ld a,1                      ; wait: never right after a long one
.input:
        cp (hl)
        jr z,.taken
        inc hl
        inc hl
        cp (hl)
        dec hl
        dec hl
        jr nz,.free
.taken:
        inc a
        jr .input
.free:
        ld (int_input),a
        ld a,1
        ld (split_on),a
        or a
        ret
.bad:
        pop bc
        pop hl
        scf
        ret

; HL = line -> C = interrupt, B = lines to wait after it
split_slice:
        ld de,SPLIT_LINE0 - GFX_TOP
        or a
        sbc hl,de                   ; lines after interrupt 1
        ld c,1
        ld de,SPLIT_LINES
        jr nc,.slice
        ld de,SPLIT_LINES0          ; above it: after interrupt 0
        add hl,de
        ld b,l
        dec c
        ret
.slice:
        or a
        sbc hl,de
        jr c,.found
        inc c
        jr .slice
.found:
        add hl,de
        ld b,l
        ret

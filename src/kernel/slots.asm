; =====================================================================
; slots.asm - the relocation of programs (src/api/vos_api.inc), for
; their slots (kernel/ext.asm) and the accessory (Launcher). In page
; zero, between the restart vectors and the API table (vectors.asm).
; =====================================================================

; the file in bank 4 (view_fetch): its relocation table, if it has one
; -> HL = the table in bank 4, BC = its entries; carry: none
reloc_find:
        ld hl,(fs_length)           ; its end: dw entries, "RL"
        ld de,BUF_ADDR - 4
        add hl,de
        push hl
        ld de,bank_buf
        ld bc,4
        ld a,BUF_CFG
        call bank_get
        pop de
        ld hl,(bank_buf + 2)
        ld bc,"L" * 256 + "R"
        or a
        sbc hl,bc
        scf
        ret nz
        ex de,hl
        ld bc,(bank_buf)            ; 2 bytes an entry
        or a
        sbc hl,bc
        sbc hl,bc
        ret

; HL = the table, BC = its entries, A = pages: move the program in
; bank 4 by A * 256 bytes
reloc:
        ld (rl_pages),a
        push bc
        ld a,BUF_CFG
        call ram_select             ; (destroys B)
        pop bc
.entry:
        ld a,b
        or c
        jp z,ram_home
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,BUF_ADDR
        add hl,de
        ld a,(rl_pages)
        add a,(hl)
        ld (hl),a
        pop hl
        dec bc
        jr .entry

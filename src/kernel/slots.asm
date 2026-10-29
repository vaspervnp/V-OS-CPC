; =====================================================================
; slots.asm - programs side by side in bank 5 (include/memmap.inc):
; their relocation (src/api/vos_api.inc) and their slots. In page
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

; -> Z: no slot in use; D = a free one (0: none)
slot_scan:
        ld hl,SLOT_FIRST * 256 + SLOT_PAGE
        ld de,0                     ; E: slots in use
.slot:
        ld a,(hl)
        or a
        jr nz,.used
        ld d,h
        db #FE                      ; (cp n: skips inc e)
.used:
        inc e
        ld a,h
        add a,SLOT_STEP
        ld h,a
        cp SLOT_END
        jr nz,.slot
        ld a,e
        or a
        ret

; B = pages: the first room for them above PROG_ADDR and a free slot
; -> A = the first page, app_slot = the slot (first page and pages
; set). Carry: no room.
slot_alloc:
        push bc
        call slot_scan
        pop bc
        ld a,d
        or a
        scf
        ret z
        push de
        ld c,PROG_ADDR >> 8
.try:
        ld a,c                      ; C .. C + B: past the bank?
        add a,b
        cp #81
        jr nc,.none
        ld h,SLOT_FIRST
.slot:
        ld l,SLOT_PAGE
        ld a,(hl)
        or a
        jr z,.next
        ld e,a                      ; E .. D: a program
        inc l
        add a,(hl)
        ld d,a
        ld a,c
        cp d
        jr nc,.next                 ; C at its end or after it
        add a,b
        dec a
        cp e
        jr c,.next                  ; the last page before it
        ld c,d                      ; else try after it
        jr .try
.next:
        ld a,h
        add a,SLOT_STEP
        ld h,a
        cp SLOT_END
        jr nz,.slot
        pop hl                      ; H = the free slot
        ld l,SLOT_PAGE
        ld (hl),c
        inc l
        ld (hl),b
        ld a,h
        ld (app_slot),a
        ld a,c
        ret                         ; (no carry: cp SLOT_END, equal)
.none:
        pop de
        scf
        ret

; =====================================================================
; expand.asm - xb_detect: which 64K blocks of a RAM expansion answer
; (Gate Array RAM configuration bits 3-5: #C4 + block * 8 .. #C7 + block
; * 8 map its four banks at #4000). Their banks go into bk_list
; (kernel/ext.asm), after bank 5, for programs. The loader calls it
; once the kernel and the kernel extension are in place; it runs from
; VOS.BIN as loaded, above #8000, since it maps banks at #4000.
; Each block's first bank gets its number, from 7 down to 0 (bank 4):
; a block that is not there shows another number (the one written last
; at the same place, as on a 6128 without expansion: always bank 4).
; =====================================================================

xb_detect:
        ld c,7
.write:
        ld a,c
        call .select
        ld a,c
        ld (#4000),a
        dec c
        jp p,.write
        ld hl,xb_found
        ld c,1
.read:
        ld a,c
        call .select
        ld a,(#4000)
        cp c
        jr nz,.next
        ld a,c                      ; there: its four banks
        add a,a
        add a,a
        add a,a
        or #C4
        ld b,4
.bank:
        ld (hl),a
        inc hl
        inc a
        djnz .bank
.next:
        inc c
        ld a,c
        cp 8
        jr nz,.read
        ld (hl),0
        ld a,LANG_BANK_CFG
        call ram_select
        ld hl,xb_found
        ld de,bk_list + 1
        ld bc,XB_MAX + 1
        ldir
        jp ram_home
; A = block -> its first bank at #4000
.select:
        add a,a
        add a,a
        add a,a
        or #C4
        jp ram_select

xb_found:       ds XB_MAX + 1

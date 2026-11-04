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
        ld hl,vw_on                 ; no view, no window, no WM.SYS yet
        ld de,vw_on + 1             ; (in the screen's RAM: whatever was
        ld bc,wm_sys - vw_on        ; there before)
        ld (hl),0
        ldir
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
        IFDEF DEMO
        ld de,xb_found              ; the demo build: the last bank for
        or a                        ; DEMO.KEY (kernel/demo.asm), not for
        sbc hl,de                   ; programs
        add hl,de
        jr z,.no_demo
        dec hl
        ld a,(hl)
        ld (demo_cfg),a
.no_demo:
        ENDIF
        ld de,xb_found              ; the last bank for the desk's
        or a                        ; picture (wall_bank, kernel/ext2.asm:
        sbc hl,de                   ; wall_draw), not for programs
        add hl,de
        jr z,.no_wall
        dec hl
        ld a,(hl)
        ld (xb_wall),a
.no_wall:
        ld (hl),0
        ld de,xb_found              ; the one before it for programs'
        or a                        ; views (wm_bank, gfx/view.asm), with
        sbc hl,de                   ; that code copied into it
        add hl,de
        jr z,.no_wm
        dec hl
        ld a,(hl)
        ld (hl),0
        ld (wm_bank),a
        call ram_select
        ld de,xb_found + 2 * WM_COPIES_N ; the ones before it for the
        or a                        ; windows' copies (wm/wm.asm: wm_snap),
        sbc hl,de                   ; if as many stay for programs
        add hl,de
        ld a,0
        jr c,.copies
        ld de,WM_COPIES + 1
        ld b,WM_COPIES_N
.copy:
        dec hl
        ld a,(hl)
        ld (hl),0
        ld (de),a
        inc de
        djnz .copy
        ld a,WM_COPIES_N
.copies:
        ld (WM_COPIES),a
        ld hl,wm_image
        ld de,WM_ADDR
        ld bc,WM_SIZE
        ldir
.no_wm:
        ld a,LANG_BANK_CFG
        call ram_select
        ld hl,EXT_ADDR + EXT_SIZE   ; the kernel extension's clipboard and
        ld de,EXT_ADDR + EXT_SIZE + 1 ; program slots, after its code:
        ld bc,EXT_MAX - EXT_SIZE - 1 ; empty (not in VOS.BIN)
        ld (hl),0
        ldir
        ld hl,xb_found
        ld de,bk_list + 1
        ld bc,XB_MAX + 2            ; (and xb_wall: wall_bank)
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
xb_wall:        db 0                ; -> wall_bank

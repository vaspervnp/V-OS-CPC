; =====================================================================
; ext2.asm - the second kernel extension: code that fits neither in the
; kernel nor in bank 7. It is in base RAM bank 1 at EXT2_ADDR (RAM
; config EXT2_CFG), where VOS.BIN was loaded: after boot nothing else
; uses that bank. The loader copies it there; the kernel calls it
; through ext2_call (kernel/view.asm), which makes that bank home while
; it runs. Like ext.asm, it must not touch a program's memory, and a
; program's code runs only from the kernel (bh_init).
; =====================================================================

; ---------------------------------------------------------------------
; VX_BEHIND, from the main loop (kernel/kernel.asm): the program for
; app_open's file (by its type) into a slot, unless it runs already,
; and its init with A = 3 as the kernel's program (bh_init); then the
; one in front as it was. Carry: A = the error, for sys_error.
; ---------------------------------------------------------------------
behind_run:
        xor a
        ld (bh_req),a
        ld hl,bh_begin              ; (kernel/files_ext.asm)
        call ext_call
        jr c,bh_end
        jr z,.start                 ; it runs already: its slot
        ld a,(app_drive)
        call fdc_select
        ld hl,file_name
        call view_fetch
        jr c,bh_end
        ld de,"A" * 256 + "V"
        or a
        sbc hl,de
        ld a,FS_ERR_NOT_PROGRAM
        scf
        jr nz,bh_end
        ld hl,app_place
        call ext_call
        ld a,FS_ERR_NO_ROOM
        jr c,bh_end
        call view_base              ; the program into its place
        ld a,BUF_CFG
        ld (ab_from),a
        ld a,(vw_cfg)
        ld (ab_to),a
        ld hl,BUF_ADDR
        ld bc,(fs_length)
        call bank_copy
        ld hl,slot_own
        call ext_call
.start:
        call bh_init
        or a
        ; fall through

; the one in front again (bh_save, from bh_begin), app_open empty; its
; bank is home again when ext2_call returns. A and carry kept.
bh_end:
        push af
        ld hl,bh_save
        ld de,vw_page               ; vw_page, vw_cfg, data_cfg, app_slot
        ld bc,4
        ldir
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (cur_base),de
        ld a,(hl)
        inc hl
        ld (app_drive),a
        ld de,file_name
        ld c,11
        ldir
        ld de,app_self
        ld c,12
        ldir
        xor a
        ld (app_open),a
        pop af
        ret

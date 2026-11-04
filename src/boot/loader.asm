; =====================================================================
; loader.asm - entry point run by AMSDOS after RUN"VOS"
;
; VOS.BIN is loaded at LOADER_ADDR. It holds this stub followed by the
; kernel image, which is assembled for KERNEL_BASE. The stub takes the
; machine away from the firmware and moves the kernel into place; from
; then on V-OS reads the disc with its own driver (drivers/fdc.asm).
; =====================================================================

loader_start:
        di
        ; both ROMs off, mode 1, reset the interrupt counter
        ld bc,GA_PORT + GA_RMR + GA_RMR_LOROM_OFF + GA_RMR_HIROM_OFF + GA_RMR_INT_RESET + 1
        out (c),c
        ; plain 64K RAM layout
        ld bc,GA_PORT + GA_RAMCFG
        out (c),c
        ; copy the kernel to #0000 (destination is below the source,
        ; so a forward LDIR is safe even if the ranges overlap)
        ld hl,kernel_image
        ld de,KERNEL_BASE
        ld bc,KERNEL_SIZE
        ldir
        ; the kernel extension into bank 7 (kernel/ext.asm)
        ld hl,EXT_IMAGE
        ld de,EXT_ADDR
        ld bc,EXT_SIZE
        ld a,LANG_BANK_CFG
        call bank_put
        call xb_detect              ; the banks of a RAM expansion
        ld hl,ext2_image            ; the second extension into base RAM
        ld de,EXT2_ADDR             ; bank 1, over the kernel's image
        ld bc,EXT2_SIZE + LOW_SIZE  ; (kernel/ext2.asm; and gfx/split_set.asm)
        ldir
        call gfx_init               ; the screen, black while the disc loads
        ld hl,palette_black
        call ga_set_palette
        ; video RAM clear: the screen, and the kernel's buffers and the
        ; program slots in its hidden gaps (include/memmap.inc)
        ld hl,#8000
        ld de,#8001
        ld bc,#7FFF
        ld (hl),l
        ldir
        jp kernel_entry

; Run once, here: they take no room in the kernel
; ---------------------------------------------------------------------
; gfx_init - program the overscan CRTC and build the line table
; Destroys: all
; ---------------------------------------------------------------------
gfx_init:
        ld hl,crtc_overscan
        call crtc_load
        ; gfx_lines_all[line] = address of physical pixel line
        ld ix,gfx_lines_all
        ld hl,SCREEN_TOP
        ld c,0                      ; char row
.row:
        push hl
        ld b,8
.line:
        ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        ld a,h
        add a,#08                   ; next pixel line: +#800
        ld h,a
        djnz .line
        pop hl
        inc c
        ld a,c
        cp SCREEN_SPLIT
        jr nz,.same_page
        ld hl,SCREEN_LOW
        jr .next
.same_page:
        ld de,SCREEN_BPL
        add hl,de
.next:
        cp SCREEN_ROWS
        jr c,.row
        ret

palette_black:  ds 17, 0

        include "../drivers/crtc.asm"
loader_end:

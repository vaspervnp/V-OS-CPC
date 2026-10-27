; =====================================================================
; loader.asm - entry point run by AMSDOS after RUN"VOS"
;
; VOS.BIN is loaded at LOADER_ADDR. It holds this stub followed by the
; kernel image, which is assembled for KERNEL_BASE. The stub takes the
; machine away from the firmware and moves the kernel into place.
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
        jp kernel_entry

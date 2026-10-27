; =====================================================================
; vos.asm - V-OS build root
;
; Output: VOS.BIN on build/vos.dsk, loaded by AMSDOS at LOADER_ADDR
; with RUN"VOS". The file is the loader stub followed by the kernel
; image, which is assembled for KERNEL_BASE and copied there at boot.
; =====================================================================

        include "include/hw.inc"
        include "include/memmap.inc"
        include "lang/msg_ids.inc"

VOS_VERSION     equ #0006           ; 0.06
VOS_API_VERSION equ #0000

; ---- loader, runs at LOADER_ADDR ------------------------------------
        org LOADER_ADDR
        run loader_start
        include "boot/loader.asm"

; ---- kernel image: stored after the loader, runs at KERNEL_BASE ------
kernel_image:
        org KERNEL_BASE, kernel_image
kernel_start:
        include "kernel/vectors.asm"
        include "kernel/kernel.asm"
        include "kernel/interrupts.asm"
        include "kernel/events.asm"
        include "kernel/fs.asm"
        include "kernel/util.asm"
        include "kernel/lang.asm"
        include "lang/lang_en.asm"
        IFDEF TEST_SCRIPT
        include "kernel/test_script.asm"
        ENDIF
        include "drivers/ga.asm"
        include "drivers/crtc.asm"
        include "drivers/kbd.asm"
        include "drivers/mouse.asm"
        include "drivers/fdc.asm"
        include "gfx/gfx.asm"
        include "gfx/pointer.asm"
        include "ui/ui.asm"
        include "ui/dialog.asm"
        include "ui/filedlg.asm"
        include "gfx/font_ascii.asm"
kernel_end:

KERNEL_SIZE     equ kernel_end - kernel_start

        assert KERNEL_SIZE <= KERNEL_LIMIT - KERNEL_BASE
        assert LOADER_ADDR + kernel_image - loader_start + KERNEL_SIZE <= #A000

        IFDEF TEST_SCRIPT
        save "VOS.BIN", loader_start, kernel_image - loader_start + KERNEL_SIZE, DSK, "build/vos_test.dsk"
        ELSE
        save "VOS.BIN", loader_start, kernel_image - loader_start + KERNEL_SIZE, DSK, "build/vos.dsk"
        ENDIF

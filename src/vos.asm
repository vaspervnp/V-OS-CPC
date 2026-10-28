; =====================================================================
; vos.asm - V-OS build root
;
; Output on build/vos.dsk: VOS.BIN, loaded by AMSDOS at LOADER_ADDR
; with RUN"VOS" (the loader stub followed by the kernel image, which is
; assembled for KERNEL_BASE and copied there at boot), and one overlay
; file per view, assembled for VIEW_ADDR in memory spaces of their own
; (BANK), which the kernel loads itself (kernel/view.asm).
; =====================================================================

        include "include/hw.inc"
        include "include/memmap.inc"
        include "lang/msg_ids.inc"

VOS_VERSION     equ #0009           ; 0.09
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
        include "kernel/files.asm"
        include "kernel/view.asm"
        include "kernel/setup.asm"
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
        include "ui/input.asm"
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

; ---- views: overlays at VIEW_ADDR -------------------------------------
        BANK
        org VIEW_ADDR
        include "shell/desktop.asm"
desktop_end:
        assert desktop_end <= VIEW_ADDR + #4000
        IFDEF TEST_SCRIPT
        save "DESKTOP.OVL", VIEW_ADDR, desktop_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "DESKTOP.OVL", VIEW_ADDR, desktop_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

        BANK
        org VIEW_ADDR
        include "shell/launcher.asm"
launcher_end:
        assert launcher_end <= VIEW_ADDR + #4000
        IFDEF TEST_SCRIPT
        save "LAUNCHER.OVL", VIEW_ADDR, launcher_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "LAUNCHER.OVL", VIEW_ADDR, launcher_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

        BANK
        org VIEW_ADDR
        include "shell/commander.asm"
commander_end:
        assert commander_end <= VIEW_ADDR + #4000
        IFDEF TEST_SCRIPT
        save "COMMANDR.OVL", VIEW_ADDR, commander_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "COMMANDR.OVL", VIEW_ADDR, commander_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

        BANK
        org VIEW_ADDR
        include "shell/setup.asm"
setup_end:
        assert setup_end <= VIEW_ADDR + #4000
        IFDEF TEST_SCRIPT
        save "SETUP.OVL", VIEW_ADDR, setup_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "SETUP.OVL", VIEW_ADDR, setup_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

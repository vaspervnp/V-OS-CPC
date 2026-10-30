; =====================================================================
; vos.asm - V-OS build root
;
; Output on build/vos.dsk: VOS.BIN, loaded by AMSDOS at LOADER_ADDR
; with RUN"VOS" (the loader stub followed by the kernel image, which is
; assembled for KERNEL_BASE and copied there at boot, and at EXT_IMAGE
; the kernel extension, which the loader puts in bank 7, then the RAM
; expansion test it runs), and one overlay
; file per view, assembled for VIEW_ADDR in memory spaces of their own
; (BANK), which the kernel loads itself (kernel/view.asm).
; =====================================================================

        include "include/hw.inc"
        include "include/memmap.inc"
        include "lang/msg_ids.inc"
        include "api/vos_api.inc"

VOS_VERSION     equ #0010           ; 0.10

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
        include "drivers/psg.asm"
        include "gfx/gfx.asm"
        include "gfx/pointer.asm"
        include "gfx/split.asm"
        include "ui/ui.asm"
        include "ui/dialog.asm"
        include "ui/filedlg.asm"
        include "ui/input.asm"
        include "gfx/font_ascii.asm"
kernel_end:

KERNEL_SIZE     equ kernel_end - kernel_start

; ---- kernel extension: in VOS.BIN at EXT_IMAGE, runs in bank 7 -------
        org EXT_ADDR, EXT_IMAGE
ext_start:
        include "kernel/ext.asm"
        include "kernel/files_ext.asm"
        assert $ <= SLOT_TABLE
        ds SLOT_TABLE - $, 0
        ds 256, 0                   ; the slots, free
ext_end:

; ---- RAM expansion test: in VOS.BIN after the extension, run there --
        org EXT_IMAGE + EXT_MAX
        include "boot/expand.asm"
xb_end:

EXT_SIZE        equ ext_end - ext_start

        IFDEF TEST_SCRIPT                     ; the test script takes some of
        assert KERNEL_SIZE <= KERNEL_LIMIT + #100 - KERNEL_BASE ; the stack
        ELSE
        assert KERNEL_SIZE <= KERNEL_LIMIT - KERNEL_BASE
        ENDIF
        assert MSG_COUNT <= VT_FIRST          ; program texts start there
        assert app_self == VOS_SELF
        assert kernel_image + KERNEL_SIZE <= EXT_IMAGE
        assert EXT_SIZE <= EXT_MAX
        assert ext_end == EXT_ADDR + EXT_MAX
        assert xb_end <= #A000              ; below AMSDOS

        IFDEF TEST_SCRIPT
        save "VOS.BIN", loader_start, xb_end - loader_start, DSK, "build/vos_test.dsk"
        ELSE
        save "VOS.BIN", loader_start, xb_end - loader_start, DSK, "build/vos.dsk"
        ENDIF

; ---- views: overlays at VIEW_ADDR -------------------------------------
        BANK
        org VIEW_ADDR
        include "shell/desktop.asm"
desktop_end:
        assert desktop_end <= PROG_ADDR
        IFDEF TEST_SCRIPT
        save "DESKTOP.OVL", VIEW_ADDR, desktop_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "DESKTOP.OVL", VIEW_ADDR, desktop_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

        BANK
        org VIEW_ADDR
        include "shell/launcher.asm"
launcher_end:
        assert launcher_end <= PROG_ADDR
        IFDEF TEST_SCRIPT
        save "LAUNCHER.OVL", VIEW_ADDR, launcher_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "LAUNCHER.OVL", VIEW_ADDR, launcher_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

        BANK
        org VIEW_ADDR
        include "shell/commander.asm"
commander_end:
        assert commander_end <= PROG_ADDR
        IFDEF TEST_SCRIPT
        save "COMMANDR.OVL", VIEW_ADDR, commander_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "COMMANDR.OVL", VIEW_ADDR, commander_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

        BANK
        org VIEW_ADDR
        include "shell/setup.asm"
setup_end:
        assert setup_end <= PROG_ADDR
        IFDEF TEST_SCRIPT
        save "SETUP.OVL", VIEW_ADDR, setup_end - VIEW_ADDR, DSK, "build/vos_test.dsk"
        ELSE
        save "SETUP.OVL", VIEW_ADDR, setup_end - VIEW_ADDR, DSK, "build/vos.dsk"
        ENDIF

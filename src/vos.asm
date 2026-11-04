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

        include "version.inc"

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
; the test script (kernel/test_script.asm) is in the second extension:
; from the interrupt, with its bank there meanwhile; ram_config says
; which to put back. (A script stack of a block program may be in
; #4000-#7FFF then: the pushes go to that bank's free end.)
test_inject:
        ld hl,test_inject_x
        IFDEF TEST_TRACE
        jr test_x
test_ring:
        ld hl,test_ring_x
        ENDIF
test_x:
        ld a,EXT2_CFG
        ld b,GA_PORT >> 8
        out (c),a
        call .go
        ld a,(ram_config)
        ld b,GA_PORT >> 8
        out (c),a
        ret
.go:
        jp (hl)
        ENDIF
        IFDEF DEMO
        include "kernel/demo.asm"
        ENDIF
        include "drivers/ga.asm"
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
        assert $ <= CLIP_ADDR       ; the clipboard after the code, then
ext_end:                            ; the slots: xb_detect empties them

; ---- RAM expansion test: in VOS.BIN after the extension, run there --
        org EXT_IMAGE + ext_end - ext_start
        include "boot/expand.asm"
xb_end:

; ---- second extension: in VOS.BIN after the RAM test, runs in base RAM
; bank 1 at EXT2_ADDR; the loader copies it there ----------------------
ext2_image:
        org EXT2_ADDR, ext2_image
ext2_start:
        include "kernel/ext2.asm"
        IFDEF TEST_SCRIPT
        include "kernel/test_script.asm"
        ENDIF
ext2_end:
EXT2_SIZE       equ ext2_end - ext2_start

; ---- VOS_SPLIT's setting: at LOW_ADDR in base RAM bank 1, where the
; loader was. In VOS.BIN after the second extension; the loader copies
; it with it, and boot_x (kernel/ext2.asm) moves it down at boot -------
        org LOW_ADDR, ext2_image + EXT2_SIZE
low_start:
        include "gfx/split_set.asm"
low_end:
LOW_SIZE        equ low_end - low_start

; ---- programs' views (VX_VIEW): at WM_ADDR in a bank of a RAM
; expansion (wm_bank), where xb_detect copies it at boot ---------------
wm_image        equ ext2_image + EXT2_SIZE + LOW_SIZE
        org WM_ADDR, wm_image
wm_start:
        include "gfx/view.asm"
wm_end:
WM_SIZE         equ wm_end - wm_start

EXT_SIZE        equ ext_end - ext_start

        IFDEF TEST_SCRIPT                     ; the test script takes some of
        assert KERNEL_SIZE <= KERNEL_LIMIT + #100 - KERNEL_BASE ; the stack
        ELSE
        IFDEF DEMO                            ; and the demo
        assert KERNEL_SIZE <= KERNEL_LIMIT + #100 - KERNEL_BASE
        ELSE
        assert KERNEL_SIZE <= KERNEL_LIMIT - KERNEL_BASE
        ENDIF
        ENDIF
        assert MSG_COUNT <= VT_FIRST          ; program texts start there
        assert app_self == VOS_SELF
        assert app_open == VOS_OPEN
        assert kernel_image + KERNEL_SIZE <= EXT_IMAGE
        assert EXT_SIZE <= EXT_MAX
        assert wm_image + WM_SIZE <= #A000  ; below AMSDOS
        assert WM_ADDR + WM_SIZE <= WM_SYS_ADDR
        assert low_end <= EXT2_ADDR
        assert loader_end <= EXT2_ADDR
        IFDEF TEST_SCRIPT                     ; CALC.SYS on SHEET's test discs
        IF TEST_SCRIPT == 32 || TEST_SCRIPT == 42 ; only: the others have
        assert ext2_end <= CALC_ADDR          ; its room for the script
        ELSE
        assert ext2_end <= DB_ADDR
        ENDIF
        ELSE
        assert ext2_end <= CALC_ADDR
        ENDIF

        IFDEF TEST_SCRIPT
        save "VOS.BIN", loader_start, wm_image + WM_SIZE - loader_start, DSK, "build/vos_test.dsk"
        ELSE
        save "VOS.BIN", loader_start, wm_image + WM_SIZE - loader_start, DSK, "build/vos.dsk"
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

; ---- the windows: WM.SYS, loaded at boot into wm_bank of a RAM
; expansion, after the views' code (kernel/ext2.asm: boot_x) -----------
        BANK
        org WM_SYS_ADDR
        include "wm/wm.asm"
wm_sys_end:
        assert wm_sys_end <= #8000
        IFDEF TEST_SCRIPT                     ; on the windows' test disc only:
        IF TEST_SCRIPT == 52 || TEST_SCRIPT == 53 ; the others: no room
        save "WM.SYS", WM_SYS_ADDR, wm_sys_end - WM_SYS_ADDR, DSK, "build/vos_test.dsk"
        ENDIF
        ELSE
        save "WM.SYS", WM_SYS_ADDR, wm_sys_end - WM_SYS_ADDR, DSK, "build/vos.dsk"
        ENDIF

; ---- the formula engine: CALC.SYS, loaded into base RAM bank 1 -------
        BANK
        org CALC_ADDR
        include "calc/calc.asm"
        assert calc_stop <= DB_ADDR
        IFDEF TEST_SCRIPT                     ; on SHEET's test discs only: the
        IF TEST_SCRIPT == 32 || TEST_SCRIPT == 42 ; others have no room
        save "CALC.SYS", CALC_ADDR, calc_stop - CALC_ADDR, DSK, "build/vos_test.dsk"
        ENDIF
        ELSE
        save "CALC.SYS", CALC_ADDR, calc_stop - CALC_ADDR, DSK, "build/vos.dsk"
        ENDIF

; ---- the M4 board's SD card: M4.SYS, loaded into bank 7 -------------
        BANK
        org M4_ADDR
        include "kernel/m4.asm"
m4_stop:
        assert m4_stop <= M4_ADDR + M4_MAX
        IFDEF TEST_SCRIPT                     ; on the M4's test disc only: the
        IF TEST_SCRIPT >= 34                  ; others have no room for it
        save "M4.SYS", M4_ADDR, m4_stop - M4_ADDR, DSK, "build/vos_test.dsk"
        ENDIF
        ELSE
        save "M4.SYS", M4_ADDR, m4_stop - M4_ADDR, DSK, "build/vos.dsk"
        ENDIF

; ---- the database engine: DB.SYS, loaded into base RAM bank 1 -------
        BANK
        org DB_ADDR
        include "db/db.asm"
        IFDEF TEST_SCRIPT                     ; (not on SHEET's: no room)
        IF TEST_SCRIPT != 32
        save "DB.SYS", DB_ADDR, db_stop - DB_ADDR, DSK, "build/vos_test.dsk"
        ENDIF
        ELSE
        save "DB.SYS", DB_ADDR, db_stop - DB_ADDR, DSK, "build/vos.dsk"
        ENDIF

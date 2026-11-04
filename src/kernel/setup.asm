; =====================================================================
; setup.asm - settings kept in A:SETUP.CFG
;
; File: "VCFG", version 5, then CFG_COUNT bytes in the order below
; (version 4 ends before CFG_WIN_X, version 3 before CFG_THEME, version
; 2 before CFG_KBDS too: the rest stays as it is; a version 1 file is
; not read: the defaults).
; at boot (kernel/ext2.asm: boot_x) it is read, if there is one, and applied; the Setup
; view (shell/setup.asm) changes cfg_data, calls cfg_apply to see the
; change at once, and cfg_save to keep it.
; =====================================================================

CFG_VIEW        equ 0               ; view at boot
CFG_LANG        equ 1               ; texts: 0 English, 1 the pack's
CFG_DELAY       equ 2               ; key repeat: frames before the first
CFG_RATE        equ 3               ; frames between repeats
CFG_AMX         equ 4               ; AMX mouse on
CFG_AMX_LEVELS  equ 5               ; AMX: count levels, not edges
CFG_DESK        equ 6               ; ink of the mode 1 desk
CFG_PACK        equ 7               ; the pack: LANG_PACKS (kernel/ext.asm)
CFG_KBDS        equ 8               ; CONTROL+SHIFT: 0 English and the
                                    ; pack's keyboard, 1 all (lang.asm)
CFG_THEME       equ 9               ; 0 light, 1 dark (ui/ui.asm)
CFG_WALL        equ 10              ; the desk's picture: its drive, #FF
CFG_WALL_NAME   equ 11              ; none; its name (11 bytes; ext2.asm)
CFG_WIN_X       equ 22              ; the Desktop's window, kept by KEEP
CFG_WIN_Y       equ 23              ; THE DESKTOP (shell/desktop.asm): x /
CFG_WIN_COLS    equ 24              ; 2, y (0: none kept), its size in
CFG_WIN_ROWS    equ 25              ; cells, its drive (#FF: closed)
CFG_WIN_DRIVE   equ 26
CFG_COUNT       equ 27
CFG_SIZE        equ 5 + CFG_COUNT

; reading it (at boot) and cfg_save are in the second extension
; (kernel/ext2.asm: cfg_load_x, cfg_save_x)
cfg_save:
        ld hl,cfg_save_x
        jp ext2_call

; cfg_data -> the drivers. Destroys: AF, HL
cfg_apply:
        ld a,(lang_loaded)
        or a
        jr z,.keys
        ld a,(cfg_data + CFG_LANG)
        ld (lang_ui),a
.keys:
        ld hl,cfg_data + CFG_DELAY
        ld a,(hl)
        ld (kbd_repeat_delay),a
        inc hl
        ld a,(hl)
        ld (kbd_repeat_rate),a
        inc hl
        ld a,(hl)
        ld (amx_enabled),a
        inc hl
        ld a,(hl)
        ld (amx_levels),a
        inc hl
        ld a,(hl)
        ld (palette_mode1),a
        ret

cfg_data:       db VIEW_DESKTOP, 0, 25, 3, 1, 1, 1, 0, 0, 0, #FF ; English,
                db "           "    ; and the Greek pack, at first; no
                db 0, 0, 0, 0, #FF  ; picture, no window kept
cfg_head        equ bank_buf        ; CFG_SIZE: only while read or written
        assert CFG_SIZE <= 32

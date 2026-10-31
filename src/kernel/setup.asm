; =====================================================================
; setup.asm - settings kept in A:SETUP.CFG
;
; File: "VCFG", version 3, then CFG_COUNT bytes in the order below
; (version 2 has no CFG_KBDS: it stays 0; a version 1 file is not read:
; the defaults).
; cfg_load (boot) reads it, if there is one, and applies it; the Setup
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
CFG_COUNT       equ 9
CFG_SIZE        equ 5 + CFG_COUNT

cfg_load:
        xor a
        call fdc_select
        ld hl,cfg_file
        ld de,BUF_ADDR
        ld c,BUF_CFG
        call fs_load
        jr c,.apply                 ; no file: the defaults
        ld hl,BUF_ADDR
        ld de,cfg_head
        ld bc,CFG_SIZE
        ld a,BUF_CFG
        call bank_get
        ld hl,cfg_head
        ld de,cfg_magic
        ld b,4
.magic:
        ld a,(de)
        cp (hl)
        jr nz,.apply
        inc hl
        inc de
        djnz .magic
        ld a,(hl)                   ; the version
        inc hl
        ld bc,CFG_COUNT
        cp 3
        jr z,.copy
        cp 2
        jr nz,.apply
        dec c                       ; no CFG_KBDS
.copy:
        ld de,cfg_data
        ldir
.apply:
        ld a,(cfg_data + CFG_VIEW)
        ld (view_next),a
        ; fall through

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

; cfg_data -> A:SETUP.CFG. Carry and A = error on failure
cfg_save:
        ld hl,cfg_magic
        ld de,cfg_head
        ld bc,5
        ldir
        ld hl,cfg_data
        ld bc,CFG_COUNT
        ldir
        xor a
        call fdc_select
        ld a,2
        ld (fs_hdr_type),a
        ld hl,0
        ld (fs_hdr_load),hl
        ld (fs_hdr_exec),hl
        ld hl,cfg_file
        ld de,cfg_head
        ld bc,CFG_SIZE
        ld a,BUF_CFG                ; (the source is below #4000)
        jp fs_save

cfg_file:       db "SETUP   CFG"
cfg_magic:      db "VCFG", 3
cfg_data:       db VIEW_DESKTOP, 0, 25, 3, 1, 0, 1, 0, 0 ; English, and the
                                                    ; Greek pack, at first
cfg_head:       ds CFG_SIZE

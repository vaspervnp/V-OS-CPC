; =====================================================================
; setup.asm - settings kept in A:SETUP.CFG
;
; File: "VCFG", version 1, then CFG_COUNT bytes in the order below.
; cfg_load (boot) reads it, if there is one, and applies it; the Setup
; view (shell/setup.asm) changes cfg_data, calls cfg_apply to see the
; change at once, and cfg_save to keep it.
; =====================================================================

CFG_VIEW        equ 0               ; view at boot
CFG_LANG        equ 1               ; 0 English, 1 the pack's language
CFG_DELAY       equ 2               ; key repeat: frames before the first
CFG_RATE        equ 3               ; frames between repeats
CFG_AMX         equ 4               ; AMX mouse on
CFG_AMX_LEVELS  equ 5               ; AMX: count levels, not edges
CFG_DESK        equ 6               ; ink of the mode 1 desk
CFG_COUNT       equ 7
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
        ld b,5
.magic:
        ld a,(de)
        cp (hl)
        jr nz,.apply
        inc hl
        inc de
        djnz .magic
        ld de,cfg_data
        ld bc,CFG_COUNT
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
cfg_magic:      db "VCFG", 1
cfg_data:       db VIEW_DESKTOP, 1, 25, 3, 1, 0, 1
cfg_head:       ds CFG_SIZE

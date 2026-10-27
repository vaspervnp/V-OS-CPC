; =====================================================================
; lang.asm - language packs (.LNG, see tools/mklng.py for the format)
;
; English is built in: kernel font for 32..127, kbd_map, msg_en_table.
; One pack adds codes 128..255 (font and letter case), a keyboard map
; with dead keys, and translated UI texts.
;
; lang_ui    0 = English texts, 1 = pack texts (lang_msg)
; lang_input 0 = English keyboard, 1 = pack keyboard; CONTROL+SHIFT
;            toggles it and posts EV_LANG
;
; Font, case, keymap and combos are copied into the video RAM gaps
; (always mapped), because the text routines and the keyboard interrupt
; use them. The full pack stays in bank 7; lang_msg copies one text from
; there into lang_msg_buf.
; =====================================================================

LNG_FONT        equ 8               ; header offsets
LNG_CASE        equ 10
LNG_KEYMAP      equ 12
LNG_COMBOS      equ 14
LNG_MSGS        equ 16
LNG_SIZE        equ 18
LNG_NAME        equ 20
LANG_COMBOS_MAX equ 32
LANG_MSG_MAX    equ 127

; ---------------------------------------------------------------------
; lang_init - load GREEK.LNG from the disc into bank 7 and copy its
; font, case, keyboard and combo tables into GAP0-GAP2. Without the
; file (or with a bad one) the system stays English.
; Destroys: all
; ---------------------------------------------------------------------
lang_init:
        xor a
        ld (lang_loaded),a
        ld (lang_ui),a
        ld (lang_input),a
        ld hl,lang_file
        ld de,LANG_BANK_ADDR
        ld c,LANG_BANK_CFG
        call fs_load
        ret c
        ld a,LANG_BANK_CFG
        call ram_select
        ld hl,LANG_BANK_ADDR        ; magic "VLNG"
        ld de,lang_magic
        ld b,4
.magic:
        ld a,(de)
        cp (hl)
        jr nz,.bad
        inc hl
        inc de
        djnz .magic
        ld hl,(LANG_BANK_ADDR + LNG_FONT)
        ld de,lang_font_lo
        ld bc,64 * 8
        call .copy
        ld hl,(LANG_BANK_ADDR + LNG_FONT)
        ld de,64 * 8
        add hl,de
        ld de,lang_font_hi
        ld bc,64 * 8
        call .copy
        ld hl,(LANG_BANK_ADDR + LNG_CASE)
        ld de,lang_case
        ld bc,128 * 2
        call .copy
        ld hl,(LANG_BANK_ADDR + LNG_KEYMAP)
        ld de,lang_keymap
        ld bc,160
        call .copy
        ld hl,(LANG_BANK_ADDR + LNG_COMBOS)
        ld de,lang_combos
        ld bc,LANG_COMBOS_MAX * 3
        call .copy
        xor a
        ld (lang_combos + LANG_COMBOS_MAX * 3),a
        ld hl,LANG_BANK_ADDR + 5    ; language code
        ld de,lang_code
        ld bc,2
        ldir
        ld hl,LANG_BANK_ADDR + LNG_NAME
        ld de,lang_name
        ld bc,12
        ldir
        ld a,1
        ld (lang_loaded),a
        ld (lang_ui),a              ; the pack's language is the default
.bad:
        ld a,RAM_BASE_CFG
        jp ram_select
; HL = offset in the pack, DE = destination, BC = length
.copy:
        push de
        ld de,LANG_BANK_ADDR
        add hl,de
        pop de
        ldir
        ret

; ---------------------------------------------------------------------
; ram_select - A = Gate Array RAM configuration (#C0..#C7)
; Destroys: BC
; ---------------------------------------------------------------------
ram_select:
        ld (ram_config),a
        ld b,GA_PORT >> 8
        out (c),a
        ret

; ---------------------------------------------------------------------
; lang_msg - A = MSG_* -> HL = zero-terminated text in the current UI
; language (English if the pack lacks it). A pack text is copied to
; lang_msg_buf, so use it before the next call.
; Main context. Destroys: AF, BC, DE
; ---------------------------------------------------------------------
lang_msg:
        ld (lm_id),a
        ld a,(lang_ui)
        or a
        jr z,.english
        ld a,LANG_BANK_CFG
        call ram_select
        ld hl,(LANG_BANK_ADDR + LNG_MSGS)
        ld de,LANG_BANK_ADDR
        add hl,de
        ld c,(hl)                   ; count
        inc hl
        inc hl
        ld a,(lm_id)
        cp c
        jr nc,.missing
        ld e,a
        ld d,0
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)                   ; offset of the text, 0 = missing
        ld a,d
        or e
        jr z,.missing
        ld hl,LANG_BANK_ADDR
        add hl,de
        ld de,lang_msg_buf
        ld b,LANG_MSG_MAX
.copy:
        ld a,(hl)
        ld (de),a
        or a
        jr z,.copied
        inc hl
        inc de
        djnz .copy
        xor a
        ld (de),a
.copied:
        ld a,RAM_BASE_CFG
        call ram_select
        ld hl,lang_msg_buf
        ret
.missing:
        ld a,RAM_BASE_CFG
        call ram_select
.english:
        ld a,(lm_id)
        ld l,a
        ld h,0
        add hl,hl
        ld de,msg_en_table
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; ---------------------------------------------------------------------
; lang_toggle_input - switch the keyboard between English and the pack.
; Interrupt context (called by the keyboard driver). Posts EV_LANG with
; code = new lang_input.
; Destroys: AF, BC, DE, HL
; ---------------------------------------------------------------------
lang_toggle_input:
        ld a,(lang_loaded)
        or a
        ret z
        ld a,(lang_input)
        xor 1
        ld (lang_input),a
        xor a
        ld (kbd_dead),a
        ld a,(lang_input)
        ld b,a
        ld c,0
        ld a,EV_LANG
        jp ev_post

; ---------------------------------------------------------------------
; lang_other_case - A = character -> A = the other case if it is a
; letter of the pack (codes >= 128), else unchanged.
; Destroys: HL
; ---------------------------------------------------------------------
lang_other_case:
        cp 128
        ret c
        push af
        sub 128
        ld l,a
        ld h,0
        add hl,hl
        push de
        ld de,lang_case
        add hl,de
        pop de
        pop af
        bit 0,(hl)
        ret z
        inc hl
        ld a,(hl)
        ret

; ---------------------------------------------------------------------
; lang_combine - A = dead key code, C = character -> C = combined
; character, or unchanged when the pack has no such combination.
; Destroys: AF, B, HL
; ---------------------------------------------------------------------
lang_combine:
        ld hl,lang_combos
        ld b,a
.next:
        ld a,(hl)
        or a
        ret z
        inc hl
        cp b
        jr nz,.skip
        ld a,(hl)
        cp c
        jr nz,.skip
        inc hl
        ld c,(hl)
        ret
.skip:
        inc hl
        inc hl
        jr .next

; ---- state ----------------------------------------------------------
lang_magic:     db "VLNG"
ram_config:     db RAM_BASE_CFG
lang_loaded:    db 0
lang_ui:        db 0
lang_input:     db 0
lang_code:      db "EN"
lang_name:      ds 12
lm_id:          db 0
lang_file:      db "GREEK   LNG"
; tables in the video RAM gaps (memmap.inc)
lang_font_lo    equ GAP0            ; glyphs 128..191
lang_msg_buf    equ GAP0 + 512      ; LANG_MSG_MAX + 1
lang_font_hi    equ GAP1            ; glyphs 192..255
lang_case       equ GAP2            ; 128 * 2
lang_keymap     equ GAP2 + 256      ; 160
lang_combos     equ GAP2 + 416      ; LANG_COMBOS_MAX * 3 + 1

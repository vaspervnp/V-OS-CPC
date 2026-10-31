; =====================================================================
; lang.asm - language packs (.LNG, see tools/mklng.py for the format)
;
; English is the master: kernel font for 32..127 and kbd_map built in, the
; texts in ENGLISH.MSG (bank 7, EN_MSG_ADDR), used when a text is missing.
; One pack (GREEK, FRENCH, SPANISH, GERMAN or ITALIAN.LNG: CFG_PACK in
; SETUP.CFG) adds codes 128..255 (font and letter case), a keyboard map
; with dead keys, and translated UI texts. lang_init, which loads them
; at boot and when Setup changes the pack, is in the kernel extension
; (kernel/ext.asm).
;
; lang_ui    0 = English texts, 1 = pack texts (lang_msg)
; lang_input 0 = English keyboard, 1 = the pack's keyboard, 2.. the
;            other packs' keyboards (in the pack too, LNG_KBDS);
;            CONTROL+SHIFT goes to the next and posts EV_LANG; ev_get
;            then copies that keyboard into lang_keymap (kbd_load).
;            Setup's KEYBOARDS (CFG_KBDS): 0 English and the pack's,
;            1 all of them
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
LNG_NAME        equ 20              ; 10 bytes
LNG_KBDS        equ 30
LANG_COMBOS_MAX equ 32
LANG_MSG_MAX    equ 151             ; its buffers end by GAP + 664

; ---------------------------------------------------------------------
; ram_select - A = Gate Array RAM configuration (#C0..#C7)
; Destroys: BC
; ---------------------------------------------------------------------
ram_select:
        ld (ram_config),a
        ld b,GA_PORT >> 8
        out (c),a
        ret

; Copies to and from a bank, for views: they run from bank 5 at #4000
; and must not map another bank there themselves.
; bank_put - A = RAM config, HL = source outside #4000-#7FFF, DE = its
;            place in the bank window, BC = bytes
; bank_get - A = RAM config, HL = source in the bank window, DE =
;            destination outside it (bank_buf, 32 bytes, is there for
;            that), BC = bytes
; Destroy: AF, BC, DE, HL
bank_put:
bank_get:
        push bc
        call ram_select
        pop bc
        ldir
        jr ram_home

; map the running view's bank back (plain RAM before the first view)
; Destroys: AF, B
ram_home:
        ld a,(ram_home_cfg)
        jr ram_select

; ---------------------------------------------------------------------
; lang_msg - A = MSG_* -> HL = zero-terminated text in the current UI
; language (English if the pack lacks it). A pack text is copied to
; lang_msg_buf, so use it before the next call.
; Main context. Destroys: AF, BC, DE
; ---------------------------------------------------------------------
lang_msg:
        cp VT_FIRST                 ; a program's own text
        jp nc,api_text
        ld (lm_id),a
        ld a,LANG_BANK_CFG
        call ram_select
        ld a,(lang_ui)
        or a
        jr z,.english
        ld hl,(LANG_BANK_ADDR + LNG_MSGS)
        ld de,LANG_BANK_ADDR
        call .find
        jr nc,.copy
.english:                           ; not translated: the English one
        ld a,(lang_en_ok)
        or a
        jr z,.none
        ld hl,5
        ld de,EN_MSG_ADDR
        call .find
        jr nc,.copy
.none:
        call ram_home
        ld hl,lm_none
        ret
.copy:
        ld de,lang_msg_buf
        ld b,LANG_MSG_MAX
.byte:
        ld a,(hl)
        ld (de),a
        or a
        jr z,.copied
        inc hl
        inc de
        djnz .byte
        xor a
        ld (de),a
.copied:
        call ram_home
        ld hl,lang_msg_buf
        ret
; HL = messages block offset, DE = file base -> HL -> text of lm_id,
; carry if it has none
.find:
        add hl,de
        ld c,(hl)                   ; count (under 256)
        inc hl
        inc hl
        ld a,(lm_id)
        cp c
        ccf
        ret c
        push de
        ld e,a
        ld d,0
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)                   ; offset of the text, 0 = missing
        ld a,d
        or e
        pop hl
        scf
        ret z
        add hl,de
        or a
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
        ld a,(cfg_data + CFG_KBDS)
        or a
        ld a,2
        jr z,.count
        ld a,(lang_kbn)
.count:
        ld b,a
        ld a,(lang_input)
        inc a
        cp b
        jr c,.next
        xor a
.next:
        ld (lang_input),a
        xor a
        ld (kbd_dead),a
        ld a,(lang_input)
        ld b,a
        ld c,0
        ld a,EV_LANG
        jp ev_post

; ev_get, at an EV_LANG: lang_input's keyboard into lang_keymap and
; lang_combos (kb_load, kernel/ext.asm, in bank 7; called directly
; when the extension is running already). Keeps A = EV_LANG.
kbd_load:
        ld hl,kb_load
        ld a,(ram_home_cfg)
        cp LANG_BANK_CFG
        jp nz,ext_call
        jp (hl)

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
ram_config:     db RAM_BASE_CFG
ram_home_cfg:   db RAM_BASE_CFG    ; set by view_switch
bank_buf        equ #9000           ; 32 bytes (include/memmap.inc)
lang_loaded:    db 0
lang_ui:        db 0
lang_input:     db 0
lang_kbn:       db 2                ; keyboards: 1 + the pack's (lang_init)
lang_code:      db "EN"
lang_name:      ds 13               ; 12 + a zero
lm_id:          db 0
lang_file:      db "GREEK   LNG"
lang_en_file:   db "ENGLISH MSG"
lang_en_ok:     db 0
lm_none:        db "?", 0
; tables in the video RAM gaps (memmap.inc)
lang_font_lo    equ GAP0            ; glyphs 128..191
lang_msg_buf    equ GAP0 + 512      ; LANG_MSG_MAX + 1
lang_font_hi    equ GAP1            ; glyphs 192..255
lang_case       equ GAP2            ; 128 * 2
lang_keymap     equ GAP2 + 256      ; 160
lang_combos     equ GAP2 + 416      ; LANG_COMBOS_MAX * 3 + 1
kbd_code        equ GAP2 + 514      ; 2: the code of lang_input's keyboard

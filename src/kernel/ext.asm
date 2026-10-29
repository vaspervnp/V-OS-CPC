; =====================================================================
; ext.asm - the kernel extension: code that does not fit in the kernel,
; in bank 7 at EXT_ADDR (include/memmap.inc). The loader puts it there;
; the kernel calls it through ext_call (kernel/view.asm), which makes
; bank 7 the home bank (ram_home) while it runs, so the kernel routines
; it calls map it back. It must not touch a view's memory.
; =====================================================================

; ---------------------------------------------------------------------
; Program slots (include/memmap.inc): a record of SLOT_SIZE bytes for
; each program that runs, at SLOT_TABLE + id * SLOT_SIZE, id 1..15
; (app_slot, app_wake; 0: none). A program has pages in one bank:
; bank 5 above PROG_ADDR, or a bank of a RAM expansion (bk_list, found
; by xb_detect at boot), from #4000.
; ---------------------------------------------------------------------

; the file in bank 4 (view_fetch, checked): find it a place -> vw_page,
; vw_cfg, app_slot, and the program moved there. Carry: no room.
app_place:
        call reloc_find
        jr c,.fixed
        push bc                     ; a table: as many pages as it has
        push hl
        ld de,0 - BUF_ADDR          ; the program, without its table
        add hl,de
        ld (fs_length),hl
        ld de,255
        add hl,de
        ld b,h
        ld c,0
        call slot_alloc             ; A = pages to move it by
        pop hl
        pop bc
        ret c
        or a
        ret z
        jp reloc
.fixed:
        ld bc,#4001                 ; none: a whole bank, at #4000
        call slot_alloc
        ret nc
        call slot_used              ; or bank 5, alone, without a slot
        scf
        ret nz
        xor a
        ld (app_slot),a
        ld a,VIEW_ADDR >> 8
        ld (vw_page),a
        ld a,VIEW_BANK_CFG
        ld (vw_cfg),a
        ret

; B = pages, C = 1: only from #4000 (no relocation table) -> the first
; room in the banks of bk_list and a new record (page, pages, bank);
; app_slot, vw_page, vw_cfg; A = vw_page - #40. Carry: no room.
slot_alloc:
        push bc
        call slot_new
        pop bc
        ret c
        ld (sa_id),a
        ld hl,bk_list
.bank:
        ld a,(hl)
        or a
        scf
        ret z
        inc hl
        ld (sa_next),hl
        ld (sa_cfg),a
        ld e,PROG_ADDR >> 8         ; the first page to try
        cp VIEW_BANK_CFG
        jr z,.from
        ld e,#40
.from:
        ld a,c
        or a
        jr z,.try
        ld a,e
        cp #40
        jr nz,.next_bank
.try:
        ld a,e                      ; E .. E + B: past the bank?
        add a,b
        cp #81
        jr nc,.next_bank
        ld hl,SLOT_TABLE + SLOT_SIZE
.rec:
        ld a,(hl)
        or a
        jr z,.rec_next
        ld d,a                      ; D .. D + pages: a program
        push hl
        ld a,l
        add a,SLOT_CFG
        ld l,a
        ld a,(sa_cfg)
        cp (hl)
        pop hl
        jr nz,.rec_next             ; in another bank
        inc l
        ld a,d
        add a,(hl)
        dec l
        cp e
        jr c,.rec_next              ; it ends before E
        jr z,.rec_next
        push af
        ld a,e
        add a,b
        cp d
        jr c,.after                 ; it starts after
        jr z,.after
        pop af
        ld e,a                      ; else try after it, if it can move
        ld a,c
        or a
        jr z,.try
        jr .next_bank
.after:
        pop af
.rec_next:
        ld a,l
        add a,SLOT_SIZE
        ld l,a
        jr nz,.rec
        ld a,(sa_id)                ; room at E
        ld (app_slot),a
        call slot_ptr
        ld (hl),e
        inc l
        ld (hl),b
        ld a,l
        add a,SLOT_CFG - SLOT_PAGES
        ld l,a
        ld a,(sa_cfg)
        ld (hl),a
        ld (vw_cfg),a
        ld a,e
        ld (vw_page),a
        sub VIEW_ADDR >> 8          ; (no carry)
        ret
.next_bank:
        ld hl,(sa_next)
        jr .bank

; -> A = a free record's id, HL = it; carry: none
slot_new:
        ld hl,SLOT_TABLE + SLOT_SIZE
.rec:
        ld a,(hl)
        or a
        jr z,slot_id
        ld a,l
        add a,SLOT_SIZE
        ld l,a
        jr nz,.rec
        scf
        ret
; HL = a record -> A = its id
slot_id:
        ld a,l
        rrca
        rrca
        rrca
        rrca
        ret                         ; (no carry: the low bits were 0)

; A = id -> HL = its record
slot_ptr:
        rlca
        rlca
        rlca
        rlca
        ld l,a
        ld h,SLOT_TABLE >> 8
        ret

; -> NZ: some program has a slot
slot_used:
        ld hl,SLOT_TABLE + SLOT_SIZE
.rec:
        ld a,(hl)
        or a
        ret nz
        ld a,l
        add a,SLOT_SIZE
        ld l,a
        jr nz,.rec
        ret

; app_wake: the program in that slot runs again -> app_slot, vw_page,
; vw_cfg
slot_wake:
        ld a,(app_wake)
        ld (app_slot),a
        call slot_ptr
        ld a,(hl)
        ld (vw_page),a
        ld a,l
        add a,SLOT_CFG
        ld l,a
        ld a,(hl)
        ld (vw_cfg),a
        ret

; who runs (app_self: drive, name) into its slot
slot_own:
        ld a,(app_slot)
        or a
        ret z
        call slot_ptr
        inc l
        inc l
        ex de,hl
        ld hl,app_self
        ld bc,12
        ldir
        ret

; the program ends: its slot is free
slot_free:
        ld hl,app_slot
        ld a,(hl)
        ld (hl),0
        or a
        ret z
        call slot_ptr
        ld (hl),0
        ret

; file_name, on drive A:, running? (Launcher) -> Z, A = its slot
slot_find:
        ld hl,SLOT_TABLE + SLOT_SIZE
.rec:
        ld a,(hl)
        or a
        jr z,.next
        push hl
        inc l
        inc l
        ld a,(hl)
        or a
        jr nz,.no
        ld de,file_name
        ld b,11
.char:
        inc l
        ld a,(de)
        cp (hl)
        jr nz,.no
        inc de
        djnz .char
        pop hl
        call slot_id
        cp a
        ret
.no:
        pop hl
.next:
        ld a,l
        add a,SLOT_SIZE
        ld l,a
        jr nz,.rec
        inc a
        ret

; ---------------------------------------------------------------------
; sw_run - the program switcher (F6, or PROGRAMS in the VIEW menu): a
; window that lists the programs in their slots, the running one
; marked ">", the next one selected. F6, DOWN and UP move, RETURN,
; ENTER, SPACE or a click choose, ESC or a click outside close it. The
; one chosen goes on where it was, as from the Launcher (app_run).
; Not while the accessory is open.
; ---------------------------------------------------------------------
SW_W            equ 16 * 8          ; window width
SW_MAX          equ 8               ; programs listed

sw_run:
        ld a,(acc_open)
        or a
        ret nz
        xor a                       ; the slot running now, if any
        ld (sw_cur),a
        ld a,(view_cur)
        cp VIEW_APP
        jr nz,.list
        ld a,(app_slot)
        ld (sw_cur),a
.list:
        ld de,sw_slots              ; the slots in use, as they were
        ld hl,SLOT_TABLE + SLOT_SIZE  ; taken (slot_new: the first free)
        ld bc,0                     ; B = count, C = the one after sw_cur
.scan:
        ld a,(hl)
        or a
        jr z,.free
        ld a,b
        cp SW_MAX
        jr z,.listed
        call slot_id
        ld (de),a
        inc de
        inc b
        push hl
        ld hl,sw_cur
        cp (hl)
        pop hl
        jr nz,.free
        ld c,b
.free:
        ld a,l
        add a,SLOT_SIZE
        ld l,a
        jr nz,.scan
.listed:
        ld a,b
        ld (sw_n),a
        or a
        ld hl,sw_none
        jp z,dialog_run
        ld a,c                      ; past the last: the first
        cp b
        jr c,.sel
        xor a
.sel:
        ld (sw_sel),a
        ld hl,SW_W                  ; height = title 12 + 4 + 10 each + 4
        ld (uw_w),hl
        ld a,b
        add a,a
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,12 + 4 + 4
        ld (uw_h),a
        call ui_centre
        call ui_save_window
        ld a,MSG_SW_T
        call ui_window
        ld a,(sw_n)
.draw:
        dec a
        push af
        call sw_item
        pop af
        jr nz,.draw
        ld a,(ptr_keys_on)          ; the cursor keys are ours
        ld (sw_keys),a
        xor a
        ld (ptr_keys_on),a
.loop:
        call wait_frame
.events:
        call ev_get
        jr z,.idle
        call sw_event               ; A = 0, 1 chosen, 2 closed
        or a
        jr z,.events
        push af
        call ui_restore
        ld a,(sw_keys)
        ld (ptr_keys_on),a
        pop af
        dec a
        ret nz
        call sw_slot                ; the one chosen, unless it runs
        ld hl,sw_cur
        cp (hl)
        ret z
        ld (app_wake),a
        call slot_ptr
        inc l                       ; who it is, for app_run
        inc l
        ld a,(hl)
        ld (app_drive),a
        inc l
        ld de,file_name
        ld bc,11
        ldir
        ld a,VIEW_APP
        jp view_request
.idle:
        call ptr_update
        jr .loop

; A = item: draw it, selected or not
sw_item:
        ld (sw_i),a
        ld hl,(uw_y)                ; y = uw_y + 16 + item * 10
        ld de,16
        add hl,de
        ld de,UI_ITEM_H
        inc a
        jr .y_first
.y_add:
        add hl,de
.y_first:
        dec a
        jr nz,.y_add
        ld (sw_y),hl
        ld a,(sw_i)
        ld hl,sw_sel
        cp (hl)
        ld a,UIP_BAR
        ld bc,UIP_TEXT * 256 + UIP_BAR
        jr nz,.colours
        ld a,UIP_SEL
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        ld (ui_fill_pen),a
        push bc
        ld hl,(uw_x)
        ld de,2
        add hl,de
        ld de,(sw_y)
        ld bc,SW_W - 4
        ld a,UI_ITEM_H
        call ui_rect
        pop bc
        ld a,b
        call ui_colours
        ld a,(sw_i)                 ; "> NAME": up to 8, no spaces
        call sw_slot_a
        ld hl,sw_cur
        cp (hl)
        push af
        call slot_ptr
        pop af
        ld a," "
        jr nz,.mark
        ld a,">"
.mark:
        ld de,sw_text
        ld (de),a
        inc de
        ld a," "
        ld (de),a
        inc de
        ld a,l
        add a,SLOT_NAME
        ld l,a
        ld b,8
.char:
        ld a,(hl)
        cp " "
        jr z,.end
        ld (de),a
        inc hl
        inc de
        djnz .char
.end:
        xor a
        ld (de),a
        ld hl,(uw_x)
        ld de,8
        add hl,de
        ld de,(sw_y)
        inc de
        ld bc,sw_text
        jp ui_text_line

; -> A = the selected slot; sw_slot_a: A = item
sw_slot:
        ld a,(sw_sel)
sw_slot_a:
        ld e,a
        ld d,0
        ld hl,sw_slots
        add hl,de
        ld a,(hl)
        ret

; ev_cur -> A = 0 nothing, 1 chosen, 2 closed
sw_event:
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jr z,.click
        cp EV_KEY_DOWN
        jr z,.key
        cp EV_KEY_REPEAT
        jr z,.key
.none:
        xor a
        ret
.click:
        ld hl,(ev_cur + 4)          ; in the window?
        ld de,(uw_x)
        or a
        sbc hl,de
        jr c,.close
        ld de,SW_W
        sbc hl,de
        jr nc,.close
        ld hl,(ev_cur + 6)
        ld de,(uw_y)
        or a
        sbc hl,de
        jr c,.close
        ld de,16
        sbc hl,de
        jr c,.none                  ; the title
        ld a,h
        or a
        jr nz,.close
        ld a,l                      ; item = (y - 16) / 10
        ld b,-1
.div:
        inc b
        sub UI_ITEM_H
        jr nc,.div
        ld a,b
        ld hl,sw_n
        cp (hl)
        jr z,.none                  ; the margin below
        jr nc,.close
        ld (sw_sel),a
        jr .choose
.key:
        ld a,(ev_cur + 1)
        cp KEY_ESC
        jr z,.close
        cp KEY_RETURN
        jr z,.choose
        cp KEY_ENTER
        jr z,.choose
        ld d,1
        cp KEY_F6
        jr z,.move
        cp KEY_DOWN
        jr z,.move
        ld d,-1
        cp KEY_UP
        jr z,.move
        ld a,(ev_cur + 2)
        cp " "
        jr nz,.none
.choose:
        ld a,1
        ret
.close:
        ld a,2
        ret
.move:
        ld a,(sw_sel)               ; one down or up, round
        push af
        add a,d
        ld hl,sw_n
        jp p,.up_ok
        ld a,(hl)
        dec a
.up_ok:
        cp (hl)
        jr c,.set
        xor a
.set:
        ld (sw_sel),a
        pop af
        call sw_item                ; the old one, then the new one
        ld a,(sw_sel)
        call sw_item
        jp .none

sw_none:        db MSG_SW_T, MSG_SW_NONE, 1, MSG_BTN_OK
sw_slots:       ds SW_MAX
sw_n:           db 0
sw_sel:         db 0
sw_cur:         db 0
sw_i:           db 0
sw_y:           dw 0
sw_keys:        db 0
sw_text:        ds 2 + 8 + 1
sa_id:          db 0
sa_cfg:         db 0
sa_next:        dw 0
; the banks programs may use: bank 5, then those of a RAM expansion
; (xb_detect), 0 at the end
bk_list:        db VIEW_BANK_CFG
                ds XB_MAX + 1, 0

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
        ld (lang_en_ok),a
        ld hl,lang_en_file          ; the English texts
        ld de,EN_MSG_ADDR
        ld c,LANG_BANK_CFG
        call fs_load
        jr c,.pack
        ld a,LANG_BANK_CFG
        call ram_select
        ld hl,(EN_MSG_ADDR)
        call ram_home
        ld de,"M" * 256 + "V"       ; "VM(SG)"
        or a
        sbc hl,de
        jr nz,.pack
        ld a,1
        ld (lang_en_ok),a
.pack:
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
        ld a,1                      ; English until SETUP.CFG chooses
        ld (lang_loaded),a          ; the pack's language (cfg_apply)
.bad:
        jp ram_home
; HL = offset in the pack, DE = destination, BC = length
.copy:
        push de
        ld de,LANG_BANK_ADDR
        add hl,de
        pop de
        ldir
        ret

lang_magic:     db "VLNG"

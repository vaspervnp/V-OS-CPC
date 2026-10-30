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
        inc l                       ; SLOT_FLAGS: it pauses behind
        ld (hl),0
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

; file_name, on sys_drive, running? (Launcher) -> Z, A = its slot
slot_find:
        ld hl,SLOT_TABLE + SLOT_SIZE
.rec:
        ld a,(hl)
        or a
        jr z,.next
        push hl
        inc l
        inc l
        ld a,(sys_drive)
        cp (hl)
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

; VOS_BACKGROUND: E = 1, the program goes on in the background; 0, it
; pauses there (not for the accessory)
slot_bg:
        ld a,(acc_open)
        or a
        ret nz
        ld a,(app_slot)
        or a
        ret z
        call slot_ptr
        ld a,l
        or SLOT_FLAGS
        ld l,a
        ld (hl),e
        ret

; ---------------------------------------------------------------------
; The background: every frame bg_frame (kernel/kernel.asm) gives a
; VE_FRAME to each program whose SLOT_FLAGS say it goes on there, but
; the one in front. bg_first, then bg_next after each, find the next
; one and make it the kernel's program for its event: its bank home
; (through ext_home, which ext_call maps on return), vw_cfg, app_slot,
; cur_base. Its calls but those of bg_open are quiet meanwhile
; (api_quiet). Carry: no more, everything as it was.
; ---------------------------------------------------------------------
bg_first:
        xor a
        ld (bg_id),a
        ld (bg_hushed),a
        ld a,(ext_home)             ; the one in front: kept
        ld (bg_home),a
        ld a,(vw_cfg)
        ld (bg_cfg),a
        ld a,(app_slot)
        ld (bg_slot),a
        ld hl,(cur_base)
        ld (bg_base),hl
        jr bg_find
bg_next:
        ld a,(bg_home)              ; the one in front again
        ld (ext_home),a
        ld a,(bg_cfg)
        ld (vw_cfg),a
        ld a,(bg_slot)
        ld (app_slot),a
        ld hl,(bg_base)
        ld (cur_base),hl
bg_find:
        ld a,(bg_id)
.next:
        inc a
        cp 16
        jr z,.done
        ld (bg_id),a
        call slot_ptr
        ld a,(hl)
        or a
        jr z,.skip
        ld d,a                      ; D = its page, E = its bank
        ld a,l
        or SLOT_FLAGS
        ld l,a
        bit 0,(hl)
        jr z,.skip
        dec l
        ld e,(hl)
        ld a,(view_cur)             ; the program in front: not here
        cp VIEW_APP
        jr nz,.behind
        ld a,(acc_open)
        or a
        jr nz,.behind
        ld a,(bg_slot)
        ld hl,bg_id
        cp (hl)
        jr z,.skip
.behind:
        ld a,(bg_hushed)
        or a
        call z,bg_hush
        ld a,e
        ld (ext_home),a
        ld (vw_cfg),a
        ld a,(bg_id)
        ld (app_slot),a
        ld h,d
        ld l,0
        ld (cur_base),hl
        or a
        ret
.skip:
        ld a,(bg_id)
        jr .next
.done:
        ld a,(bg_hushed)            ; the API as it was
        or a
        jr z,.none
        ld hl,bg_api
        ld de,VOS_API
        ld bc,VOS_API_COUNT * 3
        ldir
.none:
        scf
        ret

; the API table kept in bg_api, then quiet but for bg_open (keeps DE)
bg_hush:
        push de
        ld a,1
        ld (bg_hushed),a
        ld hl,VOS_API
        ld de,bg_api
        ld bc,VOS_API_COUNT * 3
        ldir
        ld de,bg_quiet
.range:
        ld a,(de)                   ; the first call, #FF: no more
        inc de
        inc a
        jr z,.hushed
        dec a
        ld l,a                      ; its target: VOS_API + 1 + 3 * call
        ld h,0
        ld c,l
        ld b,h
        add hl,hl
        add hl,bc
        ld bc,VOS_API + 1
        add hl,bc
        ld a,(de)                   ; how many
        inc de
        ld b,a
.call:
        ld (hl),api_quiet & #FF
        inc hl
        ld (hl),api_quiet >> 8
        inc hl
        inc hl
        djnz .call
        jr .range
.hushed:
        pop de
        ret

; the calls quiet in the background: first, count; all but VOS_FRAMES,
; VOS_RANDOM, VOS_KEEP and VOS_BACKGROUND (VOS_EXT too is quiet)
bg_quiet:       db 0, 2, 4, 32, 37, 2, 40, 3, #FF
        assert (VOS_FRAMES - VOS_API) / 3 == 2 && (VOS_KEEP - VOS_API) / 3 == 36
        assert (VOS_BACKGROUND - VOS_API) / 3 == 39 && VOS_API_COUNT == 43
bg_id           equ #9814           ; (include/memmap.inc)
bg_hushed       equ #9815
bg_home         equ #9816
bg_cfg          equ #9817
bg_slot         equ #9818
bg_base         equ #9819
bg_api          equ GAP0 + 664      ; VOS_API_COUNT * 3 (include/memmap.inc)
        assert lang_msg_buf + LANG_MSG_MAX + 1 <= bg_api
        assert 664 + VOS_API_COUNT * 3 <= GAP_SIZE

; ---------------------------------------------------------------------
; Moving windows (VOS_DRAG, VOS_FIT; kernel/api.asm, ui/ui.asm): a
; window is dr_x, dr_y (drag_run takes it in DE), dr_w, dr_h, in pixels
; of the current mode.
; drag_run, dr_drag = 0: it is moved onto the screen. dr_drag = 1: if
; ev_cur is a click on its top 10 rows, it follows the pointer as a
; dashed outline (drawn with XOR, so drawing it again takes it away)
; until the button goes up -> carry if it moved, dr_x, dr_y where it
; is now. Its x is a multiple of 8, and 4 pixels are kept for a shadow.
; ---------------------------------------------------------------------
dr_x            equ #9800           ; 19 bytes (include/memmap.inc)
dr_y            equ #9802
dr_w            equ #9804
dr_h            equ #9806
dr_drag         equ #9807
dr_nx           equ #9808           ; the outline
dr_ny           equ #980A
dr_gx           equ #980C           ; where in the window it was taken
dr_gy           equ #980E
dr_col          equ #9810           ; outline: a byte on the line
acc_moved       equ #9813           ; the accessory moved (kernel/view.asm)

drag_run:
        ld (dr_y),de
        ld a,(dr_drag)
        or a
        jp z,.fit
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jp nz,.no
        ld hl,(ev_cur + 4)          ; x - dr_x < dr_w ?
        ld de,(dr_x)
        or a
        sbc hl,de
        jr c,.no
        ld (dr_gx),hl               ; where it was taken
        ld de,(dr_w)
        sbc hl,de
        jr nc,.no
        ld hl,(ev_cur + 6)          ; y - dr_y < 10 ?
        ld de,(dr_y)
        or a
        sbc hl,de
        jr c,.no
        ld (dr_gy),hl
        ld de,10
        sbc hl,de
        jr nc,.no
        call .start
        call drag_outline
.frame:
        call ptr_update
        call wait_frame
.event:
        call ev_get
        jr z,.frame
        cp EV_PTR_UP
        jr z,.to
        cp EV_PTR_MOVE
        jr nz,.event
.to:
        push af
        call drag_outline           ; away from where it was
        ld hl,(ev_cur + 4)
        ld de,(dr_gx)
        call .less
        ld (dr_nx),hl
        ld hl,(ev_cur + 6)
        ld de,(dr_gy)
        call .less
        ld (dr_ny),hl
        call drag_clamp
        pop af
        cp EV_PTR_UP
        jr z,.up
        call drag_outline
        jr .event
.up:
        ld hl,(dr_nx)
        ld de,(dr_x)
        or a
        sbc hl,de
        jr nz,.moved
        ld hl,(dr_ny)
        ld de,(dr_y)
        sbc hl,de
        jr nz,.moved
.no:
        or a
        jr .xy
.fit:
        call .start
        call drag_clamp
.moved:
        ld hl,(dr_nx)
        ld (dr_x),hl
        ld hl,(dr_ny)
        ld (dr_y),hl
        scf
.xy:
        ld hl,(dr_x)
        ld de,(dr_y)
        ret
.start:
        ld hl,(dr_x)
        ld (dr_nx),hl
        ld hl,(dr_y)
        ld (dr_ny),hl
        ret
; HL - DE, 0 if below
.less:
        or a
        sbc hl,de
        ret nc
        ld hl,0
        ret

; ui_move: the uw_ window (dialogs) dragged -> carry: it moved, what it
; covered is back and what it covers now is saved (ui/ui.asm)
drag_window:
        ld hl,uw_x                  ; uw_x ... uw_h as dr_x ... dr_h
        ld de,dr_x
        ld bc,7
        ldir
        ld a,1
        ld (dr_drag),a
        ld de,(uw_y)
        call drag_run
        ret nc
        call ui_restore
        ld hl,dr_x
        ld de,uw_x
        ld bc,4
        ldir
        call ui_save_window
        scf
        ret

; dr_nx, dr_ny: the window on the screen (with a mixed screen, in the
; mode 0 band if drawn in mode 0)
drag_clamp:
        ld hl,(gfx_width)           ; x: at most width - w - 4
        ld de,(dr_w)
        or a
        sbc hl,de
        ld de,4
        sbc hl,de
        jr nc,.x
        ld hl,0                     ; (wider than that: at 0)
.x:
        ex de,hl
        ld hl,(dr_nx)
        call .most
        ld a,l
        and %11111000
        ld l,a
        ld (dr_nx),hl
        ld bc,UI_BAR_H              ; y: below the menu bar, or from
                                    ; the top of the band
        ld hl,GFX_H
        ld a,(split_on)
        or a
        jr z,.band
        ld a,(gfx_mode)
        or a
        jr nz,.band
        ld hl,(split_y2)
        ld bc,(split_y1)
.band:
        ld a,(dr_h)                 ; to its bottom - h - 4
        add a,4
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ex de,hl
        ld hl,(dr_ny)
        call .most
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,.y
        ld h,b
        ld l,c
.y:
        ld (dr_ny),hl
        ret
; HL = the smaller of HL and DE
.most:
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; the dashed outline at dr_nx, dr_ny: dashes of 4 pixels
drag_outline:
        call ptr_hide
        ld de,(dr_ny)               ; top and bottom
        call .row                   ; (keeps DE)
        ld a,(dr_h)
        dec a
        ld l,a
        ld h,0
        add hl,de
        ex de,hl
        call .row
        ld hl,(dr_nx)               ; left and right
        call .column
        ld hl,(dr_nx)
        ld bc,(dr_w)
        add hl,bc
        dec hl
.column:
        push hl
        call gfx_x_to_byte
        ld (dr_col),hl
        pop hl
        ld a,l                      ; its pixel
        ld hl,gfx_pmask
        and (hl)
        ld hl,(gfx_pix)
        call tbl_a
        ld c,a
        ld a,(dr_h)                 ; the rows between the corners
        sub 2
        ld b,a
        ld de,(dr_ny)
.c_row:
        inc de
        ld a,e
        and 4
        jr nz,.c_next
        call .line
        ld a,c
        xor (hl)
        ld (hl),a
.c_next:
        djnz .c_row
        ret
; DE = y: the bytes of the window's width, every other 4 pixels
.row:
        push de
        ld hl,(dr_nx)
        call gfx_x_to_byte
        ld (dr_col),hl
        ld hl,(dr_w)
        call gfx_x_to_byte
        ld b,l
        pop de
        call .line
        ld a,(gfx_mode)             ; 4 pixels: 1 byte in mode 1, 2 in
        or a                        ; mode 0
        ld c,1
        jr nz,.r_byte
        inc c
.r_byte:
        ld a,b
        and c
        jr nz,.r_next
        ld a,(hl)
        cpl
        ld (hl),a
.r_next:
        inc hl
        djnz .r_byte
        ret
; DE = y -> HL = the byte at dr_col on that line
.line:
        push de
        ld hl,gfx_lines
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,(dr_col)
        add hl,de
        pop de
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
sw_slots        equ #A800           ; SW_MAX (include/memmap.inc)
sw_n            equ #A808
sw_sel          equ #A809
sw_cur          equ #A80A
sw_i            equ #A80B
sw_y            equ #A80C
sw_keys         equ #A80E
sw_text         equ #A80F           ; 2 + 8 + 1
sa_id           equ #A81A
sa_cfg          equ #A81B
sa_next         equ #A81C
        assert SW_MAX == 8
; the banks programs may use: bank 5, then those of a RAM expansion
; (xb_detect), 0 at the end
bk_list:        db VIEW_BANK_CFG
                ds XB_MAX + 1, 0

; ---------------------------------------------------------------------
; lang_init - load the pack of SETUP.CFG (CFG_PACK: GREEK.LNG, ...)
; from the disc into bank 7 and copy its font, case, keyboard and combo
; tables into GAP0-GAP2. Without the file (or with a bad one) the system
; stays English. Setup calls it again for another pack (cfg_apply then
; sets lang_ui).
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
        ld a,(cfg_data + CFG_PACK)  ; its name
        cp LANG_PACKS
        jr c,.name
        xor a
.name:
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,lang_pack_names
        add hl,de
        ld de,lang_file
        ld bc,8
        ldir
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
; the packs, as CFG_PACK numbers them (Setup's LANGUAGE)
LANG_PACKS      equ 5
lang_pack_names: db "GREEK   FRENCH  SPANISH GERMAN  ITALIAN "
lang_pack_names_end:
        assert lang_pack_names_end - lang_pack_names == LANG_PACKS * 8

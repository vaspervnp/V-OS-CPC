; =====================================================================
; wm.asm - WM.SYS: programs in windows (docs/WINDOWS.md, M74), at
; WM_SYS_ADDR in wm_bank of a RAM expansion, after the views' code
; (gfx/view.asm); boot_x (kernel/ext2.asm) loads it from A:. The kernel
; calls it with wm_call:
;   wm_window   VX_WINDOW (kernel/api.asm: xa_window), vw_buf = w, h
;   wm_event    each event while the program in front is in a window
;               (wm_on), before the program: carry when taken here
; A window is a record, in depth order (the last one in front): the
; program's slot, its bank and page, where its frame is, the size of
; its inside, its drive and name. A program asks for its window first
; in its init. If the screen showed the windows before (wm_was = 1),
; only the frames are drawn: the program then draws its inside;
; otherwise the desk and the windows behind it are drawn again, each by
; its program through init with A = 2 (prog_call), with its view and as
; the kernel's program for that time (wm_paint), the one in front's
; state kept and put back (wm_save, wm_restore).
; Frames: a title line WT high (the program's name, + full screen, X
; close), a border WB wide at the sides and below; the inside starts at
; x + WB, y + WT, x a multiple of 4 (a byte of mode 1).
; Copies (M78): a window that nothing covers is copied from the screen
; into banks of the memory expansion (WM_COPIES, taken at boot) when
; another view starts (wm_snap, from kernel/view.asm) and before one
; moves or is resized; one drawn by its program is copied after it.
; Drawn again, a window with a copy (F_COPY) is copied back: its
; program does not draw.
; The Desktop (M79, shell/desktop.asm: dt_wm -> wm_dt) is a view, not a
; program: its drive icons (at the back) and its files window are two
; records of the list (F_DESK), drawn from their copies only. While it
; is in front (wm_on 1) a click on a program's window brings that one
; to the front; a click on the Desktop's brings the Desktop.
; =====================================================================

WM_MAX          equ 8
WM_REC          equ 32
WT              equ 10              ; the title line (VOS_DRAG's 10 rows)
WB              equ 4               ; the border
R_SLOT          equ 0               ; a record
R_PAGE          equ 1               ; vw_page, then vw_cfg (a word)
R_CFG           equ 2
R_FLAGS         equ 3               ; F_FULL
R_X             equ 4               ; the frame
R_Y             equ 6
R_W             equ 8               ; the inside
R_H             equ 10
R_NAME          equ 12              ; 12: drive, name (as app_self)
R_OX            equ 24              ; the part of its screen it shows
R_OY            equ 26              ; (API 36: VX_WINDOW's x0, y0)
F_FULL          equ 1
F_COPY          equ 2               ; its inside is in its copy (wm_snap)
F_DESK          equ 4               ; the Desktop's (M79): no frame, no
                                    ; program; R_X .. R_H its own place
DT_ICONS_ID     equ #10             ; its R_SLOT: the drive icons, at the
DT_WIN_ID       equ #11             ; back; its files window
WM_MIN_W        equ 64              ; the smallest inside
WM_MIN_H        equ 24

; ---------------------------------------------------------------------
; VX_WINDOW: vw_buf = dw w, h. The program that called (app_slot,
; app_self) gets its window, in front -> carry clear; carry: no room for
; another (it runs full screen)
; ---------------------------------------------------------------------
wm_window:
        push ix
        call .go
        pop ix
        ret
.go:
        ld hl,(vw_x)                ; its w, h (kernel/api.asm: xa_window)
        ld (wm_ret),hl
        ld a,(wm_painting)          ; drawn again from behind: its view
        or a
        jr z,.front
        ld ix,(wm_cur)
        jp wm_view
.front:
        ld hl,(vw_buf)              ; w = 0: no window (a mode 2 page,
        ld a,h                      ; say): it runs full screen as
        or l                        ; before
        jr nz,.ask
        call wm_find
        jr c,.none
        ld l,(ix + R_X)             ; its place kept for its next window
        ld h,(ix + R_X + 1)
        ld (wm_back),hl
        ld l,(ix + R_Y)
        ld h,(ix + R_SLOT)
        ld (wm_back + 2),hl
        call wm_drop
.none:
        ld a,1                      ; its next window: all drawn again
        ld (wm_need),a
        xor a
        ld (wm_on),a
        ld (vw_a),a
        call vw_set
        call wm_pal_on
        scf
        ret
.ask:
        call wm_unask
        call wm_offsets
        call wm_prune
        call wm_find
        jr nc,.found
        call wm_new
        ret c
        jr .top
.found:
        call wm_is_top              ; another was in front (F6): what it
        jr z,.raise                 ; covered is drawn again too
        ld a,1
        ld (wm_need),a
.raise:
        call wm_raise
.top:
        call wm_top
        ld hl,(wm_oxy)              ; the part of its screen it shows
        ld (ix + R_OX),l
        ld (ix + R_OX + 1),h
        ld hl,(wm_oxy + 2)
        ld (ix + R_OY),l
        ld (ix + R_OY + 1),h
        bit 0,(ix + R_FLAGS)
        jr z,.window
        ld a,2                      ; full screen: under the bar, no
        ld (wm_on),a                ; frame (its palette its own)
        call wm_pal_on
        jp wm_view
.window:
        ld a,1
        ld (wm_on),a
        call wm_pal_off             ; in a window: the windows' colours
        ld a,(wm_was)               ; the windows were on the screen?
        dec a
        ld hl,wm_need
        or (hl)
        ld (hl),0
        jr z,.frames
        call wm_mode                ; no: mode 1, the desk and those
        call wm_save                ; behind
        call wm_desk
        call wm_behind
        call wm_restore
        jr .own
.frames:
        ld a,(wm_n)                 ; yes: the one that was in front is
        cp 2                        ; not now
        jr c,.own
        dec a
        dec a
        call wm_ptr
        xor a
        call wm_frame
.own:
        call wm_top
        ld a,1
        call wm_frame
        ; fall through
; IX = a record: the view on its inside, and its w, h written back to
; the program (at wm_ret in its bank, vw_cfg) -> carry clear. Full
; screen (F_FULL): the screen under the bar
wm_view:
        bit 0,(ix + R_FLAGS)
        jr z,.window
        ld hl,0
        ld (vw_buf),hl
        ld l,UI_BAR_H
        ld (vw_buf + 2),hl
        ld hl,(gfx_width)
        ld (vw_buf + 4),hl
        ld hl,GFX_H - UI_BAR_H
        ld (vw_buf + 6),hl
        jr .set
.window:
        ld l,(ix + R_Y)
        ld h,(ix + R_Y + 1)
        ld de,WT
        add hl,de
        ld (vw_buf + 2),hl
        ld l,(ix + R_W)
        ld h,(ix + R_W + 1)
        ld (vw_buf + 4),hl
        ld l,(ix + R_H)
        ld h,0
        ld (vw_buf + 6),hl
        ld l,(ix + R_X)             ; x: a word
        ld h,(ix + R_X + 1)
        ld de,WB
        add hl,de
        ld (vw_buf),hl
.set:
        ld hl,(vw_buf + 4)          ; w, h for the program (vw_buf: not
        ld (vw_buf + 8),hl          ; in the bank window, for bank_put)
        ld hl,(vw_buf + 6)
        ld (vw_buf + 10),hl
        ld a,1
        ld (vw_a),a
        call vw_set
        ld hl,(vw_ox)               ; its (0, 0) at x0, y0 before it
        ld e,(ix + R_OX)
        ld d,(ix + R_OX + 1)
        or a
        sbc hl,de
        ld (vw_ox),hl
        ld hl,(vw_oy)
        ld e,(ix + R_OY)
        ld d,(ix + R_OY + 1)
        or a
        sbc hl,de
        ld (vw_oy),hl
        ld a,(wm_quiet)
        or a
        ret nz
        ld hl,vw_buf + 8
        ld de,(wm_ret)
        ld bc,4
        ld a,(vw_cfg)
        call bank_put
        or a
        ret

; ---------------------------------------------------------------------
; wm_event: ev_cur, the program in front in a window (wm_on 1) or full
; screen (wm_on 2) -> carry: taken here; else ev_cur as the program
; gets it (in its window: x, y from its inside)
; ---------------------------------------------------------------------
wm_event:
        push ix
        call .go
        pop ix
        ret
.go:
        call wm_unask               ; (X's ^Q did not end it)
        ld a,(acc_open)             ; the accessory open: its events,
        or a                        ; and all drawn again after it
        jr z,.free
        ld (wm_redo),a
        jr .no
.free:
        ld a,(wm_redo)              ; the accessory or the switcher
        or a                        ; closed: what they covered
        call nz,wm_redo_all
        ld a,(ev_cur)               ; F5 (the accessory), F6 (the
        cp EV_KEY_DOWN              ; switcher): the windows copied as
        jr nz,.top                  ; they are first
        ld a,(ev_cur + 1)
        cp KEY_F5
        jr z,.over
        cp KEY_F6
        jr nz,.top
.over:
        call wm_snap
        ld a,1
        ld (wm_redo),a
        jr .no
.top:
        call wm_top                 ; the Desktop in front: only a click
        bit 2,(ix + R_FLAGS)        ; on a program's window, here
        jr nz,.desk
        ld a,(ev_cur)
        cp EV_KEY_DOWN
        jr nz,.pointer
        ld a,(ev_cur + 1)           ; F7: full screen and back
        cp KEY_F7
        jr nz,.no
        call wm_top
        jp wm_full
.no:
        or a
        ret
.desk:
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jr nz,.no
        ld a,(ui_open)
        cp UI_NONE
        jr nz,.no
        call wm_hit
        jr c,.no
        bit 2,(ix + R_FLAGS)
        jr nz,.no
        call wm_wake
        scf
        ret
.pointer:
        ld a,(ev_cur)
        cp EV_PTR_MOVE
        jr c,.no
        cp EV_PTR_UP + 1
        jr nc,.no
        ld a,(ui_open)              ; a menu open: the menus' (as it is)
        cp UI_NONE
        jr nz,.no
        ld hl,(ev_cur + 6)          ; the menu bar: as it is
        ld de,UI_BAR_H
        or a
        sbc hl,de
        jr c,.no
        ex de,hl                    ; DE = y under the bar
        call wm_top
        ld a,(wm_on)                ; full screen: from under the bar
        dec a
        jr z,.window
        ld hl,(ev_cur + 4)
        jp wm_local
.window:
        call wm_inside              ; in the window in front: from it
        jp nc,wm_local
.outside:
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jr nz,.taken
        call wm_hit                 ; on a window: which, from the front
        jr c,.taken
        call wm_is_top
        jr nz,.other
        call wm_right               ; its corner, 8 x 8 at the bottom
        ld de,8                     ; right: resized
        add hl,de
        jr nc,.title
        call wm_below
        ld de,8
        add hl,de
        jr nc,.title
        call wm_resize
        jr .taken
.title:
        ld hl,(ev_cur + 6)          ; its title line?
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        or a
        sbc hl,de
        ld de,WT
        sbc hl,de
        jr nc,.taken
        call wm_right               ; HL = x - the frame's right
        ld de,12
        add hl,de
        jr c,.close                 ; the last 12 pixels: X
        ld de,12
        add hl,de
        jr c,.full                  ; the 12 before them: +
        call wm_drag
        jr .taken
.close:
        jp wm_ask
.full:
        call wm_full
        jr .taken
.other:
        call wm_wake                ; another one: to the front
.taken:
        scf
        ret

; IX = a record -> HL = ev_cur's x - the right end of its frame (+1),
; negative inside it
wm_right:
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld e,(ix + R_W)
        ld d,(ix + R_W + 1)
        add hl,de
        ld de,2 * WB
        add hl,de
        ex de,hl
        ld hl,(ev_cur + 4)
        or a
        sbc hl,de
        ret

; IX = the window in front, HL, DE = x, y from its view's corner:
; ev_cur's, from x0, y0 of its program's screen -> carry clear
wm_local:
        ld c,(ix + R_OX)
        ld b,(ix + R_OX + 1)
        add hl,bc
        ld (ev_cur + 4),hl
        ex de,hl
        ld c,(ix + R_OY)
        ld b,(ix + R_OY + 1)
        add hl,bc
        ld (ev_cur + 6),hl
        or a
        ret

; -> wm_oxy: x0, y0 the program that called asks to show (API 36 and
; on: VX_WINDOW's dw w, h, x0, y0; before: 0, 0). Its version is in
; its header (+11), at vw_page in its bank, vw_cfg
wm_offsets:
        ld hl,0
        ld (wm_oxy),hl
        ld (wm_oxy + 2),hl
        ld a,(vw_page)
        ld h,a
        ld l,11
        ld de,bank_buf
        ld bc,1
        ld a,(vw_cfg)
        call bank_get
        ld a,(bank_buf)
        cp 36
        ret c
        ld hl,(wm_ret)
        ld de,4
        add hl,de
        ld de,bank_buf
        ld bc,4
        ld a,(vw_cfg)
        call bank_get
        ld hl,(bank_buf)
        ld (wm_oxy),hl
        ld hl,(bank_buf + 2)
        ld (wm_oxy + 2),hl
        ret

; IX = a record -> HL = ev_cur's y - the bottom of its frame (+1),
; negative inside it
wm_below:
        ld l,(ix + R_Y)
        ld h,(ix + R_Y + 1)
        ld e,(ix + R_H)
        ld d,0
        add hl,de
        ld de,WT + WB
        add hl,de
        ex de,hl
        ld hl,(ev_cur + 6)
        or a
        sbc hl,de
        ret

; IX = a record: ev_cur's x, y in its inside -> HL, DE from it; carry:
; not there
wm_inside:
        ld hl,(ev_cur + 4)
        ld e,(ix + R_X)
        ld d,(ix + R_X + 1)
        or a
        sbc hl,de
        ret c
        ld de,WB
        sbc hl,de
        ret c
        push hl
        ld e,(ix + R_W)
        ld d,(ix + R_W + 1)
        sbc hl,de
        ccf
        pop bc                      ; BC = x in it
        ret c
        ld hl,(ev_cur + 6)
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        sbc hl,de
        ret c
        ld de,WT
        sbc hl,de
        ret c
        ld a,l                      ; y < h?
        cp (ix + R_H)
        ccf
        ret c
        ex de,hl                    ; DE = y in it
        ld h,b
        ld l,c
        or a
        ret

; -> IX = the window whose frame ev_cur's x, y are on, the front one
; first; carry: none
wm_hit:
        ld a,(wm_n)
.rec:
        or a
        scf
        ret z
        dec a
        push af
        call wm_ptr
        call wm_rect
        ld hl,(ev_cur + 4)          ; x0 <= x < x1
        ld de,(wm_r)
        or a
        sbc hl,de
        jr c,.next
        ld hl,(ev_cur + 4)
        ld de,(wm_r + 4)
        or a
        sbc hl,de
        jr nc,.next
        ld hl,(ev_cur + 6)          ; y0 <= y < y1
        ld de,(wm_r + 2)
        or a
        sbc hl,de
        jr c,.next
        ld hl,(ev_cur + 6)
        ld de,(wm_r + 6)
        or a
        sbc hl,de
        jr c,.found
.next:
        pop af
        jr .rec
.found:
        pop af
        or a
        ret

; ---------------------------------------------------------------------
; Moving, full screen, closing, to the front
; ---------------------------------------------------------------------

; IX = the window in front: its title dragged (VOS_DRAG's outline) ->
; where it lands, all drawn again
wm_drag:
        call wm_snap                ; (no program draws again)
        call wm_dims                ; BC = w, A = h of the frame
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        call ui_drag
        ret nc
        call wm_at
        jp wm_redraw_all

; IX = the window in front: its corner dragged (an outline, as
; VOS_DRAG's) -> its new size, all drawn again; its program gets it
; from VX_WINDOW (init with A = 2). The inside: w a multiple of 8, at
; least WM_MIN_W x WM_MIN_H, on the screen
wm_resize:
        call wm_snap                ; the others' copies (not its own:
        res 1,(ix + R_FLAGS)        ; another size)
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld (dr_nx),hl
        ld l,(ix + R_Y)
        ld h,(ix + R_Y + 1)
        ld (dr_ny),hl
        call wm_dims
        ld (dr_w),bc
        ld (dr_h),a
        call wm_outline
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
        call wm_outline             ; away
        ld hl,(ev_cur + 4)          ; w = x - the inside's left, in 8s
        ld e,(ix + R_X)
        ld d,(ix + R_X + 1)
        or a
        sbc hl,de
        jr nc,.w
        ld hl,0
.w:
        ld a,l
        and %11111000
        ld l,a
        ld de,WM_MIN_W
        call wm_larger
        push hl                     ; at most to the screen's right
        ld hl,(gfx_width)
        ld e,(ix + R_X)
        ld d,(ix + R_X + 1)
        or a
        sbc hl,de
        ld de,2 * WB
        sbc hl,de
        ld a,l
        and %11111000
        ld l,a
        ex de,hl
        pop hl
        call wm_min
        ld (wm_nw),hl
        ld de,2 * WB
        add hl,de
        ld (dr_w),hl
        ld hl,(ev_cur + 6)          ; h = y - the inside's top
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        or a
        sbc hl,de
        ld de,WT
        sbc hl,de
        jr nc,.h
        ld hl,0
.h:
        ld de,WM_MIN_H
        call wm_larger
        push hl                     ; at most to the screen's bottom
        ld hl,GFX_H - WT - WB
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        or a
        sbc hl,de
        ex de,hl
        pop hl
        call wm_min
        ld (wm_nh),hl
        ld a,l
        add a,WT + WB
        ld (dr_h),a
        call wm_outline
        pop af
        cp EV_PTR_UP
        jp nz,.event
        call wm_outline             ; away, and the new size
        ld hl,(wm_nw)
        ld (ix + R_W),l
        ld (ix + R_W + 1),h
        ld a,(wm_nh)
        ld (ix + R_H),a
        jr wm_redraw_all

; the outline at dr_nx, dr_ny, dr_w, dr_h (XOR: again takes it away)
wm_outline:
        ld hl,drag_outline
        jp ext2_call

; HL = the larger of HL and DE
wm_larger:
        push hl
        or a
        sbc hl,de
        pop hl
        ret nc
        ex de,hl
        ret

; the desk and every window again, the one in front last: its init
; draws its bar too (the state of the one in front kept and put back)
wm_redraw_all:
        call wm_save
        call wm_desk
        xor a
.rec:
        ld (wm_i),a
        call wm_ptr
        ld a,(wm_n)                 ; the last: in front
        dec a
        ld hl,wm_i
        sub (hl)
        ld a,0
        jr nz,.behind
        inc a
.behind:
        call wm_one
        ld a,(wm_i)
        inc a
        ld hl,wm_n
        cp (hl)
        jr c,.rec
        call wm_restore
        call wm_top                 ; its view where it is now (moved,
        ; fall through              ; resized)
; IX = a record: its view, its w, h not written back
wm_view_quiet:
        ld a,1
        ld (wm_quiet),a
        call wm_view
        xor a
        ld (wm_quiet),a
        ret

; IX = the window in front: full screen, or a window again; its program
; goes on so (VX_WINDOW sees F_FULL)
wm_full:
        ld a,(ix + R_FLAGS)
        and #FF - F_COPY            ; (its program draws it: no copy)
        xor F_FULL
        ld (ix + R_FLAGS),a
        jr wm_wake

; IX = a window: its program to the front (as F6 does: kernel/view.asm,
; app_run), once this event is handled
wm_wake:
        ld a,1                      ; what it covered: all drawn again
        ld (wm_need),a
        bit 2,(ix + R_FLAGS)        ; the Desktop's: the Desktop
        ld a,VIEW_DESKTOP
        jp nz,view_request
        ld a,(ix + R_SLOT)
        ld (app_wake),a
        ld a,(ix + R_NAME)
        ld (app_drive),a
        push ix
        pop hl
        ld de,R_NAME + 1
        add hl,de
        ld de,file_name
        ld bc,11
        ldir
        ld a,VIEW_APP
        jp view_request

; ---------------------------------------------------------------------
; Drawing
; ---------------------------------------------------------------------

; mode 1 and the Desktop's colours (a program may have come from the
; Launcher's mode 0, or set a palette of its own full screen)
wm_mode:
        ld a,1
        call ui_set_mode
        ld hl,palette_mode1
        call ga_set_palette
        ld a,2                      ; the pointer's outline pen
        ld (ptr_pen_out),a
        jp ptr_clamp

; the desk under the menu bar, with the Desktop's picture if it has
; one there (Setup's BACKGROUND, in wall_bank: shell/wall.asm)
wm_desk:
        ld a,UIP_DESK
        ld (ui_fill_pen),a
        ld hl,0
        ld de,UI_BAR_H
        ld bc,(gfx_width)
        ld a,GFX_H - UI_BAR_H
        call ui_rect
        ld a,(cfg_data + CFG_WALL)
        inc a
        ret z
        ld a,(wall_state)           ; loaded by the Desktop
        dec a
        ret nz
        ld a,LANG_BANK_CFG
        ld hl,wall_bank
        ld de,bank_buf
        ld bc,1
        call bank_get
        ld a,(bank_buf)
        or a
        ret z
        ld (wm_cfg),a
        ld a,(ptr_visible)
        ld (wm_pv),a
        call ptr_hide
        xor a
.line:
        ld (wm_y),a                 ; from #4000 + (y & 7) * #800 +
        rrca                        ; (y / 8) * 80, as wall_draw does
        rrca
        rrca
        and #1F
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        add hl,hl
        ld a,(wm_y)
        and 7
        add a,a
        add a,a
        add a,a
        add a,#40
        add a,h
        ld h,a
        push hl
        ld a,(wm_y)                 ; to its line, WALL_X bytes in
        add a,WALL_Y
        ld l,a
        ld h,0
        add hl,hl
        ld de,gfx_lines_all
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,WALL_X
        add hl,de
        ex de,hl
        pop hl
        ld bc,80
        ld a,(wm_cfg)
        call bank_get
        ld a,(wm_y)
        inc a
        cp 200
        jr c,.line
        ld a,(wm_pv)
        or a
        ret z
        jp ptr_show

; the windows behind the one in front, from the back
wm_behind:
        xor a
.rec:
        ld (wm_i),a
        inc a
        ld hl,wm_n
        cp (hl)
        ret nc                      ; (not the last, in front)
        dec a
        call wm_ptr
        xor a
        call wm_one
        ld a,(wm_i)
        inc a
        jr .rec

; IX = a window, A = 1 in front: its frame, then its inside by its
; program (init with A = 2), as the kernel's program; VOS_OPEN hidden
; from it (a file for the program starting, not for those behind)
wm_one:
        call wm_frame
        bit 1,(ix + R_FLAGS)        ; F_COPY: its copy back, no more
        jr z,.draw
        call wm_paste
        ret nc
.draw:
        bit 2,(ix + R_FLAGS)        ; the Desktop's: nothing more
        ret nz
        ld a,(ix + R_SLOT)
        ld (app_slot),a
        ld l,(ix + R_PAGE)
        ld h,(ix + R_CFG)
        ld (vw_page),hl
        ld (wm_cur),ix
        ld a,1
        ld (wm_painting),a
        ld hl,(wm_ret)              ; (its VX_WINDOW sets its own)
        push hl
        ld hl,VOS_OPEN              ; a file to open is not its: hidden
        ld a,(hl)
        push af
        ld (hl),0
        ld a,2
        push ix
        call prog_call
        pop ix
        pop af
        ld (VOS_OPEN),a
        pop hl
        ld (wm_ret),hl
        xor a
        ld (wm_painting),a
        jp wm_snap_one              ; whole on the screen now: copied

; IX = a window, A = 1 in front: its frame (the title in the selection's
; colours in front)
wm_frame:
        bit 2,(ix + R_FLAGS)        ; the Desktop's: its own
        ret nz
        ld (wm_act),a
        or a
        ld a,UIP_BAR
        jr z,.title
        ld a,UIP_SEL
.title:
        ld (ui_fill_pen),a
        call wm_dims                ; the title line
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        ld a,WT
        call ui_rect
        ld a,UIP_BAR                ; the border: left, right, below
        ld (ui_fill_pen),a
        call .side
        ld l,(ix + R_W)
        ld h,(ix + R_W + 1)
        ld de,WB
        add hl,de
        call .side_at
        call wm_dims
        ld l,(ix + R_Y)
        ld h,(ix + R_Y + 1)
        ld de,WT
        add hl,de
        ld e,(ix + R_H)
        ld d,0
        add hl,de
        ex de,hl
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld a,WB
        call ui_rect
        ld a,(wm_act)               ; the name, + and X
        or a
        ld bc,UIP_BAR
        ld a,UIP_TEXT
        jr z,.colours
        ld bc,UIP_SEL
        ld a,UIP_SELTEXT
.colours:
        call ui_colours
        push ix
        pop hl
        ld de,R_NAME + 1
        add hl,de
        ex de,hl
        ld hl,wm_text
        ld b,8
.char:
        ld a,(de)
        cp " "
        jr z,.end
        ld (hl),a
        inc hl
        inc de
        djnz .char
.end:
        ld (hl),0
        ld bc,wm_text
        ld de,8
        call .text
        call wm_dims                ; + at w - 20, X at w - 8
        push bc
        ld hl,-20
        add hl,bc
        ex de,hl
        ld bc,wm_plus
        call .text
        pop hl
        ld de,-8
        add hl,de
        ex de,hl
        ld bc,wm_x
; BC = text at DE pixels from the frame's left, in the title line
.text:
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        add hl,de
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        inc de
        jp ui_text_line
; a side WB wide at the frame's left (.side) or HL pixels from it
.side:
        ld hl,0
.side_at:
        ld e,(ix + R_X)
        ld d,(ix + R_X + 1)
        add hl,de
        push hl
        ld l,(ix + R_Y)
        ld h,(ix + R_Y + 1)
        ld de,WT
        add hl,de
        ex de,hl
        pop hl
        ld bc,WB
        ld a,(ix + R_H)
        jp ui_rect

; IX = a window -> BC = its frame's width, A = its height
wm_dims:
        ld c,(ix + R_W)
        ld b,(ix + R_W + 1)
        ld a,(ix + R_H)
        bit 2,(ix + R_FLAGS)        ; the Desktop's: no frame
        ret nz
        ld hl,2 * WB
        add hl,bc
        ld b,h
        ld c,l
        ld a,(ix + R_H)
        add a,WT + WB
        ret

; ---------------------------------------------------------------------
; The list
; ---------------------------------------------------------------------

; A = index -> IX = its record
wm_ptr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                   ; * WM_REC
        ld de,wm_recs
        add hl,de
        push hl
        pop ix
        ret

; -> IX = the one in front (the last)
wm_top:
        ld a,(wm_n)
        dec a
        jr wm_ptr

; IX = a record -> Z: the one in front
wm_is_top:
        push ix
        call wm_top
        push ix
        pop hl
        pop ix
        push ix
        pop de
        or a
        sbc hl,de
        ret

; the program that called (app_slot, app_self) -> IX = its window;
; carry: none
wm_find:
        ld a,(wm_n)
.rec:
        or a
        scf
        ret z
        dec a
        push af
        call wm_ptr
        ld a,(app_slot)
        cp (ix + R_SLOT)
        jr nz,.next
        call wm_same
        jr z,.found
.next:
        pop af
        jr .rec
.found:
        pop af
        or a
        ret

; IX = a record -> Z: app_self is its drive and name
wm_same:
        push ix
        pop hl
        ld de,R_NAME
        add hl,de
        ld de,app_self
        ld b,12
.char:
        ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .char
        ret

; a new window, in front, for the program that called: its size from
; vw_buf, a place down and right of the last one -> IX; carry: no room
wm_new:
        ld a,(wm_n)
        cp WM_MAX
        ccf
        ret c
        inc a
        ld (wm_n),a
        call wm_top
        push ix                     ; empty it
        pop hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,WM_REC - 1
        ldir
        ld a,(app_slot)
        ld (ix + R_SLOT),a
        ld hl,(vw_page)
        ld (ix + R_PAGE),l
        ld (ix + R_CFG),h
        push ix
        pop hl
        ld de,R_NAME
        add hl,de
        ex de,hl
        ld hl,app_self
        ld bc,12
        ldir
        ld a,(gfx_mode)             ; mode 1 first (from the Launcher
        dec a                       ; still mode 0: the window was cut to
        call nz,wm_mode             ; its width, and placed for it)
        ld hl,(vw_buf)              ; w: a multiple of 8, on the screen
        ld a,l
        and %11111000
        ld l,a
        ld de,(gfx_width)
        ex de,hl
        ld bc,2 * WB
        or a
        sbc hl,bc
        call wm_min
        ld (ix + R_W),l
        ld (ix + R_W + 1),h
        ld hl,(vw_buf + 2)          ; h: on the screen too
        ld de,GFX_H - UI_BAR_H - WT - WB
        call wm_min
        ld (ix + R_H),l
        ld a,(wm_place)             ; x 16, 40, 64 ..., y 20, 36, 52 ...
        ld b,a
        inc a
        and 7
        ld (wm_place),a
        ld a,b
        add a,a                     ; * 24
        add a,b
        add a,a
        add a,a
        add a,a
        add a,16
        ld l,a
        ld h,0
        ld (ix + R_X),l
        ld (ix + R_X + 1),h
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,20
        ld (ix + R_Y),a
        ld (ix + R_Y + 1),0
        ld hl,wm_back + 3           ; out of the windows and back (w = 0
        ld a,(app_slot)             ; before): where it was
        cp (hl)
        jr nz,.fit
        ld (hl),#FF
        dec hl
        ld a,(hl)
        ld (ix + R_Y),a
        ld hl,(wm_back)
        ld (ix + R_X),l
        ld (ix + R_X + 1),h
.fit:
        call wm_dims                ; on the screen: VOS_FIT
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        call ui_fit
        call wm_at
        or a
        ret

; IX = a window, HL = x, DE = y: its place, x down to a multiple of 4
wm_at:
        ld a,l
        and %11111100
        ld (ix + R_X),a
        ld (ix + R_X + 1),h
        ld (ix + R_Y),e
        ld (ix + R_Y + 1),d
        ret

; HL = the smaller of HL and DE
wm_min:
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; IX = a record: to the front (the last) -> IX = it there
wm_raise:
        push ix                     ; it, aside
        pop hl
        push hl
        ld de,wm_tmp
        ld bc,WM_REC
        ldir
        pop de                      ; the ones after it, one back
        ld hl,WM_REC
        add hl,de
        ex de,hl                    ; HL = it, DE = the next
        push hl
        ld hl,wm_recs + WM_MAX * WM_REC
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        ex de,hl
        ld a,b
        or c
        jr z,.last
        ldir
.last:
        call wm_top
        push ix
        pop de
        ld hl,wm_tmp
        ld bc,WM_REC
        ldir
        ret

; IX = a record: out of the list
wm_drop:
        call wm_free                ; its copy's banks free
        call wm_raise               ; to the end, then one fewer
        ld hl,wm_n
        dec (hl)
        ret

; the windows whose programs have ended (their slot free, or another's
; now: kernel/ext.asm, slot_alive) out of the list; vw_buf (VX_WINDOW's
; w, h) kept
wm_prune:
        ld hl,vw_buf
        ld de,wm_wh
        ld bc,4
        ldir
        ld a,(wm_n)
.rec:
        or a
        jr z,.done
        dec a
        ld (wm_i),a
        call wm_ptr
        bit 2,(ix + R_FLAGS)        ; the Desktop's stay
        jr nz,.kept
        ld a,(ix + R_SLOT)
        ld (vw_a),a
        push ix
        pop hl
        ld de,R_NAME
        add hl,de
        ld de,vw_buf
        ld bc,12
        ldir
        ld hl,slot_alive
        call ext_call
        ld a,(vw_a)
        or a
        call z,wm_drop_i
.kept:
        ld a,(wm_i)
        jr .rec
.done:
        ld hl,wm_wh
        ld de,vw_buf
        ld bc,4
        ldir
        ret
wm_drop_i:
        ld a,(wm_i)
        call wm_ptr
        jp wm_drop

; ---------------------------------------------------------------------
; The program in front's state, kept while the others draw (acc_vars:
; its frame events, texts, buttons and menu bar, its view; and its
; bank, entries and slot)
; ---------------------------------------------------------------------
wm_save:
        ld hl,acc_vars
        ld de,wm_ctx
        ld b,8
.byte:
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(bc)
        ld (de),a
        inc de
        pop bc
        djnz .byte
        ld hl,(cur_base)
        ld (wm_ctx + 8),hl
        ld hl,(vw_page)
        ld (wm_ctx + 10),hl
        ld a,(app_slot)
        ld (wm_ctx + 12),a
        ld hl,vw_ox
        ld de,wm_ctx + 13
        ld bc,12
        ldir
        ret

wm_restore:
        ld hl,acc_vars
        ld de,wm_ctx
        ld b,8
.byte:
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(de)
        ld (bc),a
        inc de
        pop bc
        djnz .byte
        ld hl,(wm_ctx + 8)
        ld (cur_base),hl
        ld hl,(wm_ctx + 10)
        ld (vw_page),hl
        ld a,(wm_ctx + 12)
        ld (app_slot),a
        ld hl,wm_ctx + 13
        ld de,vw_ox
        ld bc,12
        ldir
        ret

; ---------------------------------------------------------------------
; wm_bg: kernel/ext.asm (bg_find) chose the next program that goes on
; in the background (bg_id), or found no more (the API as it was), the
; program in front in a window (wm_on 1). If that one has a window that
; no window in front of it covers, it draws there: its view, and its
; drawing calls (VOS_CLS ... VOS_CHAR, VOS_BLIT) and VOS_EXT not quiet;
; the view and the text colours of the one in front put back after it.
; ---------------------------------------------------------------------
BG_OPEN         equ 8               ; VOS_CLS, VOS_PLOT, VOS_RECT,
BG_OPEN_N       equ 6               ; VOS_COLOURS, VOS_PRINT, VOS_CHAR
BG_BLIT         equ 32              ; and VOS_BLIT
BG_EXT          equ 42              ; and VOS_EXT (M80)
WM_BG_VW        equ vw_y1 + 2 - vw_on
        assert (VOS_CLS - VOS_API) / 3 == BG_OPEN
        assert (VOS_CHAR - VOS_API) / 3 == BG_OPEN + BG_OPEN_N - 1
        assert (VOS_BLIT - VOS_API) / 3 == BG_BLIT
        assert (VOS_EXT - VOS_API) / 3 == BG_EXT
wm_bg:
        push ix
        call .go
        pop ix
        ret
.go:
        ld a,(wm_bg_on)             ; the last one's: shut
        or a
        call nz,wm_bg_shut
        call wm_hushed              ; none left: the API is as it was
        ret nz
        ld a,(ui_open)              ; a menu or the accessory over them
        cp UI_NONE
        ret nz
        ld a,(acc_open)
        or a
        ret nz
        ld a,(wm_n)                 ; its window, behind the one in front
        dec a
        ret z
.rec:
        dec a
        ld (wm_i),a
        call wm_ptr
        ld a,(bg_id)
        cp (ix + R_SLOT)
        jr z,.found
        ld a,(wm_i)
        or a
        ret z
        jr .rec
.found:
        ld a,(wm_i)                 ; covered by one in front of it?
        call wm_covered
        ret c
        res 1,(ix + R_FLAGS)        ; open: it draws (its copy gets old);
        ld hl,vw_on                 ; the front one's view and colours
        ld de,wm_bg_view
        ld bc,WM_BG_VW
        ldir
        ld hl,txt_fg
        ld de,wm_bg_txt
        ld bc,9
        ldir
        call wm_view_quiet
        ld hl,bg_api + 3 * BG_OPEN
        ld de,VOS_API + 3 * BG_OPEN
        ld bc,3 * BG_OPEN_N
        ldir
        ld hl,bg_api + 3 * BG_BLIT
        ld de,VOS_API + 3 * BG_BLIT
        ld bc,3
        ldir
        ld hl,bg_api + 3 * BG_EXT   ; and VOS_EXT (TELNET receives)
        ld de,VOS_API + 3 * BG_EXT
        ld bc,3
        ldir
        ld a,1
        ld (wm_bg_on),a
        ret

; the one in front's view and colours back; the calls quiet again
; (unless the API is all back)
wm_bg_shut:
        xor a
        ld (wm_bg_on),a
        ld hl,wm_bg_view
        ld de,vw_on
        ld bc,WM_BG_VW
        ldir
        ld hl,wm_bg_txt
        ld de,txt_fg
        ld bc,9
        ldir
        call wm_hushed
        ret nz
        ld hl,VOS_API + 3 * BG_OPEN + 1
        ld b,BG_OPEN_N
.call:
        ld (hl),api_quiet & #FF
        inc hl
        ld (hl),api_quiet >> 8
        inc hl
        inc hl
        djnz .call
        ld hl,VOS_API + 3 * BG_BLIT + 1
        call .quiet
        ld hl,VOS_API + 3 * BG_EXT + 1
.quiet:
        ld (hl),api_quiet & #FF
        inc hl
        ld (hl),api_quiet >> 8
        ret

; -> Z: the API is quiet (a program behind is the kernel's); NZ: it is
; as it was (bg_find found no more and put it back)
wm_hushed:
        ld hl,(VOS_API + 1)         ; VOS_EXIT: always quiet there
        ld de,api_quiet
        or a
        sbc hl,de
        ret

; A = index -> IX = its record; carry: a window in front of it overlaps
; its frame
wm_covered:
        ld (wm_ci),a
        call wm_ptr
        call wm_rect
        ld hl,wm_r
        ld de,wm_r2
        ld bc,8
        ldir
        ld a,(wm_ci)
.over:
        inc a
        ld hl,wm_n
        cp (hl)
        jr nc,.open
        push af
        call wm_ptr
        call wm_rect
        call wm_overlap
        pop bc
        ld a,b
        jr nc,.over
.open:
        push af                     ; (carry)
        ld a,(wm_ci)
        call wm_ptr
        pop af
        ret

; ---------------------------------------------------------------------
; M80: VOS_PALETTE while a program is in front in a window (the
; windows keep the Desktop's colours), and X asking the program
; ---------------------------------------------------------------------

; VOS_PALETTE quiet (api_quiet), its routine kept
wm_pal_off:
        ld hl,(wm_pal)
        ld a,h
        or l
        ret nz
        ld hl,(VOS_PALETTE + 1)
        ld (wm_pal),hl
        ld hl,api_quiet
        ld (VOS_PALETTE + 1),hl
        ret

; VOS_PALETTE as it was
wm_pal_on:
        ld hl,(wm_pal)
        ld a,h
        or l
        ret z
        ld (VOS_PALETTE + 1),hl
        ld hl,0
        ld (wm_pal),hl
        ret

; IX = the window in front: its X. Its program gets CONTROL+Q (BACK in
; every program of V-OS: it may ask first, as NOTEPAD does about
; changes) in place of the click -> carry clear, ev_cur its now. If it
; ends, the window of the next program behind it comes to the front
; (app_return and app_wake for that time: wm_unask puts them back)
wm_ask:
        ld a,(wm_n)
        dec a
        ld (wm_i),a
.prog:
        ld a,(wm_i)                 ; the next program's window
        or a
        jr z,.key
        dec a
        ld (wm_i),a
        call wm_ptr
        bit 2,(ix + R_FLAGS)
        jr nz,.prog
        ld a,(app_return)
        ld (wm_ret_view),a
        ld a,VIEW_APP
        ld (app_return),a
        ld a,1
        ld (wm_asked),a
        ld (wm_need),a
        ld a,(ix + R_SLOT)
        ld (app_wake),a
        ld a,(ix + R_NAME)
        ld (app_drive),a
        push ix
        pop hl
        ld de,R_NAME + 1
        add hl,de
        ld de,file_name
        ld bc,11
        ldir
.key:
        ld hl,ev_cur
        ld (hl),EV_KEY_DOWN
        inc hl
        ld (hl),KEY_Q
        inc hl
        ld (hl),"Q" - "@"
        inc hl
        ld (hl),MOD_CONTROL
        or a
        ret
KEY_Q           equ 67              ; (drivers/kbd.asm: line 8, bit 3)

; the accessory or the switcher closed over the windows: all drawn
; again, the one in front by its program (its copy is old); the Desktop
; or a full screen draws itself
wm_redo_all:
        xor a
        ld (wm_redo),a
        call wm_top
        ld a,(ix + R_FLAGS)
        and F_DESK + F_FULL
        ret nz
        res 1,(ix + R_FLAGS)
        jp wm_redraw_all

; X's ^Q handled: app_return as it was (and app_wake, unless the next
; program has started with it)
wm_unask:
        ld a,(wm_asked)
        or a
        ret z
        xor a
        ld (wm_asked),a
        ld (app_wake),a
        ld a,(wm_ret_view)
        ld (app_return),a
        ret

; ---------------------------------------------------------------------
; wm_dt: the Desktop (shell/desktop.asm: dt_wm), E =
;   0  it starts: the windows of ended programs out, its drive icons a
;      record at the back (their copy taken when it ends), wm_on 1
;   1  its desk is drawn: the programs' windows over it, from the back
;      (it draws its bar again after them)
;   2  its files window drawn, at dt_wx, dt_wy, vw_buf = w, h: its
;      record, in front
;   3  no files window
; ---------------------------------------------------------------------
wm_dt:
        push ix
        call .go
        pop ix
        ret
.go:
        ld a,e
        or a
        jr z,.start
        dec a
        jr z,.windows
        dec a
        jr z,.window
.drop:
        ld a,DT_WIN_ID
        call wm_desk_find
        ret c
        jp wm_drop
.start:
        call wm_prune
        call .drop
        ld a,DT_ICONS_ID
        call wm_desk_find
        jr nc,.icons
        ld a,DT_ICONS_ID
        call wm_add
        ret c
        ld hl,DT_DRIVE_X
        ld (ix + R_X),l
        ld (ix + R_X + 1),h
        ld (ix + R_Y),DT_DRIVE_Y
        ld (ix + R_W),DT_DRIVE_W
        ld (ix + R_H),2 * DT_DRIVE_STEP + DT_DRIVE_H
        call wm_lower
.icons:
        res 1,(ix + R_FLAGS)        ; (copied again when it ends)
        ld a,1
        ld (wm_on),a
        ret
.windows:
        call wm_save
        xor a
.rec:
        ld (wm_i),a
        ld hl,wm_n
        cp (hl)
        jr nc,.done
        call wm_ptr
        bit 2,(ix + R_FLAGS)
        jr nz,.next
        xor a
        call wm_one
.next:
        ld a,(wm_i)
        inc a
        jr .rec
.done:
        call wm_restore             ; and no view (the Desktop draws its
        xor a                       ; bar again itself: it is not mapped
        ld (vw_a),a                 ; here)
        jp vw_set
.window:
        ld a,DT_WIN_ID
        call wm_desk_find
        jr nc,.have
        ld a,DT_WIN_ID
        call wm_add
        ret c
.have:
        ld hl,(vw_buf)
        ld (ix + R_W),l
        ld (ix + R_W + 1),h
        ld a,(vw_buf + 2)
        ld (ix + R_H),a
        ld hl,(dt_wx)
        ld (ix + R_X),l
        ld (ix + R_X + 1),h
        ld hl,(dt_wy)
        ld (ix + R_Y),l
        ld (ix + R_Y + 1),h
        res 1,(ix + R_FLAGS)        ; (copied when the Desktop ends)
        jp wm_raise

; A = DT_ICONS_ID or DT_WIN_ID -> IX = that record; carry: none
wm_desk_find:
        ld c,a
        ld a,(wm_n)
.rec:
        or a
        scf
        ret z
        dec a
        call wm_ptr
        ld b,a
        ld a,(ix + R_SLOT)
        cp c
        ld a,b
        jr nz,.rec
        bit 2,(ix + R_FLAGS)
        jr z,.rec
        or a
        ret

; A = an id -> IX = a new record of the Desktop's, empty, in front;
; carry: no room
wm_add:
        ld c,a
        ld a,(wm_n)
        cp WM_MAX
        ccf
        ret c
        inc a
        ld (wm_n),a
        push bc
        call wm_top
        push ix
        pop hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,WM_REC - 1
        ldir
        pop bc
        ld (ix + R_SLOT),c
        ld (ix + R_FLAGS),F_DESK
        or a
        ret

; IX = a record: to the back (the first) -> IX = it there
wm_lower:
        push ix
        pop hl
        ld de,wm_tmp
        ld bc,WM_REC
        ldir
        push ix                     ; BC = the bytes before it
        pop hl
        ld de,wm_recs
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        jr z,.place
        push ix                     ; one record on, from the last byte
        pop hl
        dec hl
        ld de,WM_REC
        add hl,de
        ex de,hl                    ; DE = its last byte
        push ix
        pop hl
        dec hl                      ; HL = the byte before it
        lddr
.place:
        ld hl,wm_tmp
        ld de,wm_recs
        ld bc,WM_REC
        ldir
        ld ix,wm_recs
        ret

; ---------------------------------------------------------------------
; Copies (M78): a window's inside, row by row, in banks of WM_COPIES
; (16K each, as many rows in each as fit), the banks it has marked with
; its slot in wm_units
; ---------------------------------------------------------------------

; every window that nothing covers (and not full screen) into its copy:
; from kernel/view.asm (another view starts), and before one moves
; another view starts (kernel/view.asm: view_start): VOS_PALETTE as it
; was, and the windows copied
wm_snap_view:
        call wm_pal_on
        ; fall through
wm_snap:
        ld hl,wm_redo               ; the switcher over them (F6): not as
        ld a,(hl)                   ; they are
        ld (hl),0
        or a
        ret nz
        ld a,(acc_open)             ; the accessory or a menu over them:
        or a                        ; not as they are
        ret nz
        ld a,(ui_open)
        cp UI_NONE
        ret nz
        push ix
        ld a,(wm_n)
.rec:
        or a
        jr z,.end
        dec a
        ld (wm_si),a
        call wm_covered
        call nc,wm_snap_one
        ld a,(wm_si)
        jr .rec
.end:
        pop ix
        ret

; IX = a window, whole on the screen: its inside into its copy (none if
; it is full screen, or too few banks are free for it)
wm_snap_one:
        call wm_free
        res 1,(ix + R_FLAGS)
        bit 0,(ix + R_FLAGS)
        ret nz
        call wm_geom
        ret c
        ld a,(ix + R_H)             ; C = banks: h / wm_rpb, up
        ld c,0
.need:
        inc c
        ld hl,wm_rpb
        sub (hl)
        jr z,.count
        jr nc,.need
.count:
        ld a,(WM_COPIES)            ; that many free?
        or a
        ret z
        ld b,a
        ld hl,wm_units
        ld e,0
.free:
        ld a,(hl)
        or a
        jr nz,.taken
        inc e
.taken:
        inc hl
        djnz .free
        ld a,e
        cp c
        ret c
        ld hl,wm_units              ; taken
.take:
        ld a,(hl)
        or a
        jr nz,.next
        ld a,(ix + R_SLOT)
        ld (hl),a
        dec c
        jr z,.rows
.next:
        inc hl
        jr .take
.rows:
        xor a                       ; the screen into them
        call wm_rows
        set 1,(ix + R_FLAGS)
        ret

; IX = a window with a copy: it back on the screen; carry: it cannot be
; (its inside not at a byte)
wm_paste:
        call wm_geom
        ret c
        ld a,1
        call wm_rows
        or a
        ret

; IX = a window: the banks of its copy free
wm_free:
        ld hl,wm_units
        ld b,WM_COPIES_N
.unit:
        ld a,(hl)
        cp (ix + R_SLOT)
        jr nz,.next
        ld (hl),0
.next:
        inc hl
        djnz .unit
        ret

; IX = a window -> wm_cx = its inside's first byte in a line, wm_cw its
; bytes, wm_cy its first line, wm_rpb its rows in a bank (up to 255);
; carry: its inside does not start at a byte
wm_geom:
        ld de,WB * 256 + WT         ; the frame (D, E), none for the
        bit 2,(ix + R_FLAGS)        ; Desktop's
        jr z,.frame
        ld de,0
.frame:
        ld a,e
        ld (wm_cy),a
        ld e,d
        ld d,0
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        add hl,de
        ld a,l
        and 3
        scf
        ret nz
        srl h
        rr l
        srl h
        rr l
        ld (wm_cx),hl
        ld l,(ix + R_W)
        ld h,(ix + R_W + 1)
        srl h
        rr l
        srl h
        rr l
        ld (wm_cw),hl
        ex de,hl                    ; rows in 16K: 16384 / bytes
        ld hl,#4000
        ld b,0
.rpb:
        or a
        sbc hl,de
        jr c,.rpb_end
        inc b
        ld a,b
        inc a
        jr nz,.rpb
.rpb_end:
        ld a,b
        ld (wm_rpb),a
        ld a,(wm_cy)
        ld e,a
        ld d,0
        ld l,(ix + R_Y)
        ld h,(ix + R_Y + 1)
        add hl,de
        ld (wm_cy),hl
        or a
        ret

; IX = a window (wm_geom done), A = 0: its rows from the screen into its
; banks; 1: back. The pointer hidden meanwhile
wm_rows:
        ld (wm_dir),a
        ld a,(ptr_visible)
        ld (wm_pv),a
        call ptr_hide
        ld a,(ix + R_SLOT)
        ld (wm_own),a
        ld hl,wm_units - 1
        ld (wm_up),hl
        ld hl,(wm_cy)
        ld (wm_y),hl
        ld b,0                      ; rows left in this bank
        ld c,(ix + R_H)
.row:
        ld a,b
        or a
        call z,.unit
        push bc
        ld hl,(wm_y)                ; the screen: its line, from wm_cx
        add hl,hl
        ld de,gfx_lines
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(wm_cx)
        add hl,de
        ld de,(wm_dst)
        ld a,(wm_dir)
        or a
        jr z,.put
        ex de,hl
.put:
        ld bc,(wm_cw)
        ld a,(wm_cfg)
        call bank_put               ; (bank_get is the same)
        ld hl,(wm_dst)
        ld de,(wm_cw)
        add hl,de
        ld (wm_dst),hl
        ld hl,(wm_y)
        inc hl
        ld (wm_y),hl
        pop bc
        dec b
        dec c
        jr nz,.row
        ld a,(wm_pv)
        or a
        call nz,ptr_show
        ret
; the next bank of its copy -> wm_cfg, wm_dst at its start, B = rows
.unit:
        ld hl,(wm_up)
        ld a,(wm_own)
.find:
        inc hl
        cp (hl)
        jr nz,.find
        ld (wm_up),hl
        ld de,wm_units
        or a
        sbc hl,de
        ld de,WM_COPIES + 1
        add hl,de
        ld a,(hl)
        ld (wm_cfg),a
        ld hl,#4000
        ld (wm_dst),hl
        ld a,(wm_rpb)
        ld b,a
        ret

; IX = a record -> wm_r: its frame's x0, y0, x1, y1 (x1, y1 past it)
wm_rect:
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld (wm_r),hl
        call wm_dims                ; BC = w, A = h of the frame
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        add hl,bc
        ld (wm_r + 4),hl
        ld l,(ix + R_Y)
        ld h,(ix + R_Y + 1)
        ld (wm_r + 2),hl
        ld e,a
        ld d,0
        add hl,de
        ld (wm_r + 6),hl
        ret

; wm_r and wm_r2 -> carry: they overlap (each starts before the other
; ends, across and down)
wm_overlap:
        push iy
        ld ix,wm_r
        ld iy,wm_r2
        call .axis
        call c,.down
        pop iy
        ret
.down:
        inc ix
        inc ix
        inc iy
        inc iy
.axis:
        ld l,(ix + 0)               ; r.x0 < r2.x1
        ld h,(ix + 1)
        ld e,(iy + 4)
        ld d,(iy + 5)
        or a
        sbc hl,de
        ret nc
        ld l,(iy + 0)               ; r2.x0 < r.x1
        ld h,(iy + 1)
        ld e,(ix + 4)
        ld d,(ix + 5)
        or a
        sbc hl,de
        ret

; ---- data ------------------------------------------------------------
wm_plus:        db "+", 0
wm_x:           db "X", 0
wm_n:           db 0                ; windows
wm_painting:    db 0                ; 1: one drawn again from behind
wm_need:        db 0                ; 1: all to be drawn again
wm_place:       db 0                ; the next new one's place
wm_pal:         dw 0                ; VOS_PALETTE's routine, while quiet
wm_asked:       db 0                ; 1: X sent ^Q (wm_ask)
wm_redo:        db 0                ; 1: the accessory or switcher over them
wm_ret_view:    db 0                ; app_return before it
wm_units:       ds WM_COPIES_N      ; the copies' banks: whose (a slot)
wm_si:          db 0                ; wm_snap's window
wm_ci:          db 0                ; wm_covered's
wm_dir:         db 0                ; wm_rows: 0 into the copy, 1 back
wm_pv:          db 0                ; the pointer was visible
wm_own:         db 0                ; the slot whose copy
wm_rpb:         db 0                ; rows in a bank
wm_cfg:         db 0                ; the bank
wm_up:          dw 0                ; -> its entry in wm_units
wm_dst:         dw 0                ; the row's place in the bank
wm_y:           dw 0                ; the row's line on the screen
wm_cx:          dw 0                ; wm_geom
wm_cw:          dw 0
wm_cy:          dw 0
wm_back:        dw 0                ; x, y, slot of one out (w = 0)
                db 0, #FF
wm_act:         db 0
wm_i:           db 0
wm_wh:          ds 4
wm_cur:         dw 0
wm_oxy:         dw 0, 0             ; wm_offsets
wm_nw:          dw 0                ; a new size (wm_resize)
wm_nh:          dw 0
wm_ret:         dw 0
wm_bg_on:       db 0                ; 1: one behind draws (wm_bg)
wm_bg_view:       ds WM_BG_VW         ; the front one's vw_on ... vw_y1
wm_quiet:       db 0                ; 1: wm_view writes no w, h back
wm_bg_txt:      ds 9                ; its txt_fg ... txt_style
wm_r:           ds 8
wm_r2:          ds 8                ; where the program wants its w, h
wm_text:        ds 9
wm_ctx:         ds 25
wm_tmp:         ds WM_REC
wm_recs:        ds WM_MAX * WM_REC

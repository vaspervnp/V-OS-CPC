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
; x + WB, y + WT.
; =====================================================================

WM_MAX          equ 6
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
F_FULL          equ 1

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
        ld a,(wm_painting)          ; drawn again from behind: its view
        or a
        jr z,.front
        ld ix,(wm_cur)
        jp wm_view
.front:
        call wm_prune
        call wm_find
        jr nc,.found
        call wm_new
        ret c
        jr .top
.found:
        call wm_raise
.top:
        call wm_top
        bit 0,(ix + R_FLAGS)
        jr z,.window
        ld a,2                      ; full screen: no view, no frame
        ld (wm_on),a
        xor a
        ld (vw_on),a
        ret
.window:
        ld a,1
        ld (wm_on),a
        ld a,(wm_was)               ; the windows were on the screen?
        dec a
        ld hl,wm_need
        or (hl)
        ld (hl),0
        jr z,.frames
        call wm_save                ; no: the desk and those behind
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
; IX = a record: the view on its inside -> carry clear
wm_view:
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
        ld a,1
        ld (vw_a),a
        call vw_set
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
.pointer:
        ld a,(wm_on)
        dec a
        jr nz,.no                   ; full screen: as it is
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
        call wm_top                 ; in the window in front: from it
        call wm_inside
        jr c,.outside
        ld (ev_cur + 4),hl
        ld (ev_cur + 6),de
        or a
        ret
.outside:
        ld a,(ev_cur)
        cp EV_PTR_DOWN
        jr nz,.taken
        call wm_hit                 ; on a window: which, from the front
        jr c,.taken
        call wm_is_top
        jr nz,.other
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
        call wm_close
        jr .taken
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
        ld hl,(ev_cur + 4)          ; x - frame x < w + 2 WB ?
        ld e,(ix + R_X)
        ld d,(ix + R_X + 1)
        or a
        sbc hl,de
        jr c,.next
        push hl
        ld l,(ix + R_W)
        ld h,(ix + R_W + 1)
        ld de,2 * WB
        add hl,de
        ex de,hl
        pop hl
        sbc hl,de
        jr nc,.next
        ld hl,(ev_cur + 6)          ; y - frame y < WT + h + WB ?
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        or a
        sbc hl,de
        jr c,.next
        ld de,WT + WB
        sbc hl,de
        jr c,.found
        ld a,h
        or a
        jr nz,.next
        ld a,l
        cp (ix + R_H)
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
        call wm_dims                ; BC = w, A = h of the frame
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        call ui_drag
        ret nc
        ld (ix + R_X),l
        ld (ix + R_X + 1),h
        ld (ix + R_Y),e
        ld (ix + R_Y + 1),d
        ; fall through
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
        jp wm_restore

; IX = the window in front: full screen, or a window again; its program
; goes on so (VX_WINDOW sees F_FULL)
wm_full:
        ld a,(ix + R_FLAGS)
        xor F_FULL
        ld (ix + R_FLAGS),a
        jr wm_wake

; IX = the window in front: its program ends, as with VOS_EXIT; the
; next one comes to the front, or the view that started it
wm_close:
        call api_end
        call wm_top
        call wm_drop
        ld a,(wm_n)
        or a
        ld a,(app_return)
        jp z,view_request
        call wm_top
        ; fall through
; IX = a window: its program to the front (as F6 does: kernel/view.asm,
; app_run), once this event is handled
wm_wake:
        ld a,1                      ; what it covered: all drawn again
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
        ld a,VIEW_APP
        jp view_request

; ---------------------------------------------------------------------
; Drawing
; ---------------------------------------------------------------------

; the desk under the menu bar
wm_desk:
        ld a,UIP_DESK
        ld (ui_fill_pen),a
        ld hl,0
        ld de,UI_BAR_H
        ld bc,(gfx_width)
        ld a,GFX_H - UI_BAR_H
        jp ui_rect

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
; program (init with A = 2), as the kernel's program
wm_one:
        call wm_frame
        ld a,(ix + R_SLOT)
        ld (app_slot),a
        ld l,(ix + R_PAGE)
        ld h,(ix + R_CFG)
        ld (vw_page),hl
        ld (wm_cur),ix
        ld a,1
        ld (wm_painting),a
        ld a,2
        push ix
        call prog_call
        pop ix
        xor a
        ld (wm_painting),a
        ret

; IX = a window, A = 1 in front: its frame (the title in the selection's
; colours in front)
wm_frame:
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
        call wm_dims                ; on the screen: VOS_FIT
        ld l,(ix + R_X)
        ld h,(ix + R_X + 1)
        ld e,(ix + R_Y)
        ld d,(ix + R_Y + 1)
        call ui_fit
        ld (ix + R_X),l
        ld (ix + R_X + 1),h
        ld (ix + R_Y),e
        ld (ix + R_Y + 1),d
        or a
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

; ---- data ------------------------------------------------------------
wm_plus:        db "+", 0
wm_x:           db "X", 0
wm_n:           db 0                ; windows
wm_painting:    db 0                ; 1: one drawn again from behind
wm_need:        db 0                ; 1: all to be drawn again
wm_place:       db 0                ; the next new one's place
wm_act:         db 0
wm_i:           db 0
wm_wh:          ds 4
wm_cur:         dw 0
wm_text:        ds 9
wm_ctx:         ds 25
wm_tmp:         ds WM_REC
wm_recs:        ds WM_MAX * WM_REC

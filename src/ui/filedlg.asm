; =====================================================================
; filedlg.asm - modal file list
;
; file_pick - A = title MSG_*, after fs_catalog filled FS_CAT.
; Returns A = the chosen file (index in FS_CAT), carry if cancelled.
;
; Up to FP_MAX_ROWS files are shown (FP_SPLIT_ROWS with a mixed screen); the list scrolls with the selection.
; UP/DOWN move, RETURN/ENTER/SPACE choose, ESC cancels, a click on a
; file chooses it. The last line shows the free space on the disc.
; Rows read "NAME    .EXT  nnnK". Uses the save-under buffer, like
; menus and dialogs.
; =====================================================================

FP_MAX_ROWS         equ 10
FP_SPLIT_ROWS   equ 8               ; in a mixed screen's mode 0 band
FP_CHARS        equ 22              ; box width in characters

file_pick:
        ld (fp_title),a
        ld a,(fc_count)
        ld (fp_count),a
        ld a,(ptr_keys_on)
        ld (fp_saved_keys),a
        xor a
        ld (ptr_keys_on),a
        ld (fp_sel),a
        ld (fp_top),a
        ld a,(split_on)             ; rows on screen
        or a
        ld c,FP_MAX_ROWS
        jr z,.max
        ld c,FP_SPLIT_ROWS
.max:
        ld a,(fp_count)
        cp c
        jr c,.rows
        ld a,c
.rows:
        ld (fp_rows),a
        ld b,a                      ; height = 12 + 4 + rows*10 + 4 + 10 + 4
        ld a,34
.height:
        add a,10
        djnz .height
        ld (fp_h),a
        ld hl,FP_CHARS * 8
        ld (fp_w),hl
        call ui_centre
        ld hl,(fp_y)
        ld de,16                    ; first row
        add hl,de
        ld (fp_rows_y),hl

        call ui_save_window
        ld a,(fp_title)
        call ui_window
        call fp_draw_rows
        call fp_draw_free

.loop:
        call wait_frame
.events:
        call ev_get
        jr z,.idle
        call fp_event               ; A: 0 none, 1 chosen, 2 cancelled
        or a
        jr z,.events
        jr .done
.idle:
        call ptr_update
        jr .loop
.done:
        ld (fp_result),a
        call ui_restore
        ld a,(fp_saved_keys)
        ld (ptr_keys_on),a
        ld a,(fp_result)
        cp 2
        ccf                         ; carry if cancelled
        ld a,(fp_sel)
        ret

; all visible rows
fp_draw_rows:
        xor a
.row:
        ld hl,fp_rows
        cp (hl)
        ret nc
        push af
        call fp_draw_row
        pop af
        inc a
        jr .row

; A = row on screen
fp_draw_row:
        ld (fp_r),a
        ld b,a                      ; y = rows_y + row * 10
        ld hl,(fp_rows_y)
        ld de,10
        inc b
        jr .first
.add:
        add hl,de
.first:
        djnz .add
        ld (fp_ry),hl
        ld a,(fp_top)               ; file = top + row
        ld hl,fp_r
        add a,(hl)
        ld (fp_i),a
        ld hl,fp_sel
        cp (hl)
        ld a,UIP_BAR
        ld bc,UIP_TEXT * 256 + UIP_BAR
        jr nz,.colours
        ld a,UIP_SEL
        ld bc,UIP_SELTEXT * 256 + UIP_SEL
.colours:
        ld (ui_fill_pen),a
        ld (fp_colours),bc
        ld hl,(fp_x)
        ld de,4
        add hl,de
        ld de,(fp_ry)
        ld bc,(fp_w)
        push hl
        ld hl,-8
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        ld a,10
        call ui_rect
        ld a,(fp_colours + 1)
        ld bc,(fp_colours)
        call ui_colours
        ld a,(fp_i)                 ; text: name, extension, size
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FS_CAT
        add hl,de
        ld de,fp_line
        call util_cat_row
        ld hl,(fp_x)
        ld de,8
        add hl,de
        ld de,(fp_ry)
        inc de
        ld bc,fp_line
        jp txt_print

; "FREE nnnK" on the last line
fp_draw_free:
        ld de,fp_line
        ld a,MSG_FREE
        call util_msg
        ld a," "
        ld (de),a
        inc de
        push de
        call fs_free_k
        pop de
        ld l,a
        ld h,0
        call util_dec
        ld a,"K"
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld a,UIP_TEXT
        ld c,UIP_BAR
        call ui_colours
        ld hl,(fp_y)
        ld a,(fp_h)
        sub 14
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        ld hl,(fp_x)
        ld bc,8
        add hl,bc
        ld bc,fp_line
        jp txt_print

; ev_cur -> A = 0 nothing, 1 chosen, 2 cancelled
fp_event:
        ld a,(ev_cur)
        cp EV_LANG
        jr nz,.not_lang
        call ui_draw_indicator
        jr .none
.not_lang:
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
        ld hl,(ev_cur + 4)          ; inside the box?
        ld de,(fp_x)
        or a
        sbc hl,de
        jr c,.none
        ld de,(fp_w)
        or a
        sbc hl,de
        jr nc,.none
        ld hl,(ev_cur + 6)          ; which row?
        ld de,(fp_rows_y)
        or a
        sbc hl,de
        jr c,.none
        ld a,h
        or a
        jr nz,.none
        ld a,l
        ld c,0
.row:
        sub 10
        jr c,.found
        inc c
        jr .row
.found:
        ld a,c
        ld hl,fp_rows
        cp (hl)
        jr nc,.none
        ld hl,fp_top
        add a,(hl)
        ld (fp_sel),a
        ld a,1
        ret
.key:
        ld a,(ev_cur + 1)
        cp KEY_ESC
        jr z,.cancel
        cp KEY_RETURN
        jr z,.choose
        cp KEY_ENTER
        jr z,.choose
        cp KEY_UP
        jr z,.up
        cp KEY_DOWN
        jr z,.down
        ld a,(ev_cur + 2)
        cp " "
        jr z,.choose
        jr .none
.cancel:
        ld a,2
        ret
.choose:
        ld a,1
        ret
.up:
        ld a,(fp_sel)
        or a
        jr z,.none
        dec a
        jr .move
.down:
        ld a,(fp_sel)
        inc a
        ld hl,fp_count
        cp (hl)
        jr nc,.none
.move:
        ld hl,fp_sel
        ld b,(hl)
        ld (hl),a
        ld a,(fp_top)               ; scroll so the selection shows
        ld c,a
        ld a,(fp_sel)
        cp c
        jr nc,.not_above
        ld (fp_top),a
        jr .redraw
.not_above:
        ld hl,fp_rows
        sub (hl)
        jr c,.no_scroll
        inc a                       ; sel - rows + 1 > top ?
        cp c
        jr c,.no_scroll
        jr z,.no_scroll
        ld (fp_top),a
.redraw:
        call fp_draw_rows
        jp .none
.no_scroll:
        ld a,b                      ; old and new row only
        sub c
        call fp_draw_row
        ld a,(fp_top)
        ld c,a
        ld a,(fp_sel)
        sub c
        call fp_draw_row
        jp .none

; ---- state ----------------------------------------------------------
fp_title:       db 0
fp_count:       db 0
fp_sel:         db 0
fp_top:         db 0
fp_rows:        db 0
fp_r:           db 0
fp_i:           db 0
fp_result:      db 0
fp_saved_keys:  db 0
fp_x            equ uw_x
fp_y            equ uw_y
fp_w            equ uw_w
fp_h            equ uw_h
fp_rows_y:      dw 0
fp_ry:          dw 0
fp_colours:     dw 0                ; background, foreground
fp_line:        ds 24

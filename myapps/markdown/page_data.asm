; page_data.asm - the variables of page.asm
pv_top:         dw 0                ; the page line at the top
pv_y:           dw 0                ; the page line being made
pv_more:        db 0                ; 1: more lines below the screen
pv_sp:          dw 0
pv_fence:       db 0                ; 1: in a ``` code block
pv_join:        db 0                ; the line: 1 a paragraph, 2 a quote
ck_n:           db 0                ; checkpoints: in ck_tab
ck_next:        dw 0                ; the page line for the next one
ck_best:        dw 0
ck_tab:         ds CK_MAX * 6       ; dw text, dw pv_y, db fence, db li
pv_n:           db 0                ; characters in the page line
pv_ind:         db 0                ; its indent
pv_st:          db 0                ; ST_*: styles open
pv_base:        db 0                ; the line's attributes
pv_pad:         db 0                ; the attributes after its end
pv_last:        db 0                ; the character put before
pv_cnt:         db 0
pv_i:           db 0
pv_dy:          dw 0
pv_end:         db 0
pv_rect:        dw 0, 0, 0, 8         ; x, y, w, h, pen
                db BG
pv_ch:          ds COLS             ; the page line: characters,
pv_at:          ds COLS             ; then their attributes
pv_tmp:         ds COLS * 2
        IFDEF PV_LINKS
pv_li:          db 0                ; the links counted so far
pv_sel:         db #FF              ; the chosen one (#FF: none)
pv_only:        db #FF              ; draw only this row (#FF: all)
lk_y:           dw 0                ; the page line of the link open
lk_n:           db 0
lk_tab:         ds LK_MAX * 5
        ENDIF

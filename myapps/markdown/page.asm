; =====================================================================
; page.asm - the page of a Markdown text: MARKDOWN's preview and
; READER's pages (included by both; page_data.asm has its variables)
;
; pv_render draws the page lines pv_top.. of text..tend on the screen
; rows 0..ROWS-1 (row_y; pv_rows: fewer), until the screen is full. The program gives:
; text, tend, at_eol, same, row_y, line (COLS2 + 1 bytes), ROWS, BG,
; INK, CUR_PEN, and the page's width: ncols (db, its columns, up to
; COLS2) and xoff (dw, the x of its first one): 48 from 0 in mode 1, 80
; from PAGE_X in mode 2 (the page). Call pv_new when they change. Markdown: # ## ### headings, **bold** __bold__,
; *italic* _italic_, `code`, ``` blocks, - * + and 1. lists, > quotes,
; --- lines, [links](url) underlined, \ before a mark. Lines that follow
; each other make one paragraph (two spaces at the end break it), as do a
; list item's and a quote's; long page lines wrap at a space.
; Scrolling: pv_render starts from the last checkpoint above pv_top
; (ck_tab: where a text line starts, every CK_STEP page lines or so), not
; from the text's start. pv_new forgets them: call it for a new text.
; With PV_LINKS (READER): the links are counted (pv_li), the one numbered
; pv_sel is drawn inverted, and those on the screen go into lk_tab (db
; number, row; dw -> address; db its length). pv_only = a row: only that
; row is drawn (#FF: all).
; =====================================================================

; the page: a cell's pen (bits 0-1), background (2-3) and style (4-6)
A_NORM          equ INK + BG * 4
A_MARK          equ CUR_PEN + BG * 4    ; list marks, quotes, lines
A_H1            equ CUR_PEN + BG * 4 + VOS_BOLD + VOS_UNDERLINE
A_H2            equ CUR_PEN + BG * 4 + VOS_BOLD
A_H3            equ INK + BG * 4 + VOS_BOLD
A_CODE          equ CUR_PEN             ; yellow on black
ST_BOLD         equ 1               ; pv_st: the styles open in a line
ST_ITALIC       equ 2
ST_CODE         equ 4
ST_LINK         equ 8
LK_MAX          equ 16              ; links kept from one screen
CK_MAX          equ 64              ; checkpoints (ck_tab)
CK_STEP         equ 8               ; page lines between them, at least
PV_W            equ COLS2           ; pv_ch: its attributes PV_W on

; the page's lines pv_top.. on the screen: the text from its start,
; line by line, until the screen is full (then pv_more = 1)
pv_render:
        ld (pv_sp),sp               ; pv_emit stops here when full
        xor a
        ld (pv_more),a
        IFDEF PV_LINKS
        ld (lk_n),a
        ENDIF
        call ck_find
.line:
        ld de,(tend)
        call same
        jr z,.end
        call ck_add
        call pv_line
        jr .line
.end:
        IFDEF PV_LINKS
        ld a,(pv_only)              ; one row only: not the rest
        inc a
        ret nz
        ENDIF
        ld hl,(pv_y)                ; the rows left: empty
        ld de,(pv_top)
        or a
        sbc hl,de
        ld a,l
        jr nc,.rest
        xor a
.rest:
        cp ROWS
pv_rows_at0 equ $ - 1
        ret nc
        push af
        xor a
        ld (pv_n),a
        ld a,A_NORM
        ld (pv_pad),a
        call pv_fill
        pop af
        push af
        call pv_draw
        pop af
        inc a
        jr .rest

; HL -> a line of the text: its line(s) on the page -> HL -> the next
pv_line:
        xor a
        ld (pv_join),a
        ld (pv_ind),a
        ld (pv_n),a
        ld (pv_st),a
        ld a," "
        ld (pv_last),a
        ld a,A_NORM
        ld (pv_base),a
        ld (pv_pad),a
        push hl                     ; ``` : a code block starts or ends
        ld b,3
.fence:
        call at_eol
        jr z,.no_fence
        ld a,(hl)
        cp "`"
        jr nz,.no_fence
        inc hl
        djnz .fence
        pop hl
        ld a,(pv_fence)
        xor 1
        ld (pv_fence),a
        jp pv_skip
.no_fence:
        pop hl
        ld a,(pv_fence)
        or a
        jr z,.lead
        ld a,A_CODE                 ; in a code block: as it is
        ld (pv_pad),a
.code:
        call at_eol
        jp z,pv_done
        ld a,(hl)
        ld c,A_CODE
        call pv_put
        inc hl
        jr .code
.lead:                              ; spaces at the start: kept
        call at_eol
        jp z,pv_done
        ld a,(hl)
        cp " "
        jr nz,.mark
        ld c,A_NORM
        call pv_put
        inc hl
        jr .lead
.mark:
        ld a,(pv_n)
        ld (pv_ind),a
        ld a,1                      ; a paragraph, unless it is not
        ld (pv_join),a
        ld a,(hl)
        cp "#"
        jr z,.head
        cp ">"
        jp z,.quote
        cp "-"
        jr z,.dash
        cp "*"
        jr z,.dash
        cp "_"
        jr z,.rule
        cp "+"
        jp z,.item
        cp "0"
        jp c,pv_inline
        cp "9" + 1
        jp c,.number
        jp pv_inline
.dash:
        call pv_is_rule
        jr z,.ruled
        jp .item
.rule:
        call pv_is_rule
        jp nz,pv_inline
.ruled:
        xor a
        ld (pv_join),a
        ld a,(ncols)                ; ---: a line across
        ld b,a
        ld a,(pv_n)
        ld c,a
        ld a,b
        sub c
        ld b,a
.dashes:
        push bc
        ld a,"-"
        ld c,A_MARK
        call pv_put
        pop bc
        djnz .dashes
        jp pv_done
.head:                              ; #, ##, ### and a space
        push hl
        ld b,0
.hashes:
        ld a,(hl)
        cp "#"
        jr nz,.hashed
        inc b
        inc hl
        call at_eol
        jr nz,.hashes
.hashed:
        call at_eol
        jr z,.not_head
        ld a,(hl)
        cp " "
        jr z,.heading
.not_head:
        pop hl                      ; not a heading
        jp pv_inline
.heading:
        pop af
        xor a                       ; a heading is one line
        ld (pv_join),a
        inc hl
        ld a,b
        ld c,A_H1
        dec a
        jr z,.level
        ld c,A_H2
        dec a
        jr z,.level
        ld c,A_H3
.level:
        ld a,c
        ld (pv_base),a
        jp pv_inline
.quote:                             ; > : a bar, the text in italic
        ld a,2                      ; it goes on with ">"
        ld (pv_join),a
        inc hl
        call at_eol
        jr z,.bar
        ld a,(hl)
        cp " "
        jr nz,.bar
        inc hl
.bar:
        ld a,"|"
        ld c,A_MARK
        call pv_put
        ld a," "
        ld c,A_NORM
        call pv_put
        ld a,A_NORM + VOS_ITALIC
        ld (pv_base),a
        jr .indent
.item:                              ; - * + and a space: "-" in yellow
        push hl
        inc hl
        call at_eol
        jr z,.not_item
        ld a,(hl)
        cp " "
        jr nz,.not_item
        pop af
        inc hl
        ld a,"-"
        ld c,A_MARK
        call pv_put
        ld a," "
        ld c,A_NORM
        call pv_put
        jr .indent
.not_item:
        pop hl
        jp pv_inline
.number:                            ; 12. or 12) and a space
        push hl
.digits:
        inc hl
        call at_eol
        jr z,.not_item
        ld a,(hl)
        cp "0"
        jr c,.dot
        cp "9" + 1
        jr c,.digits
.dot:
        cp "."
        jr z,.dotted
        cp ")"
        jr nz,.not_item
.dotted:
        inc hl
        call at_eol
        jr z,.not_item
        ld a,(hl)
        cp " "
        jr nz,.not_item
        ex (sp),hl                  ; HL -> the first digit
.put_number:
        ld a,(hl)
        cp " "
        jr z,.numbered
        ld c,A_MARK
        call pv_put
        inc hl
        jr .put_number
.numbered:
        pop hl
        ld c,A_NORM
        call pv_put
        inc hl
.indent:
        ld a,(pv_n)                 ; wrapped lines start under the text
        ld (pv_ind),a
        ; fall through

; the rest of the line, with **, *, __, _, `, [ ] ( ) and \ at work
pv_inline:
        call at_eol
        jp z,pv_done
        ld a,(pv_st)
        and ST_CODE
        ld a,(hl)
        jr z,.marks
        cp "`"
        jr z,.tick
        ld c,A_CODE
        jr .put
.marks:
        cp "`"
        jr z,.tick
        cp "\\"
        jr z,.escape
        cp "*"
        jr z,.emphasis
        cp "_"
        jr z,.underscore
        cp "["
        jr z,.link
        cp "]"
        jr z,.link_end
.plain:
        call pv_attr
        ld a,(hl)
.put:
        call pv_put
        inc hl
        jr pv_inline
.tick:
        ld a,ST_CODE
.flip:
        inc hl
.flip_here:
        ld c,a
        ld a,(pv_st)
        xor c
        ld (pv_st),a
        jr pv_inline
.escape:
        inc hl
        call at_eol
        jp z,pv_done
        jr .plain
.underscore:                        ; inside a word: an underscore
        ld a,(pv_last)
        call pv_alnum
        jr nc,.emphasis
        push hl
        inc hl
        call at_eol
        ld a," "
        jr z,.next
        ld a,(hl)
.next:
        pop hl
        call pv_alnum
        jr c,.plain
.emphasis:                          ; ** bold, * italic (the same mark)
        ld b,(hl)
        inc hl
        call at_eol
        jr z,.single
        ld a,(hl)
        cp b
        jr nz,.single
        ld a,ST_BOLD
        jr .flip
.single:
        ld a,(pv_st)                ; "a * b": a star
        and ST_ITALIC
        jr nz,.italic
        call at_eol
        jr z,.star
        ld a,(hl)
        cp " "
        jr nz,.italic
.star:
        dec hl
        jr .plain
.italic:
        ld a,ST_ITALIC
        jr .flip_here
.link:
        IFDEF PV_LINKS
        push hl
        ld hl,(pv_y)                ; its page line
        ld (lk_y),hl
        pop hl
        ENDIF
        ld a,ST_LINK
        jr .flip
.link_end:
        ld a,(pv_st)
        and ST_LINK
        jr z,.plain
        ld a,ST_LINK
        ld c,a
        ld a,(pv_st)
        xor c
        ld (pv_st),a
        IFDEF PV_LINKS
        ld a,(pv_li)                ; the next link
        inc a
        ld (pv_li),a
        ENDIF
        inc hl                      ; (url): left out
        call at_eol
        jr z,pv_done
        ld a,(hl)
        cp "("
        jp nz,pv_inline
        IFDEF PV_LINKS
        inc hl
        call lk_add
        dec hl
        ENDIF
.url:
        inc hl
        call at_eol
        jr z,pv_done
        ld a,(hl)
        cp ")"
        jr nz,.url
        inc hl
        jp pv_inline

; the end of a line: on with the next one in a paragraph, or the last
; page line out and HL past the LF
pv_done:
        ld a,(pv_join)
        or a
        jr z,.out
        call pv_next
        jr c,.out
        ld a,(pv_last)              ; a space between the two
        cp " "
        jp z,pv_inline
        call pv_attr
        ld a," "
        call pv_put
        jp pv_inline
.out:
        push hl
        call pv_emit
        pop hl
        ; fall through
pv_skip:
        call at_eol
        jr z,.eol
        inc hl
        jr pv_skip
.eol:
        ld de,(tend)
        call same
        ret z
        inc hl
        ret

; HL at the end of a paragraph's line: NC and HL -> the text that goes
; on in it from the next line. Carry and HL kept: the next line is empty
; or starts something else, or this one ends in two spaces (a break).
pv_next:
        push hl
        call .look
        jr c,.no
        pop af
        or a
        ret
.no:
        pop hl
        scf
        ret
.look:
        ld de,(tend)
        call same
        scf
        ret z
        dec hl                      ; two spaces before the end?
        ld a,(hl)
        dec hl
        cp " "
        jr nz,.soft
        ld a,(hl)
        cp " "
        scf
        ret z
.soft:
        inc hl                      ; the next line
        inc hl
        inc hl
.spaces:
        call at_eol
        scf
        ret z
        ld a,(hl)
        cp " "
        jr nz,.first
        inc hl
        jr .spaces
.first:
        ld a,(pv_join)
        cp 2
        jr nz,pv_starts
        ld a,(hl)                   ; a quote goes on after "> "
        cp ">"
        scf
        ret nz
        inc hl
        call at_eol
        scf
        ret z
        ld a,(hl)
        cp " "
        jr nz,pv_starts
        inc hl
        call at_eol
        scf
        ret z
        ; fall through

; HL -> the first character of a line: carry if it starts a heading, a
; quote, a list item, a line or a code block. HL kept.
pv_starts:
        ld a,(hl)
        cp "#"
        jr z,.yes
        cp ">"
        jr z,.yes
        cp "`"
        jr z,.fence
        cp "-"
        jr z,.item
        cp "*"
        jr z,.item
        cp "+"
        jr z,.item
        cp "_"
        jr z,.rule
        cp "0"
        jr c,.no
        cp "9" + 1
        jr c,.number
.no:
        or a
        ret
.yes:
        scf
        ret
.fence:
        push hl
        inc hl
        ld a,(hl)
        cp "`"
        jr nz,.fenced
        inc hl
        ld a,(hl)
        cp "`"
.fenced:
        pop hl
        jr z,.yes
        jr .no
.item:
        push hl
        inc hl
        ld a,(hl)
        cp " "
        pop hl
        jr z,.yes
.rule:
        call pv_is_rule
        jr z,.yes
        jr .no
.number:
        push hl
.digit:
        inc hl
        ld a,(hl)
        cp "0"
        jr c,.dot
        cp "9" + 1
        jr c,.digit
.dot:
        cp "."
        jr z,.dotted
        cp ")"
        jr nz,.not
.dotted:
        inc hl
        ld a,(hl)
        cp " "
.not:
        pop hl
        jr z,.yes
        jr .no

; a new text: no checkpoints
pv_new:
        xor a
        ld (ck_n),a
        ret

; A = the rows on the screen (ROWS, or fewer in a window)
pv_rows:
        ld (pv_rows_at0),a
        ld (pv_rows_at1),a
        IFDEF PV_LINKS
        ld (pv_rows_at2),a
        ENDIF
        ret

; the last checkpoint at or above pv_top -> HL -> its text line, and
; pv_y, pv_fence (and pv_li) as they were there
ck_find:
        ld a,(ck_n)
        or a
        jr nz,.search
        ld hl,text                  ; the first: the text's start
        ld (ck_tab),hl
        ld hl,0
        ld (ck_tab + 2),hl
        ld (ck_tab + 4),hl
        ld hl,CK_STEP
        ld (ck_next),hl
        inc a
        ld (ck_n),a
.search:
        ld b,a
        ld hl,ck_tab
        ld (ck_best),hl
.next:
        push hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(pv_top)
        or a
        sbc hl,de
        pop hl
        jr c,.found                 ; below pv_top
        ld (ck_best),hl
        ld de,6
        add hl,de
        djnz .next
.found:
        ld hl,(ck_best)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (pv_y),de
        ld a,(hl)
        inc hl
        ld (pv_fence),a
        IFDEF PV_LINKS
        ld a,(hl)
        ld (pv_li),a
        ENDIF
        pop hl
        ret

; HL -> a text line about to be made: a checkpoint, if CK_STEP page
; lines went by since the last one. HL kept.
ck_add:
        ld a,(ck_n)
        cp CK_MAX
        ret nc
        push hl
        ld hl,(pv_y)
        ld de,(ck_next)
        or a
        sbc hl,de
        jr c,.not
        ld l,a                      ; ck_tab + 6 * ck_n
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,ck_tab
        add hl,de
        pop de
        push de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(pv_y)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(pv_fence)
        ld (hl),a
        inc hl
        IFDEF PV_LINKS
        ld a,(pv_li)
        ELSE
        xor a
        ENDIF
        ld (hl),a
        ld hl,ck_n
        inc (hl)
        ld hl,CK_STEP
        add hl,de
        ld (ck_next),hl
.not:
        pop hl
        ret

; HL -> -, * or _ : Z if the line is 3 or more of it (and spaces)
pv_is_rule:
        push hl
        ld c,(hl)
        ld b,0
.char:
        call at_eol
        jr z,.end
        ld a,(hl)
        inc hl
        cp " "
        jr z,.char
        cp c
        jr nz,.no
        inc b
        jr .char
.end:
        ld a,b
        cp 3
        jr c,.no
        xor a
        pop hl
        ret
.no:
        or 1
        pop hl
        ret

; A = character -> carry if a letter or a digit
pv_alnum:
        cp "0"
        ccf
        ret nc
        cp "9" + 1
        ret c
        cp "A"
        ccf
        ret nc
        cp "Z" + 1
        ret c
        cp "a"
        ccf
        ret nc
        cp "z" + 1
        ret c
        cp 128                      ; the language's letters
        ccf
        ret

; -> C = the cell's attributes for the styles open now
pv_attr:
        ld a,(pv_base)
        ld c,a
        ld a,(pv_st)
        rrca                        ; ST_BOLD
        jr nc,.italic
        set 4,c
.italic:
        rrca                        ; ST_ITALIC
        jr nc,.code
        ld b,a
        ld a,c
        xor VOS_ITALIC
        ld c,a
        ld a,b
.code:
        rrca                        ; ST_CODE (handled before)
        rrca                        ; ST_LINK: underlined
        ret nc
        set 6,c
        IFDEF PV_LINKS
        ld a,(pv_sel)               ; the chosen one: inverted
        ld b,a
        ld a,(pv_li)
        cp b
        ret nz
        ld a,c
        and #70
        or BG + INK * 4
        ld c,a
        ENDIF
        ret

; A = character, C = its attributes: into the page line, which wraps at
; the last space when it is full. HL kept.
pv_put:
        push hl
        push af
        push bc
        ld hl,ncols
        ld a,(pv_n)
        cp (hl)
        call nc,pv_wrap
        pop bc
        pop af
        ld (pv_last),a
        ld hl,pv_n
        ld e,(hl)
        inc (hl)
        ld d,0
        ld hl,pv_ch
        add hl,de
        ld (hl),a
        ld de,PV_W
        add hl,de
        ld (hl),c
        pop hl
        ret

; the page line is full: out up to its last space, the rest on the next
; line (none: all of it out)
pv_wrap:
        ld a,(ncols)
        dec a
        ld e,a
        ld d,0
        ld hl,pv_ch
        add hl,de
        ld b,a
.find:
        ld a,(pv_ind)
        cp b
        jp nc,pv_emit
        ld a,(hl)
        cp " "
        jr z,.space
        dec hl
        dec b
        jr .find
.space:
        ld a,b
        ld (pv_n),a                 ; the line ends before the space
        ld a,(ncols)
        dec a
        sub b
        ld (pv_cnt),a
        or a
        jp z,pv_emit
        inc hl                      ; the rest: characters, attributes
        push hl
        ld de,pv_tmp
        ld c,a
        ld b,0
        ldir
        pop hl
        ld de,PV_W
        add hl,de
        ld de,pv_tmp + PV_W
        ld a,(pv_cnt)
        ld c,a
        ldir
        call pv_emit
        ld a,(pv_n)                 ; at the indent of the next line
        ld e,a
        ld d,0
        ld hl,pv_ch
        add hl,de
        push hl
        ex de,hl
        ld hl,pv_tmp
        ld a,(pv_cnt)
        ld c,a
        ld b,0
        ldir
        pop hl
        ld de,PV_W
        add hl,de
        ex de,hl
        ld hl,pv_tmp + PV_W
        ld a,(pv_cnt)
        ld c,a
        ldir
        ld a,(pv_cnt)
        ld hl,pv_n
        add a,(hl)
        ld (hl),a
        ret

; the page line out: on the screen if it is in view; then a new one,
; with spaces to the indent. A line below the screen stops pv_render.
pv_emit:
        call pv_fill
        ld hl,(pv_y)
        ld de,(pv_top)
        or a
        sbc hl,de
        jr c,.next                  ; above the screen
        ld a,h
        or a
        jr nz,.full
        ld a,l
        cp ROWS
pv_rows_at1 equ $ - 1
        jr nc,.full
        IFDEF PV_LINKS
        ld b,a                      ; only one row?
        ld a,(pv_only)
        cp #FF
        jr z,.draw
        cp b
        jr nz,.next
.draw:
        ld a,b
        ENDIF
        call pv_draw
.next:
        ld hl,(pv_y)
        inc hl
        ld (pv_y),hl
        ld a,(pv_ind)
        ld (pv_n),a
        or a
        ret z
        ld b,a
        ld hl,pv_ch
.indent:
        ld (hl)," "
        push hl
        ld de,PV_W
        add hl,de
        ld (hl),A_NORM
        pop hl
        inc hl
        djnz .indent
        ret
.full:
        ld a,1
        ld (pv_more),a
        ld sp,(pv_sp)
        ret

; the page line from pv_n to the end: spaces in pv_pad
pv_fill:
        ld a,(pv_n)
        ld e,a
        ld d,0
        ld hl,pv_ch
        add hl,de
        ld a,(ncols)
        sub e
        ret z
        ld b,a
.pad:
        ld (hl)," "
        push hl
        ld de,PV_W
        add hl,de
        ld a,(pv_pad)
        ld (hl),a
        pop hl
        inc hl
        djnz .pad
        ret

; A = row: the page line there, in runs of the same attributes; the
; plain spaces at its end as one rectangle (much faster)
pv_draw:
        call row_y
        ld (pv_dy),de
        ld a,(ncols)                ; pv_end: after the last cell to print
        ld b,a
        dec a
        ld e,a
        ld d,0
        ld hl,pv_ch
        add hl,de
.trim:
        ld a,(hl)
        cp " "
        jr nz,.trimmed
        push hl
        ld de,PV_W
        add hl,de
        ld a,(hl)
        pop hl
        cp A_NORM
        jr nz,.trimmed
        dec hl
        djnz .trim
.trimmed:
        ld a,b
        ld (pv_end),a
        xor a
        ld (pv_i),a
.run:
        ld a,(pv_end)
        ld b,a
        ld a,(pv_i)
        cp b
        jr nc,pv_clear
        ld e,a
        ld d,0
        ld hl,pv_ch + PV_W          ; its attributes
        add hl,de
        ld c,(hl)
        ld b,a                      ; B = the column
        ld de,line
.copy:
        ld a,(hl)
        cp c
        jr nz,.copied
        push bc
        ld bc,-PV_W
        add hl,bc
        ld a,(hl)
        ld (de),a
        ld bc,PV_W + 1
        add hl,bc
        pop bc
        inc de
        inc b
        ld a,(pv_end)
        cp b
        jr z,.copied
        jr nc,.copy
.copied:
        xor a
        ld (de),a
        ld a,(pv_i)                 ; x of the run
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(xoff)
        add hl,de
        push hl
        ld a,b
        ld (pv_i),a
        ld a,c                      ; pen and style, background
        and #73
        ld b,a
        ld a,c
        rrca
        rrca
        and 3
        ld c,a
        ld a,b
        call VOS_COLOURS
        pop hl
        ld de,(pv_dy)
        ld bc,line
        call VOS_PRINT
        jr .run

; the page line after pv_end: the background
pv_clear:
        ld hl,ncols
        ld b,a
        ld a,(hl)
        sub b                       ; the columns after it
        ret z
        ret c
        ld l,a                      ; w
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (pv_rect + 4),hl
        ld l,b                      ; x
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(xoff)
        add hl,de
        ld (pv_rect),hl
        ld de,(pv_dy)
        ld (pv_rect + 2),de
        push ix
        ld ix,pv_rect
        call VOS_RECT
        pop ix
        ret


        IFDEF PV_LINKS
; HL -> a link's address (after "("): into lk_tab if its line is on the
; screen. HL kept.
lk_add:
        ld a,(lk_n)
        cp LK_MAX
        ret nc
        push hl
        ld hl,(lk_y)                ; its row
        ld de,(pv_top)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.out
        ld a,l
        cp ROWS
pv_rows_at2 equ $ - 1
        jr nc,.out
        ld c,a
        pop hl
        push hl
        ld b,0                      ; its length: up to ")"
.len:
        call at_eol
        jr z,.counted
        ld a,(hl)
        cp ")"
        jr z,.counted
        inc hl
        inc b
        jr .len
.counted:
        ld a,(lk_n)                 ; lk_tab + 5 * n
        ld e,a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,lk_tab
        add hl,de
        ld a,(pv_li)                ; its number (counted at "]")
        dec a
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),b
        ld hl,lk_n
        inc (hl)
        ex de,hl
        ret
.out:
        pop hl
        ret
        ENDIF

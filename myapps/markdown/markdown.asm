; =====================================================================
; markdown.asm - MARKDOWN, an editor for Markdown (.MD) files on V-OS,
; with a preview page (made with the SDK, from NOTEPAD)
;
; The editor is NOTEPAD's: mode 1, 48 columns, 22 lines, up to 6K of
; text with LF between the lines (CR LF on the disc). ^P shows the page:
; the marks are gone, and the text is in bold, italic or underlined with
; the text styles of VOS_COLOURS (API 13):
;   # ## ###  headings          **bold** __bold__   *italic* _italic_
;   - * +  list items, 1.       `code`, ``` code blocks ```
;   > quotes                    [links](url): the text underlined
;   --- a line                  \* a mark as it is
; Each line of the file starts a line on the page; long ones wrap at a
; space. The arrows scroll the page (left and right: a screen), RETURN
; or ^P go back to the text.
;   MARKDOWN menu: NEW ^N, OPEN ^O (.MD files), SAVE ^S, SAVE AS,
;   PREVIEW ^P, OTHER DRIVE, ABOUT, BACK ^Q
;   make app NAME=markdown    build/MARKDOWN.BIN and build/markdown.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
CUR_PEN         equ 3
COLS            equ 48              ; the text on the screen
ROWS            equ 22
TOP_Y           equ 14
STATUS_Y        equ 238
HINT_Y          equ 249
TEXT_MAX        equ 6144
DATA            equ #4000           ; the file, in the data bank
KEY_CLR         equ 16

CMD_NEW         equ VC_APP + 1               ; menu items: commands
CMD_OPEN        equ VC_APP + 2
CMD_SAVE        equ VC_APP + 3
CMD_SAVE_AS     equ VC_APP + 4
CMD_DRIVE       equ VC_APP + 5
CMD_ABOUT       equ VC_APP + 6
CMD_BACK        equ VC_APP + 7
CMD_PREVIEW     equ VC_APP + 8

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

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start, an empty text; 2: back, the text as it was
init:
        push af
        ld hl,texts
        call VOS_TEXTS
        ld a,1
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        pop af
        cp 2
        jr z,redraw
        ld a,(VOS_SELF)             ; files on its own drive at first
        ld (fdrive),a
        call new_doc
        ; fall through

; everything, again
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        ld a,(pv_mode)
        or a
        jp nz,pv_show
        ld a,T_HINT
        ld hl,0
        ld de,HINT_Y
        ld c,COLS
        call print_label
        call place
        call draw_all
        jp status

new_doc:
        ld hl,text
        ld (tend),hl
        ld (cur),hl
        ld (top),hl
        xor a
        ld (left),a
        ld (modified),a
        ld (pv_mode),a
        ld hl,noname
        ld de,fname
        ld bc,11
        ldir
        ret

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        push hl
        call VOS_UI_EVENT           ; menus and CONTROL+letter first
        pop hl
        or a
        jp nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(pv_mode)
        or a
        jp nz,pv_event
        ld a,(hl)
        cp VE_PTR_DOWN
        jp z,click
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_KEY_REPEAT
        ret nz
.key:
        inc hl
        ld a,(hl)                   ; the key, and its character
        inc hl
        ld c,(hl)
        ld hl,action
        ; fall through

; HL = what to do (with A and C): the cursor off, it, then the cursor
; on the screen again, and what changed drawn
edit:
        push af
        push bc
        push hl
        call cursor_off
        xor a
        ld (redo),a
        pop hl
        pop bc
        pop af
        call jp_hl
        call place
        ld a,(redo)
        cp 2
        jr z,.all
        or a
        jr z,.cursor
        ld hl,(cur_ls)              ; its line
        ld a,(cur_row)
        and a
        call draw_row
.cursor:
        call draw_cursor
        jp status
.all:
        call draw_all
        jp status

jp_hl:
        jp (hl)

; A = key, C = its character
action:
        cp VK_LEFT
        jr z,go_left
        cp VK_RIGHT
        jr z,go_right
        cp VK_UP
        jr z,go_up
        cp VK_DOWN
        jr z,go_down
        cp VK_DEL
        jp z,backspace
        cp KEY_CLR
        jp z,delete
        cp VK_RETURN
        jr z,.line
        cp VK_ENTER
        jr z,.line
        ld a,c
        cp 32
        ret c
        call insert
        ret c
        ld a,1                      ; its line again
        ld (redo),a
        ret
.line:
        ld a,10
        call insert
        jp redo_all

go_left:
        ld hl,(cur)
        ld de,text
        call same
        ret z
        dec hl
        ld (cur),hl
        ret

go_right:
        ld hl,(cur)
        ld de,(tend)
        call same
        ret z
        inc hl
        ld (cur),hl
        ret

; up and down: to the same column, or the end of a shorter line
go_up:
        call column
        ld de,text
        call same
        ret z
        dec hl
        call line_begin
        jr go_col

go_down:
        call column
        call line_next
        ret c
        ; fall through

; HL -> a line, BC = column: the cursor there, or at its end
go_col:
        ld a,b
        or c
        jr z,.set
        call at_eol
        jr z,.set
        inc hl
        dec bc
        jr go_col
.set:
        ld (cur),hl
        ret

; -> HL -> the cursor's line, BC = its column
column:
        ld hl,(cur)
        call line_begin
        push hl
        ex de,hl
        ld hl,(cur)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        ret

; A = character: in at the cursor -> carry if the text is full
insert:
        ld hl,(tend)
        ld de,text + TEXT_MAX
        call same
        jr z,.full
        push af
        ld hl,(tend)                ; the rest one place on
        ld de,(cur)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(tend)
        ld d,h
        ld e,l
        inc hl
        ld (tend),hl
        dec hl
        dec hl
        ld a,b
        or c
        jr z,.put
        lddr
.put:
        pop af
        ld hl,(cur)
        ld (hl),a
        inc hl
        ld (cur),hl
        ld a,1
        ld (modified),a
        or a
        ret
.full:
        xor a                       ; a short low note
        ld hl,600
        ld c,10
        ld b,6
        call VOS_SOUND
        scf
        ret

backspace:
        ld hl,(cur)
        ld de,text
        call same
        ret z
        dec hl
        ld (cur),hl
        ; fall through

; the character at the cursor out
delete:
        ld hl,(cur)
        ld de,(tend)
        call same
        ret z
        ld a,(hl)
        push af
        ex de,hl                    ; the rest one place back
        or a
        sbc hl,de
        dec hl
        ld b,h
        ld c,l
        ld h,d
        ld l,e
        inc hl
        ld a,b
        or c
        jr z,.end
        ldir
.end:
        ld hl,(tend)
        dec hl
        ld (tend),hl
        ld a,1
        ld (modified),a
        ld (redo),a
        pop af
        cp 10                       ; two lines became one
        ret nz
        ; fall through
redo_all:
        ld a,2
        ld (redo),a
        ret

; a click on the text: the cursor there
click:
        inc hl
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)                   ; y > 255: not the text
        or a
        ret nz
        ld a,c
        sub TOP_Y
        ret c
        ld b,-1
.row:
        inc b
        sub 10
        jr nc,.row
        ld a,b
        cp ROWS
        ret nc
        ld (click_r),a
        ex de,hl                    ; column = x / 8
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        cp COLS
        ret nc
        ld (click_c),a
        ld hl,.go
        jp edit
.go:
        ld hl,(top)
        ld a,(click_r)
        or a
        jr z,.line
        ld b,a
.down:
        call line_next
        jr c,.end
        djnz .down
.line:
        ld a,(left)
        ld c,a
        ld a,(click_c)
        add a,c
        ld c,a
        ld a,0
        adc a,0
        ld b,a
        jp go_col
.end:
        ld (cur),hl
        ret

; A = command (the menu)
command:
        cp CMD_PREVIEW
        jp z,pv_toggle
        ld c,a                      ; its own commands leave the page
        sub VC_APP
        jr c,.text
        cp CMD_PREVIEW - VC_APP
        jr nc,.text
        ld a,(pv_mode)
        or a
        jr z,.text
        xor a
        ld (pv_mode),a
        push bc
        call redraw
        pop bc
.text:
        ld a,c
        cp CMD_NEW
        jr nz,.not_new
        call discard_ok
        ret nz
        call new_doc
        jp redraw
.not_new:
        cp CMD_OPEN
        jp z,open
        cp CMD_SAVE
        jp z,save_file
        cp CMD_SAVE_AS
        jp z,save_as
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,fdrive
        ld a,(hl)
        xor 1
        ld (hl),a
        jp status
.not_drive:
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp nz,VOS_COMMAND
        call discard_ok
        ret nz
        jp VOS_EXIT

; changes not saved: ask -> Z to go on
discard_ok:
        ld a,(modified)
        or a
        ret z
        ld hl,dlg_discard
        call VOS_DIALOG
        or a                        ; YES is button 0
        ret

; ---------------------------------------------------------------------
; files
; ---------------------------------------------------------------------
; OPEN: a .MD file of fdrive into the data bank, then here, without CR
; and from the end-of-file mark (26) on
open:
        call discard_ok
        ret nz
        ld a,(fdrive)               ; its .MD files
        or VOS_CAT_EXT
        ld hl,ext_txt
        call VOS_CATALOG
        jp c,VOS_ERROR
        or a
        ret z
        ld (cat),hl
        ld a,T_OPEN_T
        call VOS_FILE_PICK
        ret c
        ld l,a                      ; HL -> its entry (16 bytes)
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cat)
        add hl,de
        ld de,name_tmp
        ld bc,11
        ldir
        ld a,(fdrive)
        or VOS_DATA
        ld hl,name_tmp
        ld de,DATA
        call VOS_LOAD
        jp c,VOS_ERROR
        ld hl,TEXT_MAX
        or a
        sbc hl,bc
        jr nc,.fits
        ld hl,dlg_big
        jp VOS_DIALOG
.fits:
        ld (flen),bc
        ld a,b
        or c
        jr z,.copied
        ld hl,DATA
        ld de,text
        call VOS_BANK_GET
.copied:
        ld hl,text
        ld de,text
        ld bc,(flen)
.char:
        ld a,b
        or c
        jr z,.done
        ld a,(hl)
        inc hl
        dec bc
        cp 26
        jr z,.done
        cp 9                        ; TAB: a space
        jr nz,.tab
        ld a," "
.tab:
        cp 10
        jr z,.keep
        cp 32
        jr c,.char                  ; CR and other codes out
.keep:
        ld (de),a
        inc de
        jr .char
.done:
        ld (tend),de
        ld hl,text
        ld (cur),hl
        ld (top),hl
        xor a
        ld (left),a
        ld (modified),a
        ld hl,name_tmp
        ld de,fname
        ld bc,11
        ldir
        jp redraw

; SAVE: as NONAME it asks for a name first
save_file:
        ld hl,fname
        ld de,noname
        ld b,11
.same:
        ld a,(de)
        cp (hl)
        jr nz,write
        inc hl
        inc de
        djnz .same
        ; fall through

; SAVE AS: a name (8 characters), .MD
save_as:
        ld hl,fname                 ; the name now, to change
        ld de,name_in
        ld b,8
.old:
        ld a,(hl)
        cp " "
        jr z,.asked
        ld (de),a
        inc hl
        inc de
        djnz .old
.asked:
        xor a
        ld (de),a
        ld a,T_NAME_T
        ld hl,name_in
        ld c,8
        call VOS_INPUT
        ret c
        ld hl,name_in
        ld a,(hl)
        or a
        ret z
        ld de,fname
        ld b,8
.name:
        ld a,(hl)
        or a
        jr z,.pad
        cp "."
        jr z,.pad
        cp "a"                      ; capitals
        jr c,.cap
        cp "z" + 1
        jr nc,.cap
        sub 32
.cap:
        ld (de),a
        inc hl
        inc de
        djnz .name
        jr .ext
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.ext:
        ld hl,ext_txt
        ld bc,3
        ldir
        ; fall through

; the text into the data bank, LF as CR LF, 32 bytes at a time, then
; to the disc
write:
        ld hl,DATA
        ld (outp),hl
        ld hl,text
        ld de,sbuf
        ld b,0
.next:
        push de
        ld de,(tend)
        call same
        pop de
        jr z,.end
        ld a,(hl)
        inc hl
        cp 10
        jr nz,.put
        ld a,13
        call .byte
        ld a,10
.put:
        call .byte
        jr .next
.byte:
        ld (de),a
        inc de
        inc b
        ld a,b
        cp 32
        ret c
.flush:
        push hl
        ld c,b
        ld b,0
        ld a,c
        or a
        jr z,.empty
        ld hl,(outp)
        push hl
        add hl,bc
        ld (outp),hl
        pop de
        ld hl,sbuf
        call VOS_BANK_PUT
.empty:
        pop hl
        ld de,sbuf
        ld b,0
        ret
.end:
        call .flush
        ld hl,(outp)
        ld de,DATA
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,(fdrive)
        or VOS_DATA
        ld hl,fname
        call VOS_SAVE
        jp c,VOS_ERROR
        xor a
        ld (modified),a
        jp status

; ---------------------------------------------------------------------
; the text and the screen
; ---------------------------------------------------------------------
; HL, DE -> Z if the same (HL kept)
same:
        or a
        sbc hl,de
        add hl,de
        ret

; HL -> Z at the end of a line (LF, or the end of the text)
at_eol:
        ld a,(tend)
        cp l
        jr nz,.char
        ld a,(tend + 1)
        cp h
        ret z
.char:
        ld a,(hl)
        cp 10
        ret

; HL -> somewhere in a line -> HL -> its start
line_begin:
        push de
        ld de,text
.back:
        call same
        jr z,.done
        dec hl
        ld a,(hl)
        cp 10
        jr nz,.back
        inc hl
.done:
        pop de
        ret

; HL -> somewhere in a line -> HL -> the next line; carry if there is
; none (HL at the end). B kept.
line_next:
        call at_eol
        jr z,.eol
        inc hl
        jr line_next
.eol:
        ld a,(hl)
        push de
        ld de,(tend)
        call same
        pop de
        scf
        ret z
        inc hl
        or a
        ret

; where the cursor is: cur_ls, cur_col, cur_row; top and left move to
; keep it on the screen (then everything is drawn again)
place:
        ld hl,(cur)
        call line_begin
        ld (cur_ls),hl
        ex de,hl
        ld hl,(cur)
        or a
        sbc hl,de
        ld a,h
        or a
        ld a,l
        jr z,.col
        ld a,255
.col:
        ld (cur_col),a
        ld hl,left
        cp (hl)
        jr nc,.right
        and #F0                     ; left of the view
        ld (hl),a
        call redo_all
        jr .row
.right:
        sub (hl)
        cp COLS
        jr c,.row
        ld a,(cur_col)              ; right of it
        sub COLS - 16
        and #F0
        ld (hl),a
        call redo_all
.row:
        ld hl,(cur_ls)              ; above the screen?
        ld de,(top)
        or a
        sbc hl,de
        jr nc,.count
        ld hl,(cur_ls)
        ld (top),hl
        call redo_all
.count:
        ld hl,(top)
        ld de,(cur_ls)
        ld b,0
.line:
        call same
        jr z,.found
        call line_next
        inc b
        jr .line
.found:
        ld a,b
        cp ROWS
        jr c,.ok
        sub ROWS - 1                ; below it: the screen moves up
        ld b,a
        ld hl,(top)
.up:
        call line_next
        djnz .up
        ld (top),hl
        call redo_all
        ld a,ROWS - 1
.ok:
        ld (cur_row),a
        ret

; all the lines from top, and the cursor
draw_all:
        ld hl,(top)
        ld b,0                      ; row
        ld c,0                      ; 1: past the end of the text
.row:
        push bc
        push hl
        ld a,c
        rrca
        ld a,b
        call draw_row
        pop hl
        pop bc
        ld a,c
        or a
        jr nz,.next
        call line_next
        jr nc,.next
        ld c,1
.next:
        inc b
        ld a,b
        cp ROWS
        jr c,.row
        ; fall through

draw_cursor:
        ld a,BG
        ld c,CUR_PEN
        jr cursor_at
cursor_off:
        ld a,INK
        ld c,BG
cursor_at:
        call VOS_COLOURS
        ld hl,(cur)
        call at_eol
        ld a," "
        jr z,.char
        ld a,(hl)
.char:
        push af
        ld a,(cur_row)
        call row_y
        ld a,(left)
        ld b,a
        ld a,(cur_col)
        sub b
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        pop af
        jp VOS_CHAR

; A = row, HL -> its line (carry: none, the row empty)
draw_row:
        push af
        ld de,line
        ld b,COLS
        jr c,.pad
        ld a,(left)
        ld c,a
.skip:
        ld a,c
        or a
        jr z,.copy
        call at_eol
        jr z,.pad
        inc hl
        dec c
        jr .skip
.copy:
        call at_eol
        jr z,.pad
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .copy
        jr .print
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.print:
        xor a
        ld (de),a
        call colours
        pop af
        call row_y
        ld hl,0
        ld bc,line
        jp VOS_PRINT

; A = row -> DE = its y
row_y:
        ld e,a
        add a,a
        add a,a
        add a,e
        add a,a
        add a,TOP_Y
        ld e,a
        ld d,0
        ret

colours:
        ld a,INK
        ld c,BG
        jp VOS_COLOURS

; the last line: A:NAME.MD *, LINE n, COL n
status:
        ld a,(pv_mode)
        or a
        jr z,.text
        ld a,T_PV_STATUS
        ld hl,0
        ld de,STATUS_Y
        ld c,COLS
        jp print_label
.text:
        ld de,line
        ld a,(fdrive)
        add a,"A"
        ld (de),a
        inc de
        ld a,":"
        ld (de),a
        inc de
        ld hl,fname
        ld b,8
.name:
        ld a,(hl)
        cp " "
        jr z,.dot
        ld (de),a
        inc de
        inc hl
        djnz .name
.dot:
        ld a,"."
        ld (de),a
        inc de
        ld hl,fname + 8
        ld bc,3
        ldir
        ld a,(modified)
        or a
        ld a," "
        jr z,.mark
        ld a,"*"
.mark:
        ld (de),a
        inc de
        ld b,8
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
        xor a
        ld (de),a
        ld a,CUR_PEN
        ld c,BG
        call VOS_COLOURS
        ld hl,0
        ld de,STATUS_Y
        ld bc,line
        call VOS_PRINT
        ld a,T_LINE
        ld hl,184
        ld de,STATUS_Y
        ld c,7
        call print_label
        ld hl,text                  ; the line: LFs before the cursor
        ld de,(cur)
        ld bc,1
.count:
        call same
        jr z,.counted
        ld a,(hl)
        inc hl
        cp 10
        jr nz,.count
        inc bc
        jr .count
.counted:
        ld h,b
        ld l,c
        ld de,240
        call number
        ld a,T_COL
        ld hl,288
        ld de,STATUS_Y
        ld c,6
        call print_label
        call column
        inc bc
        ld h,b
        ld l,c
        ld de,336
        ; fall through

; HL = number, DE = x: 5 digits on the last line
number:
        push de
        ld de,line
        ld bc,-10000
        call .digit
        ld bc,-1000
        call .digit
        ld bc,-100
        call .digit
        ld c,-10
        call .digit
        ld c,b
        call .digit
        xor a
        ld (de),a
        ld hl,line                  ; leading zeros as spaces
        ld b,4
.zero:
        ld a,(hl)
        cp "0"
        jr nz,.print
        ld (hl)," "
        inc hl
        djnz .zero
.print:
        call colours
        pop hl
        ld de,STATUS_Y
        ld bc,line
        jp VOS_PRINT
.digit:
        ld a,"0" - 1
.more:
        inc a
        add hl,bc
        jr c,.more
        sbc hl,bc
        ld (de),a
        inc de
        ret

; A = text, HL = x, DE = y, C = width: it, then spaces to the width
print_label:
        push hl
        push de
        push bc
        call VOS_MSG
        pop bc
        ld b,c
        ld de,line
.copy:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .copy
        jr .end
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.end:
        xor a
        ld (de),a
        call colours
        pop de
        pop hl
        ld bc,line
        jp VOS_PRINT

; ---------------------------------------------------------------------
; the page (preview)
; ---------------------------------------------------------------------
; ^P: the page from its top, or back to the text
pv_toggle:
        ld a,(pv_mode)
        xor 1
        ld (pv_mode),a
        ld hl,0
        ld (pv_top),hl
        jp redraw

; the page on the screen, with its hint and status line
pv_show:
        ld a,T_PV_HINT
        ld hl,0
        ld de,HINT_Y
        ld c,COLS
        call print_label
        call pv_render
        jp status

; HL -> the event: keys scroll, RETURN goes back to the text
pv_event:
        ld a,(hl)
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_KEY_REPEAT
        ret nz
.key:
        inc hl
        ld a,(hl)
        cp VK_RETURN
        jr z,pv_toggle
        cp VK_ENTER
        jr z,pv_toggle
        ld hl,(pv_top)
        cp VK_UP
        jr z,.up
        cp VK_LEFT
        jr z,.page_up
        cp VK_DOWN
        jr z,.down
        cp VK_RIGHT
        ret nz
        ld a,(pv_more)              ; a screen on
        or a
        ret z
        ld de,ROWS - 1
        add hl,de
        ld (pv_top),hl
        call pv_render
        ld hl,(pv_y)                ; past the end: its last line on top
        ld de,(pv_top)
        or a
        sbc hl,de
        jr c,.last
        ret nz
.last:
        ld hl,(pv_y)
        dec hl
        jr .set
.down:
        ld a,(pv_more)
        or a
        ret z
        inc hl
        jr .set
.up:
        ld a,h
        or l
        ret z
        dec hl
        jr .set
.page_up:
        ld de,ROWS - 1
        or a
        sbc hl,de
        jr nc,.set
        ld hl,0
.set:
        ld (pv_top),hl
        ; fall through

; the page's lines pv_top.. on the screen: the text from its start,
; line by line, until the screen is full (then pv_more = 1)
pv_render:
        ld (pv_sp),sp               ; pv_emit stops here when full
        ld hl,0
        ld (pv_y),hl
        xor a
        ld (pv_more),a
        ld (pv_fence),a
        ld hl,text
.line:
        ld de,(tend)
        call same
        jr z,.end
        call pv_line
        jr .line
.end:
        ld hl,(pv_y)                ; the rows left: empty
        ld de,(pv_top)
        or a
        sbc hl,de
        ld a,l
        jr nc,.rest
        xor a
.rest:
        cp ROWS
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
        ld b,COLS                   ; ---: a line across
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
        inc hl                      ; (url): left out
        call at_eol
        jr z,pv_done
        ld a,(hl)
        cp "("
        jp nz,pv_inline
.url:
        inc hl
        call at_eol
        jr z,pv_done
        ld a,(hl)
        cp ")"
        jr nz,.url
        inc hl
        jp pv_inline

; the end of a line: the last page line out, HL past the LF
pv_done:
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
        ret

; A = character, C = its attributes: into the page line, which wraps at
; the last space when it is full. HL kept.
pv_put:
        push hl
        push af
        push bc
        ld a,(pv_n)
        cp COLS
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
        ld de,COLS
        add hl,de
        ld (hl),c
        pop hl
        ret

; the page line is full: out up to its last space, the rest on the next
; line (none: all of it out)
pv_wrap:
        ld hl,pv_ch + COLS - 1
        ld b,COLS - 1
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
        ld a,COLS - 1
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
        ld de,COLS
        add hl,de
        ld de,pv_tmp + COLS
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
        ld de,COLS
        add hl,de
        ex de,hl
        ld hl,pv_tmp + COLS
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
        jr nc,.full
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
        ld de,COLS
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
        ld a,COLS
        sub e
        ret z
        ld b,a
.pad:
        ld (hl)," "
        push hl
        ld de,COLS
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
        ld hl,pv_ch + COLS - 1      ; pv_end: after the last cell to print
        ld b,COLS
.trim:
        ld a,(hl)
        cp " "
        jr nz,.trimmed
        push hl
        ld de,COLS
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
        ld hl,pv_ch + COLS          ; its attributes
        add hl,de
        ld c,(hl)
        ld b,a                      ; B = the column
        ld de,line
.copy:
        ld a,(hl)
        cp c
        jr nz,.copied
        push bc
        ld bc,-COLS
        add hl,bc
        ld a,(hl)
        ld (de),a
        ld bc,COLS + 1
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
        cp COLS
        ret nc
        ld l,a                      ; x
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (pv_rect),hl
        ld de,(pv_dy)
        ld (pv_rect + 2),de
        ld de,COLS * 8
        ex de,hl
        or a
        sbc hl,de
        ld (pv_rect + 4),hl
        push ix
        ld ix,pv_rect
        call VOS_RECT
        pop ix
        ret

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1: pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1

bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 9
                db T_NEW, CMD_NEW, "N", 0
                db T_OPEN, CMD_OPEN, "O", 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_SAVE_AS, CMD_SAVE_AS, 0, 0
                db T_PREVIEW, CMD_PREVIEW, "P", 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_discard:    db T_MENU, T_DISCARD, 2, VM_YES, VM_NO
dlg_big:        db T_MENU, T_TOO_BIG, 1, VM_OK
noname:         db "NONAME  MD "
ext_txt:        db "MD "

        include "app_texts.asm"     ; texts, from texts.txt

fdrive:         db 0                ; OPEN and SAVE: 0 A:, 1 B:
fname:          ds 11
name_tmp:       ds 11
name_in:        ds 10               ; VOS_INPUT: 8 + 2
modified:       db 0
redo:           db 0                ; after an edit: 1 its line, 2 all
cur:            dw 0                ; -> the cursor, in text
tend:           dw 0                ; -> after the text
top:            dw 0                ; -> the first line on the screen
left:           db 0                ; the first column on the screen
cur_ls:         dw 0                ; -> the cursor's line
cur_row:        db 0
cur_col:        db 0
click_r:        db 0
click_c:        db 0
cat:            dw 0
flen:           dw 0
outp:           dw 0
sbuf:           ds 32
pv_mode:        db 0                ; 1: the page
pv_top:         dw 0                ; the page line at the top
pv_y:           dw 0                ; the page line being made
pv_more:        db 0                ; 1: more lines below the screen
pv_sp:          dw 0
pv_fence:       db 0                ; 1: in a ``` code block
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
line:           ds COLS + 1
text:           ds TEXT_MAX

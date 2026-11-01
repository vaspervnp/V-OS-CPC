; =====================================================================
; notepad.asm - NOTEPAD, a text editor for V-OS (made with the SDK)
;
; Mode 1, 48 columns, 22 lines on the screen; ^M (PAGE) switches to
; the page: mode 2 (API 25), black on white, 80 columns between the
; page's edges, a line where a page of PAGE_LINES lines ends, and the
; page in the last line. Up to 4K of text, kept
; here with LF between the lines; on the disc the lines end with CR LF
; (a binary file, through the data bank). With a RAM expansion the data
; bank is NOTEPAD's own (VX_DATA, API 21), and the text up to 16K: 4K
; of it here, a window around the cursor, the rest in the data bank
; (before the window from #4000, after it up to #7FFF), which moves
; when the cursor comes near its ends (win_check). The keys type in the V-OS
; keyboard's language; the arrows and a click move the cursor, DEL
; deletes before it, CLR at it, RETURN starts a line. A line wider than
; the screen moves the view sideways, 16 columns at a time.
;   NOTEPAD menu: NEW ^N, OPEN ^O, SAVE ^S, SAVE AS, OTHER DRIVE (the
;   drive OPEN and SAVE use, A: or B:), PAGE ^M, ABOUT, BACK ^Q
; The last line shows the drive and file ("*": not saved), the line
; and the column.
;   make app NAME=notepad     build/NOTEPAD.BIN, and build/vos.dsk
; =====================================================================

        include "api/vos_api.inc"

BG              equ 2               ; pens (palette below)
INK             equ 1
CUR_PEN         equ 3
COLS            equ 48              ; the text on the screen (mode 1)
COLS2           equ 80              ; on the page (mode 2), from PAGE_X
PAGE_X          equ 64
PAGE_LINES      equ 60              ; lines a page
ROWS            equ 22
TOP_Y           equ 14
STATUS_Y        equ 238
HINT_Y          equ 249
TEXT_MAX        equ 4096            ; the window (all the text on a 6128)
DATA            equ #4000           ; the file, in the data bank
BIG_MAX         equ #4000           ; the text, with a data bank of its own
FILL            equ 2560            ; the window when it moves: from
WIN_BACK        equ 1280            ; that far before the cursor; again
WIN_TOP         equ 256             ; when the top of the screen or the
WIN_LOW         equ 1024            ; cursor comes that near its ends,
WIN_FULL        equ TEXT_MAX - 1040 ; or it has this much
KEY_CLR         equ 16

CMD_NEW         equ VC_APP + 1               ; menu items: commands
CMD_OPEN        equ VC_APP + 2
CMD_SAVE        equ VC_APP + 3
CMD_SAVE_AS     equ VC_APP + 4
CMD_DRIVE       equ VC_APP + 5
CMD_ABOUT       equ VC_APP + 6
CMD_PAGE        equ VC_APP + 12
CMD_BACK        equ VC_APP + 7
CMD_COPY        equ VC_APP + 8       ; the EDIT menu
CMD_CUT         equ VC_APP + 9
CMD_PASTE       equ VC_APP + 10
CMD_ALL         equ VC_APP + 11

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
        call set_mode
        call VOS_MENU_VIEW
        ld (bar + 5),hl
        call VOS_MENU_HELP
        ld (bar + 7),hl
        ld hl,bar
        call VOS_SET_BAR
        pop af
        cp 2
        jr z,.back
        ld a,(VOS_SELF)             ; files on its own drive at first
        ld (fdrive),a
        ld a,VX_DATA                ; the data bank its own: up to 16K
        call VOS_EXT
        ld (big),a
        call new_doc
.back:
        call redraw
        ; fall through

; a file to open from the Desktop or the Commander (VOS_OPEN): taken,
; then loaded as OPEN does, after asking about unsaved changes
open_arg:
        ld hl,VOS_OPEN
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        call discard_ok
        ret nz
        ld a,(VOS_OPEN + 1)
        ld (fdrive),a
        ld hl,VOS_OPEN + 2
        ld de,name_tmp
        ld bc,11
        ldir
        jp load_file

; everything, again
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        ld hl,0
        ld de,HINT_Y
        ld a,(ncols)
        ld c,a
        ld a,T_HINT
        call print_label
        ld a,(pmode)                ; the page: its edges
        cp 2
        call z,edges
        call place
        call draw_all
        jp status

new_doc:
        ld hl,0
        ld (plen),hl
        ld (slen),hl
        ld (plines),hl
        ld hl,text
        ld (tend),hl
        ld (cur),hl
        ld (top),hl
        xor a
        ld (left),a
        ld (modified),a
        ld (sel_on),a
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
        ld a,(hl)
        cp VE_PTR_DOWN
        jp z,click
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_KEY_REPEAT
        ret nz
.key:
        inc hl
        ld a,(hl)                   ; the key, its character, the mods
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
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

; A = key, C = its character, B = mods. SHIFT and an arrow: the
; selection from where the cursor was; typing, RETURN, DEL and CLR take
; the selection out first (DEL and CLR: only that)
action:
        ld e,a
        cp VK_LEFT
        jr z,.arrow
        cp VK_RIGHT
        jr z,.arrow
        cp VK_UP
        jr z,.arrow
        cp VK_DOWN
        jr z,.arrow
        cp VK_DEL
        jr z,.del
        cp KEY_CLR
        jr z,.clr
        cp VK_RETURN
        jr z,.line
        cp VK_ENTER
        jr z,.line
        ld a,c
        cp 32
        ret c
        push af
        call sel_delete
        pop af
        call insert
        ret c
        ld a,(redo)
        or a
        ret nz
        ld a,1                      ; its line again
        ld (redo),a
        ret
.line:
        call sel_delete
        ld a,10
        call insert
        jp redo_all
.del:
        call sel_delete
        jp z,backspace
        ret
.clr:
        call sel_delete
        jp z,delete
        ret
.arrow:
        ld a,b
        and VMOD_SHIFT
        jr z,.plain
        ld a,(sel_on)
        or a
        jr nz,.held
        ld hl,(cur)
        ld (sel),hl
        inc a
        ld (sel_on),a
.held:
        call redo_all
        jr .go
.plain:
        call sel_off
.go:
        ld a,e
        cp VK_LEFT
        jr z,go_left
        cp VK_RIGHT
        jr z,go_right
        cp VK_UP
        jr z,go_up
        jr go_down

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
        push af
        call room
        ld a,h
        or l
        jr z,.full
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
        pop af
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
        ex de,hl                    ; column = (x - xoff) / 8
        ld de,(xoff)
        or a
        sbc hl,de
        ret c
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,l
        ld hl,ncols
        cp (hl)
        ret nc
        ld (click_c),a
        ld hl,.go
        jp edit
.go:
        call sel_off
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
        cp CMD_COPY
        ld hl,do_copy
        jp z,edit
        cp CMD_CUT
        ld hl,do_cut
        jp z,edit
        cp CMD_PASTE
        ld hl,do_paste
        jp z,edit
        cp CMD_ALL
        ld hl,do_all
        jp z,edit
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
        cp CMD_PAGE
        jr nz,.not_page
        ld hl,pmode                 ; mode 1 <-> the page, mode 2
        ld a,(hl)
        xor 3
        ld (hl),a
        xor a
        ld (left),a
        call set_mode
        call VOS_DRAW_BAR
        jp redraw
.not_page:
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
; the selection and the clipboard (VOS_EXT, API 16)
; ---------------------------------------------------------------------
; -> Z if there is no selection (or an empty one); else HL -> its start,
; DE -> after it
sel_range:
        ld a,(sel_on)
        or a
        ret z
        ld hl,(sel)
        ld de,(cur)
        call same
        jr z,.none
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.ordered
        ex de,hl
.ordered:
        or 1
        ret
.none:
        xor a
        ld (sel_on),a
        ret

; no selection any more (all drawn again if there was one)
sel_off:
        ld a,(sel_on)
        or a
        ret z
        xor a
        ld (sel_on),a
        jp redo_all

; the selection out of the text, the cursor at its start -> NZ; Z if
; there was none
sel_delete:
        call sel_range
        ret z
        ld (cur),hl
        push hl
        push de
        ld hl,(tend)                ; the bytes after it
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        pop de
        ld a,b
        or c
        jr z,.moved
        ldir
.moved:
        ld (tend),de
        xor a
        ld (sel_on),a
        inc a
        ld (modified),a
        call redo_all
        or a
        ret

; ^C: the selection into the clipboard
do_copy:
        call sel_range
        ret z
        push hl
        ex de,hl
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        ld a,VX_CLIP_PUT
        jp VOS_EXT

; ^X: into the clipboard, then out of the text
do_cut:
        call do_copy
        jp sel_delete

; ^V: the clipboard in at the cursor (instead of the selection), as
; much as there is room for
do_paste:
        call sel_delete
        ld a,VX_CLIP_GET
        ld bc,0
        call VOS_EXT                ; HL = its size
        ld a,h
        or l
        ret z
        push hl
        call room                   ; the room left
        pop bc
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,.fits
        ld b,h
        ld c,l
.fits:
        ld a,b
        or c
        ret z
        ld (paste_n),bc
        ld hl,(tend)                ; the rest that many places on
        ld de,(cur)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(tend)
        dec hl
        push hl
        ld de,(paste_n)
        add hl,de
        ex de,hl
        pop hl
        ld a,b
        or c
        jr z,.gap
        lddr
.gap:
        ld hl,(tend)
        ld de,(paste_n)
        add hl,de
        ld (tend),hl
        ld de,(cur)
        ld bc,(paste_n)
        ld a,VX_CLIP_GET
        call VOS_EXT
        ld hl,(cur)
        ld de,(paste_n)
        add hl,de
        ld (cur),hl
        ld a,1
        ld (modified),a
        jp redo_all

; ^A: all of the text
do_all:
        ld hl,text
        ld (sel),hl
        ld hl,(tend)
        ld (cur),hl
        ld a,1
        ld (sel_on),a
        jp redo_all

; ---------------------------------------------------------------------
; files
; ---------------------------------------------------------------------
; OPEN: a .TXT file of fdrive into the data bank, then here, without CR
; and from the end-of-file mark (26) on
open:
        call discard_ok
        ret nz
        ld a,(fdrive)               ; its .TXT files
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
load_file:                          ; name_tmp on fdrive
        ld a,(fdrive)
        or VOS_DATA
        ld hl,name_tmp
        ld de,DATA
        call VOS_LOAD
        jr c,.error
        ld a,(big)
        or a
        jr nz,.fits
        ld hl,TEXT_MAX
        sbc hl,bc                   ; (no carry)
        jr nc,.fits
        ld hl,dlg_big
        jp VOS_DIALOG
.fits:
        ld hl,DATA                  ; UTF-8 into the V-OS set
        ld e,VOS_DATA
        ld a,VX_UTF8
        call VOS_EXT                ; -> BC (as it was before API 23)
        call from_file
        ld hl,0                     ; the window at its start
        ld (cur_a),hl
        ld (top_a),hl
        ld hl,text
        ld (tend),hl
        call win_go
        xor a
        ld (left),a
        ld (modified),a
        ld (sel_on),a
        ld hl,name_tmp
        ld de,fname
        ld bc,11
        ldir
        jp redraw
.error:                             ; the text in the data bank lost?
        ld hl,big
        bit 0,(hl)
        jp z,VOS_ERROR
        call VOS_ERROR
        call new_doc
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

; SAVE AS: a name (8 characters), .TXT
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

; the text into the data bank, LF as CR LF, then to the disc; then the
; text in the data bank and the window again
write:
        call win_flush
        ld hl,0                     ; all of it after the window
        call bound
        ld hl,0                     ; its LFs: the file has as many CRs
        ld (nlf),hl
        call s_start
        ld hl,(slen)
.count:
        ld a,h
        or l
        jr z,.counted
        call chunk
        sbc hl,bc                   ; (no carry)
        push hl
        ex de,hl
        push hl
        add hl,bc
        ex (sp),hl
        call get
        ld hl,(nlf)
        add hl,de
        ld (nlf),hl
        pop de
        pop hl
        jr .count
.counted:
        ld hl,(slen)
        ld de,(nlf)
        add hl,de
        ld de,BIG_MAX + 1
        sbc hl,de                   ; (no carry)
        jr c,.fits
        call win_go
        ld hl,dlg_big
        jp VOS_DIALOG
.fits:
        ld hl,DATA                  ; 2K at a time: read into the
        ld (outp),hl                ; buffer's second half, written
        call s_start                ; with CRs from its start
        ld hl,(slen)
.piece:
        ld a,h
        or l
        jr z,.save
        ld bc,2048
        push hl
        sbc hl,bc                   ; (no carry)
        pop hl
        jr nc,.most
        ld b,h
        ld c,l
.most:
        or a
        sbc hl,bc
        push hl
        push bc
        push de
        ex de,hl
        ld de,text + 2048
        call VOS_BANK_GET
        pop hl
        pop bc
        push bc
        add hl,bc
        ex (sp),hl                  ; the next piece's start kept
        ld b,h
        ld c,l
        ld hl,text + 2048
        ld de,text
.char:
        ld a,(hl)
        inc hl
        cp 10
        jr nz,.put
        ld a,13
        ld (de),a
        inc de
        ld a,10
.put:
        ld (de),a
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.char
        ex de,hl                    ; DE..: the piece, with CRs
        ld de,text
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld hl,(outp)
        push hl
        add hl,bc
        ld (outp),hl
        pop de
        call put
        pop de
        pop hl
        jr .piece
.save:
        ld hl,(outp)
        ld de,DATA
        or a
        sbc hl,de
        ld b,h
        ld c,l
        push bc
        ld a,(fdrive)
        or VOS_DATA
        ld hl,fname
        call VOS_SAVE
        pop bc
        push af
        call from_file              ; the text and the window again
        call win_go
        pop af
        jp c,VOS_ERROR
        xor a
        ld (modified),a
        jp status

; ---------------------------------------------------------------------
; the text in the data bank: plen bytes before the window from DATA,
; plines LFs among them; slen bytes after it, up to DATA + #4000
; ---------------------------------------------------------------------
; -> HL = how many more characters fit
room:
        ld hl,text + TEXT_MAX
        ld de,(tend)
        or a
        sbc hl,de
        ld a,(big)
        or a
        ret z
        ex de,hl                    ; and in the data bank
        ld hl,BIG_MAX - TEXT_MAX    ; (+ DE first: it never goes below
        ld bc,(plen)                ; 0 on the way)
        add hl,de
        or a
        sbc hl,bc
        ld bc,(slen)
        or a
        sbc hl,bc
        push hl
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret

; the window moves when the screen's top or the cursor comes near its
; ends, with more text there, or when it is nearly full (place)
win_check:
        ld a,(big)
        or a
        ret z
        ld hl,(tend)
        ld de,text + WIN_FULL
        or a
        sbc hl,de
        jr nc,win_move
        ld hl,(plen)
        ld a,h
        or l
        jr z,.end
        ld hl,(top)
        ld de,text + WIN_TOP
        sbc hl,de                   ; (no carry)
        jr c,win_move
.end:
        ld hl,(slen)
        ld a,h
        or l
        ret z
        ld hl,(tend)
        ld de,(cur)
        or a
        sbc hl,de
        ld de,WIN_LOW
        sbc hl,de
        ret nc
win_move:
        call win_flush
        call win_go
        jp redo_all

; the window into the data bank, after the text before it; cur_a,
; top_a, sel_a: where cur, top and sel are in all of the text
win_flush:
        ld hl,(cur)
        call whole
        ld (cur_a),hl
        ld hl,(top)
        call whole
        ld (top_a),hl
        ld hl,(sel)
        call whole
        ld (sel_a),hl
        ld hl,(tend)
        ld de,text
        or a
        sbc hl,de
        ld b,h
        ld c,l
        push bc
        ex de,hl
        call lf_count
        ld hl,(plines)
        add hl,de
        ld (plines),hl
        pop bc
        ld hl,(plen)
        push hl
        add hl,bc
        ld (plen),hl
        pop hl
        ld de,DATA
        add hl,de
        ex de,hl
        call put
        ld hl,text
        ld (tend),hl
        ret

; HL -> in the window -> HL = where in all of the text
whole:
        ld de,text
        or a
        sbc hl,de
        ld de,(plen)
        add hl,de
        ret

; the window again around cur_a (win_flush, from_file): from WIN_BACK
; before it, FILL bytes (all of the text on a 6128); cur, top and sel
; there
win_go:
        ld hl,0
        ld bc,TEXT_MAX
        ld a,(big)
        or a
        jr z,.from
        ld hl,(cur_a)
        ld de,WIN_BACK
        sbc hl,de                   ; (no carry)
        jr nc,.back
        ld hl,0
.back:
        ld bc,FILL
.from:
        ld (win_a),hl
        push bc
        call bound
        pop bc
        ld hl,(slen)                ; as much as there is
        push hl
        sbc hl,bc                   ; (no carry)
        pop hl
        jr nc,.most
        ld b,h
        ld c,l
.most:
        push bc                     ; from the start of what is after
        call s_start
        ex de,hl
        pop bc
        push bc
        call get
        ld hl,(slen)
        pop bc
        or a
        sbc hl,bc
        ld (slen),hl
        ld hl,text
        add hl,bc
        ld (tend),hl
        ld hl,(cur_a)
        call in_win
        ld (cur),hl
        ld hl,(sel_a)
        call in_win
        ld (sel),hl
        ld hl,(top_a)
        call in_win
        jr nc,.top
        ld hl,(cur)                 ; it was before the window
        call line_begin
.top:
        ld (top),hl
        ret

; HL = where in all of the text -> HL -> it in the window, or its start
; (carry: before it) or its end
in_win:
        ld de,(win_a)
        or a
        sbc hl,de
        jr c,.before
        ld de,text
        add hl,de
        ex de,hl
        ld hl,(tend)
        sbc hl,de
        ex de,hl
        ret nc
        ld hl,(tend)
        or a
        ret
.before:
        ld hl,text
        ret

; the boundary between the text before the window and after it moves
; to HL, through the buffer (empty: win_flush first)
bound:
        ld (bnd),hl
.again:
        ld hl,(plen)
        ld de,(bnd)
        or a
        sbc hl,de
        ret z
        jr c,.forward
        call chunk                  ; the last bytes before it go after
        ld hl,(plen)
        sbc hl,bc                   ; (no carry)
        ld (plen),hl
        ld de,DATA
        add hl,de
        push bc
        call get
        ld hl,(plines)
        or a
        sbc hl,de
        ld (plines),hl
        pop bc
        ld hl,(slen)
        add hl,bc
        ld (slen),hl
        call s_start
        call put
        jr .again
.forward:
        ld hl,(bnd)                 ; the first bytes after it go before
        ld de,(plen)
        or a
        sbc hl,de
        call chunk
        call s_start
        ex de,hl
        push bc
        call get
        ld hl,(plines)
        add hl,de
        ld (plines),hl
        pop bc
        ld hl,(slen)
        or a
        sbc hl,bc
        ld (slen),hl
        ld hl,(plen)
        push hl
        add hl,bc
        ld (plen),hl
        pop hl
        ld de,DATA
        add hl,de
        ex de,hl
        call put
        jr .again

; HL = bytes -> BC = as many as the buffer takes (no carry)
chunk:
        ld bc,TEXT_MAX
        push hl
        or a
        sbc hl,bc
        pop hl
        ret nc
        ld b,h
        ld c,l
        or a
        ret

; -> DE = the start of what is after the window
s_start:
        ld hl,DATA + #4000
        ld de,(slen)
        or a
        sbc hl,de
        ex de,hl
        ret

; HL -> in the data bank, BC = bytes: into the buffer -> DE = their LFs
get:
        ld de,text
        push bc
        call VOS_BANK_GET
        pop bc
        ld hl,text
        ; fall through
; HL -> bytes, BC = how many -> DE = the LFs among them
lf_count:
        ld de,0
        ld a,b
        or c
        ret z
        ld a,10
.find:
        cpir
        ret nz
        inc de
        jp pe,.find
        ret

; DE -> in the data bank, BC = bytes: there from the buffer
put:
        ld hl,text
        jp VOS_BANK_PUT

; the file in the data bank (BC bytes from DATA) -> all of it after the
; window (none before): no CR or other codes, TAB a space, nothing from
; the end-of-file mark (26) on. Read from its end, a buffer at a time,
; and written from the end of the bank down.
from_file:
        ld hl,DATA
        add hl,bc
        ld (inp),hl
        ld hl,DATA + #4000
        ld (outp),hl
.piece:
        ld hl,(inp)
        ld de,DATA
        or a
        sbc hl,de
        jr z,.done
        call chunk
        ld hl,(inp)
        sbc hl,bc                   ; (no carry)
        ld (inp),hl
        push bc
        ld de,text
        call VOS_BANK_GET
        pop bc
        ld hl,text - 1
        add hl,bc
        ld (bend),hl
        ld d,h
        ld e,l
.char:
        ld a,(hl)
        dec hl
        cp 26                       ; the end: nothing after it
        jr nz,.not_end
        ld de,DATA + #4000
        ld (outp),de
        ld de,(bend)
        jr .next
.not_end:
        cp 9
        jr nz,.tab
        ld a," "
.tab:
        cp 10
        jr z,.keep
        cp 32
        jr c,.next
.keep:
        ld (de),a
        dec de
.next:
        dec bc
        ld a,b
        or c
        jr nz,.char
        ld hl,(bend)                ; DE + 1 ..: what the piece gives
        or a
        sbc hl,de
        ld b,h
        ld c,l
        inc de
        ld hl,(outp)
        sbc hl,bc                   ; (no carry)
        ld (outp),hl
        ex de,hl
        call VOS_BANK_PUT
        jr .piece
.done:
        ld hl,DATA + #4000
        ld de,(outp)
        or a
        sbc hl,de
        ld (slen),hl
        ld hl,0
        ld (plen),hl
        ld (plines),hl
        ret

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
        call win_check
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
        push hl
        ld hl,ncols
        cp (hl)
        ld a,(hl)
        pop hl
        jr c,.row
        sub 16                      ; right of it
        ld b,a
        ld a,(cur_col)
        sub b
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
        ld bc,(xoff)
        add hl,bc
        pop af
        jp VOS_CHAR

; A = row, HL -> its line (carry: none, the row empty)
draw_row:
        push af
        ld de,line
        ld a,(ncols)
        ld b,a
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
        ld (row_p),hl               ; the row's first character
.char:
        call at_eol
        jr z,.pad
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .char
        jr .print
.pad:
        ld a,(ncols)                ; the characters of the row (the
        sub b                       ; rest is filled, row_rest)
        ld (row_k),a
        jr .printed
.print:
        ld a,(ncols)
        ld (row_k),a
.printed:
        xor a
        ld (de),a
        call colours
        pop af
        call row_y
        ld (row_y0),de
        ld hl,(xoff)
        ld bc,line
        call VOS_PRINT
        call row_rest
        call sel_range              ; the selected part, inverted
        ret z
        push de
        call .col
        ld (row_i0),a
        pop hl
        call .col
        ld hl,row_i0
        sub (hl)
        ret z
        ret c
        add a,(hl)                  ; its end: a zero there
        ld e,a
        ld d,0
        ld hl,line
        add hl,de
        ld (hl),0
        ld a,BG
        ld c,INK
        call VOS_COLOURS
        ld a,(row_i0)
        ld e,a
        ld d,0
        ld hl,line
        add hl,de
        ld b,h
        ld c,l
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(xoff)
        add hl,de
        ld de,(row_y0)
        jp VOS_PRINT
; HL -> in the text -> A = its column in the row, 0 to row_k
.col:
        ld de,(row_p)
        or a
        sbc hl,de
        jr nc,.after
        xor a
        ret
.after:
        ld a,h
        or a
        ld a,(row_k)
        ret nz
        cp l
        ret c
        ld a,l
        ret

; the mode of pmode, its palette, columns and x
set_mode:
        ld a,(pmode)
        call VOS_MODE
        ld hl,palette
        ld bc,COLS
        ld de,0
        ld a,(pmode)
        cp 2
        jr nz,.set
        ld hl,palette2
        ld c,COLS2
        ld e,PAGE_X
.set:
        ld a,c
        ld (ncols),a
        ld (xoff),de
        jp VOS_PALETTE

; the page's edges, left and right of its text
edges:
        ld ix,edge_rect
        ld hl,PAGE_X - 6
        ld (ix+0),l
        ld (ix+1),h
        call VOS_RECT
        ld hl,PAGE_X + COLS2 * 8 + 5
        ld (ix+0),l
        ld (ix+1),h
        jp VOS_RECT

; the page: a line over each row that starts a page (cur_line, a page
; every PAGE_LINES lines), none over the others
breaks:
        ld a,(pmode)
        cp 2
        ret nz
        ld hl,(cur_line)            ; the top row's line, from 0
        ld a,(cur_row)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        dec hl
        ld a,h
        or l
        ld (brk_first),a            ; 0: the text's first line on top
        ld bc,-PAGE_LINES
.mod:
        add hl,bc
        jr c,.mod
        ld bc,PAGE_LINES
        add hl,bc
        ld c,l                      ; its line in its page
        ld b,0                      ; row
.row:
        push bc
        ld a,c
        or a
        ld a,BG
        jr nz,.pen
        ld a,b                      ; a page starts here, unless it is
        or a                        ; the first line of the text
        ld a,INK
        jr nz,.pen
        ld a,(brk_first)
        or a
        ld a,INK
        jr nz,.pen
        ld a,BG
.pen:
        ld (brk_rect + 8),a
        ld a,b
        call row_y
        dec de
        ld (brk_rect + 2),de
        ld ix,brk_rect
        call VOS_RECT
        pop bc
        inc c
        ld a,c
        cp PAGE_LINES
        jr c,.next
        ld c,0
.next:
        inc b
        ld a,b
        cp ROWS
        jr c,.row
        ret

; PAGE n in the last line: n = (cur_line - 1) / PAGE_LINES + 1
page_no:
        ld a,T_PAGE_NO
        ld hl,384
        ld de,STATUS_Y
        ld c,6
        call print_label
        ld hl,(cur_line)
        dec hl
        ld de,-PAGE_LINES
        ld bc,1
.div:
        add hl,de
        jr nc,.n
        inc bc
        jr .div
.n:
        ld h,b
        ld l,c
        ld de,432
        jp number

; the row after its row_k characters: empty, a rectangle is faster
; than spaces
row_rest:
        ld a,(row_k)
        ld l,a
        ld a,(ncols)
        sub l
        ret z
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(xoff)
        add hl,de
        ld (rest_rect),hl
        ld hl,(row_y0)
        ld (rest_rect + 2),hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (rest_rect + 4),hl
        ld ix,rest_rect
        jp VOS_RECT

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

; the last line: A:NAME.TXT *, LINE n, COL n
status:
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
        ld hl,(xoff)
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
        ld bc,(plines)
        inc bc
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
        ld (cur_line),bc
        call breaks
        ld hl,(cur_line)
        ld de,240
        call number
        ld a,(pmode)                ; the page: PAGE n
        cp 2
        call z,page_no
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

; HL = number, DE = x (from xoff): 5 digits on the last line
number:
        push hl
        ld hl,(xoff)
        add hl,de
        ex (sp),hl
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

; A = text, HL = x (from xoff), DE = y, C = width: it, then spaces to
; the width
print_label:
        push de
        ld de,(xoff)
        add hl,de
        pop de
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

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1: pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
; the page (mode 2): pen 0 white paper, pen 1 black ink, a grey border
palette2:       db 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0
                db 13
edge_rect:      dw 0, TOP_Y - 2, 1, ROWS * 10 + 2
                db INK
brk_rect:       dw PAGE_X, 0, COLS2 * 8, 1
                db INK
rest_rect:      dw 0, 0, 0, 8
                db BG

bar:            db 4
                dw menu, edit_menu, 0, 0
menu:           db T_MENU, 9
                db T_NEW, CMD_NEW, "N", 0
                db T_OPEN, CMD_OPEN, "O", 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_SAVE_AS, CMD_SAVE_AS, 0, 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_PAGE, CMD_PAGE, "M", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
edit_menu:      db T_EDIT, 5
                db T_COPY, CMD_COPY, "C", 0
                db T_CUT, CMD_CUT, "X", 0
                db T_PASTE, CMD_PASTE, "V", 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_ALL, CMD_ALL, "A", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_discard:    db T_MENU, T_DISCARD, 2, VM_YES, VM_NO
dlg_big:        db T_MENU, T_TOO_BIG, 1, VM_OK
noname:         db "NONAME  TXT"
ext_txt:        db "TXT"

        include "app_texts.asm"     ; texts, from texts.txt

fdrive:         db 0                ; OPEN and SAVE: 0 A:, 1 B:
fname:          ds 11
name_tmp:       ds 11
name_in:        ds 10               ; VOS_INPUT: 8 + 2
modified:       db 0
redo:           db 0                ; after an edit: 1 its line, 2 all
cur:            dw 0                ; -> the cursor, in text
sel:            dw 0                ; -> the other end of the selection
sel_on:         db 0                ; 1: there is a selection
paste_n:        dw 0
row_p:          dw 0                ; draw_row: its first character,
row_k:          db 0                ; how many it shows, its y and
row_y0:         dw 0                ; where the selection starts
row_i0:         db 0
tend:           dw 0                ; -> after the text
top:            dw 0                ; -> the first line on the screen
left:           db 0                ; the first column on the screen
pmode:          db 1                ; 1, or 2: the page (^M)
ncols:          db COLS             ; the columns on the screen
xoff:           dw 0                ; x of the first one
cur_line:       dw 1                ; the cursor's line, from 1
brk_first:      db 0
cur_ls:         dw 0                ; -> the cursor's line
cur_row:        db 0
cur_col:        db 0
click_r:        db 0
click_c:        db 0
cat:            dw 0
outp:           dw 0
big:            db 0                ; 1: a data bank of its own (VX_DATA)
plen:           dw 0                ; the text before the window,
slen:           dw 0                ; after it (in the data bank)
plines:         dw 0                ; the LFs before it
cur_a:          dw 0                ; win_flush: cur, top, sel in all
top_a:          dw 0                ; of the text
sel_a:          dw 0
win_a:          dw 0                ; win_go: where the window starts
bnd:            dw 0
inp:            dw 0
bend:           dw 0
nlf:            dw 0
line:           ds COLS2 + 1
text:           ds TEXT_MAX

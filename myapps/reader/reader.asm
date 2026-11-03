; =====================================================================
; reader.asm - READER, Markdown pages from the disc or the web (SDK)
;
; Mode 1, 48 columns, 22 rows; ^M (PAGE): mode 2 (API 25), black on
; white, 80 columns between the page's edges. A page as MARKDOWN's
; preview shows it
; (../markdown/page.asm, with PV_LINKS). A page is a place: "A:NAME.MD"
; on a disc, or "host/path" on the web (HTTP, with the M4 board,
; VX_M4: C_HTTPGETMEM, then C_COPYBUF 512 bytes at a time), up to 6K.
;   arrows      scroll (left, right: a screen)
;   TAB         the next link on the screen (inverted)
;   RETURN      follow it: "http://host/path", "/path" on the same host,
;               or a name next to this page (on its disc, or on the web)
;   DEL         the page before (up to HIST_MAX back)
;   READER menu: OPEN A FILE ^O (.MD), OPEN AN ADDRESS ^U, PREVIOUS
;   PAGE, OTHER DRIVE, PAGE ^M, ABOUT, BACK ^Q
; At the start it opens INDEX.MD from its own drive.
;   make app NAME=reader      build/READER.BIN and build/reader.dsk
; =====================================================================

        include "api/vos_api.inc"

PV_LINKS        equ 1               ; page.asm: links, TAB and RETURN

BG              equ 2               ; pens (palette below)
INK             equ 1
CUR_PEN         equ 3
COLS            equ 48              ; the page on the screen (mode 1)
COLS2           equ 80              ; on the page (mode 2), from PAGE_X
PAGE_X          equ 64
ROWS            equ 22
TOP_Y           equ 14
STATUS_Y        equ 238
HINT_Y          equ 249
TEXT_MAX        equ 6144
DATA            equ #4000           ; a disc page, in the data bank
PLACE_MAX       equ 63              ; "A:NAME.MD" or "host/path"
HIST_MAX        equ 4
PIECE           equ 512

C_HTTPGETMEM    equ #4328           ; M4 commands (spinpoint.org/cpc/
C_COPYBUF       equ #4329           ; m4info.txt)

CMD_OPEN        equ VC_APP + 1      ; menu items: commands
CMD_ADDRESS     equ VC_APP + 2
CMD_PREVIOUS    equ VC_APP + 3
CMD_DRIVE       equ VC_APP + 4
CMD_ABOUT       equ VC_APP + 5
CMD_BACK        equ VC_APP + 6
CMD_PAGE        equ VC_APP + 7

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: INDEX.MD of its own drive; 2: the page as it was
init:
        push af
        ld hl,texts
        call VOS_TEXTS
        call set_mode
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        pop af
        cp 2
        jr z,redraw
        ld a,(VOS_SELF)
        ld (fdrive),a
        add a,"A"
        ld (start),a
        ld hl,text
        ld (tend),hl
        call redraw
        ld hl,start
        jp go_place

; everything, again
redraw:
        ld a,BG
        call VOS_CLS
        call VOS_DRAW_BAR
        ld a,(pmode)                ; the page: its edges
        cp 2
        call z,edges
        ld hl,0
        ld de,HINT_Y
        ld a,(ncols)
        ld c,a
        ld a,T_HINT
        call print_lab
        call pv_render
        ; fall through

; the last line: the place, in yellow
status:
        ld hl,place
        ld de,line
        ld a,(ncols)
        ld b,a
.char:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .char
        jr .end
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.end:
        xor a
        ld (de),a
        ld a,CUR_PEN
        ld c,BG
        call VOS_COLOURS
        ld hl,(xoff)
        ld de,STATUS_Y
        ld bc,line
        jp VOS_PRINT

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

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        push hl
        call VOS_UI_EVENT
        pop hl
        or a
        jp nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(hl)
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_KEY_REPEAT
        ret nz
.key:
        inc hl
        ld a,(hl)
        cp VK_TAB
        jp z,next_link
        cp VK_RETURN
        jp z,follow
        cp VK_ENTER
        jp z,follow
        cp VK_DEL
        jp z,previous
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
        jp pv_render

; A = command (the menu)
command:
        cp CMD_OPEN
        jp z,open_file
        cp CMD_ADDRESS
        jp z,open_address
        cp CMD_PREVIOUS
        jp z,previous
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,fdrive
        call vos_next_drive
        ret
.not_drive:
        cp CMD_PAGE
        jr nz,.not_page
        ld hl,pmode                 ; mode 1 <-> the page, mode 2: the
        ld a,(hl)                   ; page again from its top (it wraps
        xor 3                       ; elsewhere: no checkpoints)
        ld (hl),a
        ld hl,0
        ld (pv_top),hl
        call pv_new
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
        jp VOS_EXIT

; OPEN A FILE: a .MD of fdrive -> "X:NAME.MD"
open_file:
        ld a,(fdrive)
        or VOS_CAT_EXT
        ld hl,ext_md
        call VOS_CATALOG
        jp c,VOS_ERROR
        or a
        ret z
        ld (cat),hl
        ld a,T_OPEN_T
        call VOS_FILE_PICK
        ret c
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(cat)
        add hl,de
        ex de,hl                    ; DE -> its name
        ld hl,link
        ld a,(fdrive)
        add a,"A"
        ld (hl),a
        inc hl
        ld (hl),":"
        inc hl
        ex de,hl
        ld b,8                      ; NAME, then .EXT
.name:
        ld a,(hl)
        and #7F
        cp " "
        jr z,.named
        ld (de),a
        inc de
.named:
        inc hl
        djnz .name
        ld a,"."
        ld (de),a
        inc de
        ld b,3
.ext:
        ld a,(hl)
        and #7F
        cp " "
        jr z,.extd
        ld (de),a
        inc de
.extd:
        inc hl
        djnz .ext
        xor a
        ld (de),a
        ld hl,link
        jr go_place

; OPEN AN ADDRESS: typed, "http://" or not
open_address:
        ld hl,place                 ; the page's place, to change
        ld de,link
        ld bc,PLACE_MAX + 1
        ldir
        ld a,T_URL_T
        ld hl,link
        ld c,PLACE_MAX - 2
        call VOS_INPUT
        ret c
        ld hl,link
        call strip_http
        ret c
        ; fall through

; HL -> a place: the page now there, this one into the history
go_place:
        push hl
        ld a,(place)                ; none yet: nothing to keep
        or a
        jr z,.kept
        ld hl,hist + PLACE_MAX + 1  ; the oldest goes
        ld de,hist
        ld bc,(HIST_MAX - 1) * (PLACE_MAX + 1)
        ldir
        ld hl,place
        ld de,hist + (HIST_MAX - 1) * (PLACE_MAX + 1)
        ld bc,PLACE_MAX + 1
        ldir
        ld hl,hist_n
        ld a,(hl)
        cp HIST_MAX
        jr nc,.kept
        inc (hl)
.kept:
        pop hl
        ; fall through

; HL -> a place: loaded and shown (carry: it could not be)
load_place:
        ld de,new_place
        ld bc,PLACE_MAX + 1
        ldir
        ld a,T_LOADING
        call loading
        ld a,(new_place + 1)        ; "X:": a disc
        cp ":"
        jr nz,.web
        call load_disc
        jr .loaded
.web:
        call load_web
.loaded:
        jr c,.failed
        ld hl,new_place
        ld de,place
        ld bc,PLACE_MAX + 1
        ldir
        ld hl,0
        ld (pv_top),hl
        call pv_new
        ld a,#FF
        ld (pv_sel),a
        jp redraw
.failed:
        push af
        call status
        pop af
        or a                        ; A = text of the dialog
        ret z
        ld (dlg_fail + 1),a
        ld hl,dlg_fail
        jp VOS_DIALOG

; A = text: on the last line, then spaces to its end
loading:
        call VOS_MSG
        ld de,place_tmp
        ld a,(ncols)
        ld b,a
.char:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .char
        jr .end
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.end:
        xor a
        ld (de),a
        ld a,CUR_PEN
        ld c,BG
        call VOS_COLOURS
        ld hl,(xoff)
        ld de,STATUS_Y
        ld bc,place_tmp
        jp VOS_PRINT

; DEL: the page before
previous:
        ld hl,hist_n
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ld hl,hist + (HIST_MAX - 1) * (PLACE_MAX + 1)
        ld de,link
        ld bc,PLACE_MAX + 1
        ldir
        ld hl,hist + (HIST_MAX - 2) * (PLACE_MAX + 1) + PLACE_MAX
        ld de,hist + (HIST_MAX - 1) * (PLACE_MAX + 1) + PLACE_MAX
        ld bc,(HIST_MAX - 1) * (PLACE_MAX + 1)
        lddr
        ld hl,link
        jp load_place

; ---------------------------------------------------------------------
; links
; ---------------------------------------------------------------------
; TAB: the next link on the screen after the chosen one (or the first);
; the rows of both drawn again
next_link:
        ld a,(lk_n)
        or a
        ret z
        ld b,a
        ld hl,lk_tab
        ld a,(pv_sel)
        ld c,a
.find:
        ld a,c                      ; none chosen: the first
        cp #FF
        jr z,.take
        ld a,(hl)
        cp c
        jr z,.next
        jr nc,.take                 ; a bigger number
.next:
        ld de,5
        add hl,de
        djnz .find
        ld hl,lk_tab                ; none after it: the first
.take:
        ld a,(hl)
        ld (new_sel),a
        call sel_row                ; the old one's row
        ld a,(new_sel)
        ld (pv_sel),a
        ld a,c
        call row_again
        call sel_row                ; the new one's row
        ld a,c
        ; fall through

; A = row (#FF: none) -> that row of the page drawn again
row_again:
        cp #FF
        ret z
        ld (pv_only),a
        call pv_render
        ld a,#FF
        ld (pv_only),a
        ret

; -> C = the row of link pv_sel on the screen (#FF: not there), HL ->
; its lk_tab entry
sel_row:
        ld c,#FF
        ld a,(lk_n)
        or a
        ret z
        ld b,a
        ld hl,lk_tab
        ld a,(pv_sel)
.entry:
        cp (hl)
        jr z,.found
        ld de,5
        add hl,de
        djnz .entry
        ret
.found:
        inc hl
        ld c,(hl)
        dec hl
        ret

; RETURN: the chosen link, as a place next to this one
follow:
        call sel_row
        ld a,c
        inc a
        ret z
        inc hl                      ; its address and length
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        or a
        ret z
        cp PLACE_MAX - 8
        ret nc
        ld c,a
        ld b,0
        ex de,hl
        ld de,addr
        ldir
        xor a
        ld (de),a
        ld a,(addr)                 ; "#...": on this page
        cp "#"
        ret z
        call resolve
        ret c
        ld hl,link
        jp go_place

; addr, relative to place -> link; carry (and a dialog) if not HTTP
resolve:
        ld hl,addr
        call has_scheme             ; "http://" goes, others cannot
        jr nc,.relative
        ld hl,addr
        call strip_http
        ret c
        ld hl,addr
        ld de,link
        jp copy_z
.relative:
        ld a,(addr)                 ; "/path": the same host
        cp "/"
        jr nz,.next_to
        ld hl,place
        ld de,link
.host:
        ld a,(hl)
        or a
        jr z,.put
        cp "/"
        jr z,.put
        ld (de),a
        inc hl
        inc de
        jr .host
.next_to:                           ; next to it: up to its last "/" or
        ld hl,place                 ; ":" (a disc)
        ld de,link
        ld b,d
        ld c,e
.copy:
        ld a,(hl)
        or a
        jr z,.cut
        ld (de),a
        inc hl
        inc de
        cp "/"
        jr z,.mark
        cp ":"
        jr nz,.copy
.mark:
        ld b,d
        ld c,e
        jr .copy
.cut:
        ld d,b
        ld e,c
.put:
        ld hl,addr
        call copy_z
        or a
        ret

; HL -> an address -> carry if it has "://"
has_scheme:
        ld a,(hl)
        or a
        ret z
        inc hl
        cp ":"
        jr nz,has_scheme
        ld a,(hl)
        cp "/"
        jr nz,has_scheme
        scf
        ret

; HL -> an address: "http://" taken out (the rest moved up), carry and
; a dialog for another scheme
strip_http:
        push hl
        ld de,http
        ld b,7
.cmp:
        ld a,(de)
        cp (hl)
        jr z,.same
        add a,"A" - "a"             ; HTTP:// too
        cp (hl)
        jr nz,.other
.same:
        inc hl
        inc de
        djnz .cmp
        pop de
        call copy_z
        or a
        ret
.other:
        pop hl
        call has_scheme
        jr c,.bad
        or a                        ; no scheme: as it is
        ret
.bad:
        ld a,T_NO_HTTPS
        ld (dlg_fail + 1),a
        ld hl,dlg_fail
        call VOS_DIALOG
        scf
        ret

; ---------------------------------------------------------------------
; loading
; ---------------------------------------------------------------------
; new_place "X:NAME.EXT" -> text; carry and A = text of the dialog
load_disc:
        ld hl,fname
        ld b,11
.clear:
        ld (hl)," "
        inc hl
        djnz .clear
        ld hl,new_place + 2
        ld de,fname
        ld b,8
        call .part
        ld a,(hl)
        cp "."
        jr nz,.load
        inc hl
        ld de,fname + 8
        ld b,3
        call .part
.load:
        ld a,(new_place)
        and #DF
        sub "A"
        or VOS_DATA
        ld hl,fname
        ld de,DATA
        call VOS_LOAD
        ld a,T_NO_PAGE
        ret c
        ld hl,TEXT_MAX
        or a
        sbc hl,bc
        ld a,T_NO_PAGE
        ret c
        ld (flen),bc
        ld a,b
        or c
        jr z,.empty
        ld hl,DATA
        ld de,text
        call VOS_BANK_GET
.empty:
        ld bc,(flen)
        jp clean
; up to B characters to DE, until "." or the end, in capitals
.part:
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        cp "a"
        jr c,.cap
        cp "z" + 1
        jr nc,.cap
        sub 32
.cap:
        ld (de),a
        inc hl
        inc de
        djnz .part
        ret

; new_place "host/path" -> text, with the M4 board; carry and A = text
load_web:
        ld hl,new_place
        ld de,pk_get + 5
        call copy_z
        ex de,hl                    ; the packet's size, up to the zero
        ld de,pk_get
        or a
        sbc hl,de
        ld a,l
        ld (pk_get),a
        ld hl,pk_get
        ld de,resp
        ld bc,3 + 2
        ld a,VX_M4
        call VOS_EXT
        ld a,T_NO_M4
        ret c
        ld hl,(resp + 3)            ; bytes downloaded
        ld (flen),hl
        ld a,h
        or l
        ld a,T_NO_PAGE
        scf
        ret z
        ld hl,0
        ld (done),hl
.piece:
        ld hl,(flen)
        ld de,(done)
        or a
        sbc hl,de
        jr z,.copied
        ld de,PIECE
        push hl
        sbc hl,de
        pop hl
        jr c,.short
        ex de,hl
.short:
        ld (pk_copy + 5),hl
        ld (pc_n),hl
        ld hl,(done)
        ld (pk_copy + 3),hl
        ld hl,pk_copy
        ld de,resp
        ld bc,(pc_n)
        inc bc
        inc bc
        inc bc
        ld a,VX_M4
        call VOS_EXT
        ld a,T_NO_M4
        ret c
        ld hl,(done)                ; into the text
        ld de,text
        add hl,de
        ex de,hl
        ld hl,resp + 3
        ld bc,(pc_n)
        ldir
        ld hl,(done)
        ld de,(pc_n)
        add hl,de
        ld (done),hl
        jr .piece
.copied:
        ld bc,(flen)
        ; fall through

; BC = bytes at text: from UTF-8 into the V-OS set if it is UTF-8
; (VX_UTF8), then without CR and other codes, TAB a space, up to the
; end-of-file mark (26) -> tend; no carry
clean:
        ld hl,text
        ld e,0
        ld a,VX_UTF8
        call VOS_EXT                ; -> BC (as it was before API 23)
        ld hl,text
        ld de,text
.char:
        ld a,b
        or c
        jr z,.done
        ld a,(hl)
        inc hl
        dec bc
        cp 26
        jr z,.done
        cp 9
        jr nz,.tab
        ld a," "
.tab:
        cp 10
        jr z,.keep
        cp 32
        jr c,.char
.keep:
        ld (de),a
        inc de
        jr .char
.done:
        ld (tend),de
        or a
        ret

; ---------------------------------------------------------------------
; for page.asm, and small things
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

; HL -> zero-terminated text -> DE (with its zero); DE -> the zero
copy_z:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        jr copy_z

; A = text, HL = x (from xoff), DE = y, C = width: it, then spaces to
; the width
print_lab:
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
        ld a,INK
        ld c,BG
        call VOS_COLOURS
        pop de
        pop hl
        ld bc,line
        jp VOS_PRINT

        include "../markdown/page.asm"

; ---- data -----------------------------------------------------------
; black, white, blue, bright yellow (mode 1: pens 0..3), the border
palette:        db 0, 26, 1, 24, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16
                db 1
; the page (mode 2): pen 0 white paper, pen 1 black ink, a grey border
palette2:       db 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0, 26, 0
                db 13
edge_rect:      dw 0, TOP_Y - 2, 1, ROWS * 10 + 2
                db INK
bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 8
                db T_OPEN, CMD_OPEN, "O", 0
                db T_ADDRESS, CMD_ADDRESS, "U", 0
                db T_PREVIOUS, CMD_PREVIOUS, 0, 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_PAGE, CMD_PAGE, "M", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_fail:       db T_MENU, 0, 1, VM_OK
ext_md:         db "MD "
http:           db "http://"
start:          db "A:INDEX.MD", 0

        include "api/vos_drive.inc"
        include "app_texts.asm"     ; texts, from texts.txt

fdrive:         db 0
pmode:          db 1                ; 1, or 2: the page (^M)
ncols:          db COLS             ; the page's columns on the screen
xoff:           dw 0                ; x of the first one
cat:            dw 0
flen:           dw 0
done:           dw 0
pc_n:           dw 0
hist_n:         db 0
new_sel:        db 0
fname:          ds 11
place:          ds PLACE_MAX + 1    ; the page shown
new_place:      ds PLACE_MAX + 1
link:           ds PLACE_MAX + 1
addr:           ds PLACE_MAX + 1
place_tmp:      ds COLS2 + 1
hist:           ds HIST_MAX * (PLACE_MAX + 1)
pk_get:         db 0                ; C_HTTPGETMEM: size, command, bytes
                dw C_HTTPGETMEM     ; wanted, the address
                dw TEXT_MAX
                ds PLACE_MAX + 1
pk_copy:        db 6                ; C_COPYBUF: size, command, from,
                dw C_COPYBUF        ; bytes
                dw 0, 0
resp:           ds 3 + PIECE
line:           ds COLS2 + 1
        include "../markdown/page_data.asm"
tend:           dw 0
text:           ds TEXT_MAX

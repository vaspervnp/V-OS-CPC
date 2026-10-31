; =====================================================================
; paint.asm - PAINT, a drawing program for V-OS (made with the SDK)
;
; Mode 0, 16 colours. Two kinds of picture, in the same 8K here:
;   a picture   128 x 128 pixels, two a byte as on the screen (.PIC,
;               8192 bytes)
;   layers      64 x 64 pixels shown twice as big, in three layers.
;               Each has its pixels (2048 bytes) and a mask (512: a bit
;               a pixel, 0 where it lets the ones below show); then the
;               order of the layers, from the bottom, and which are
;               shown (.LYR, 7686 bytes). A pixel no layer shows is
;               white.
; The pointer draws: the AMX mouse, or the cursor keys with COPY as its
; button. The tools, on the right (or P B L X F):
;   PENCIL, BRUSH (3 x 3)  draw while the button is down
;   LINE, BOX              from where it went down to where it came up
;   FILL                   the area of one colour around the pointer
; The colours, below the picture (or TAB: the next one). With layers,
; under the tools, the layers from the top (a click chooses one), and
; keys: 1-3 choose one, H hides or shows it, U and D move it up or
; down, E the eraser (the colour after the 16: the pixels let the
; layers below show).
;   PAINT menu: NEW, NEW LAYERS, OPEN ^O, OPEN LAYERS, SAVE ^S, SAVE
;   AS, OTHER DRIVE (A: or B:), ABOUT, BACK ^Q
;   make app NAME=paint       build/PAINT.BIN, and build/vos.dsk
; =====================================================================

        include "api/vos_api.inc"

PIC_SIZE        equ 8192            ; a picture: (128 / 2) x 128
LPIX            equ 2048            ; a layer: (64 / 2) x 64, then its
LMASK           equ 512             ; mask, 64 x 64 bits
LAYER           equ LPIX + LMASK
L_ORDER         equ 3 * LAYER       ; 3 layers, from the bottom
L_VIS           equ L_ORDER + 3     ; 1: shown
LYR_SIZE        equ L_VIS + 3
ERASE           equ 16              ; the colour after the 16
CX              equ 4               ; the picture on the screen
CY              equ 16
TOOL_X          equ 136
TOOL_Y          equ 20
TOOL_STEP       equ 16
LAY_Y           equ 110             ; the layers, from the top
LAY_STEP        equ 12
SW_Y            equ 150             ; the colours
SW_W            equ 12
NAME_Y          equ 168
HINT_Y          equ 228
UI_BG           equ 9               ; pens: grey around the picture
SEL_BG          equ 5               ; yellow under the chosen tool
FILL_MAX        equ 64              ; FILL's stack: places to look at
                                    ; (in row_pairs, free then)

T_PENCIL_       equ 0               ; tools
T_BRUSH_        equ 1
T_LINE_         equ 2
T_BOX_          equ 3
T_FILL_         equ 4
TOOLS           equ 5

CMD_NEW         equ VC_APP + 1
CMD_NEW_L       equ VC_APP + 2
CMD_OPEN        equ VC_APP + 3
CMD_OPEN_L      equ VC_APP + 4
CMD_SAVE        equ VC_APP + 5
CMD_SAVE_AS     equ VC_APP + 6
CMD_DRIVE       equ VC_APP + 7
CMD_ABOUT       equ VC_APP + 8
CMD_BACK        equ VC_APP + 9
CMD_EXPORT      equ VC_APP + 10
SCR_DATA        equ #4000           ; EXPORT: the screen, in the data bank
SCR_X           equ 8               ; the picture there: bytes from the
SCR_Y           equ 36              ; left, lines from the top

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt
; The Launcher reads the icon from the disc: here, while PAINT runs,
; its 256 bytes (after "IC") hold the buffers below
icon_ram        equ VOS_APP_ADDR + VOS_ICON + 2
row_pairs       equ icon_ram        ; a row to draw: 64 (mask, pixels)
fstack          equ row_pairs       ; FILL's stack, there too
lbuf            equ icon_ram + 128  ; a line of text (25 bytes)
name_tmp        equ icon_ram + 160  ; names (11)
name_in         equ icon_ram + 176  ; (10)
lay_text        equ icon_ram + 192  ; "1 OFF": a layer (8)

; A = 0: a new start, a white picture; 2: back, as it was
init:
        push af
        ld hl,texts
        call VOS_TEXTS
        xor a
        call VOS_MODE
        ld hl,palette
        call VOS_PALETTE
        call VOS_MENU_VIEW
        ld (bar + 3),hl
        call VOS_MENU_HELP
        ld (bar + 5),hl
        ld hl,bar
        call VOS_SET_BAR
        ld a,VOS_PTR_KEYS           ; the cursor keys move the pointer
        call VOS_TICKS
        pop af
        cp 2
        jr z,.back
        ld a,(VOS_SELF)
        ld (fdrive),a
        call new_pic
.back:
        call redraw
        ; fall through

; a picture to open from the Desktop or the Commander (VOS_OPEN): taken,
; then loaded as OPEN or OPEN LAYERS does (by its extension)
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
        ld a,(name_tmp + 8)         ; .LYR: layers
        and #7F
        sub "L"
        jr z,.mode
        ld a,1
.mode:
        xor 1
        ld (open_mode),a
        jp load_file

; everything, again
redraw:
        ld a,UI_BG
        call VOS_CLS
        call VOS_DRAW_BAR
        push ix
        ld ix,frame_rect            ; black round the picture and the
        call VOS_RECT               ; colours
        ld ix,sw_frame
        call VOS_RECT
        pop ix
        call draw_canvas
        call draw_tools
        call draw_layers
        call draw_colours
        call draw_name
        ld a,(lmode)                ; the keys
        or a
        jr z,.hints
        ld a,T_HINT3
        ld hl,0
        ld de,HINT_Y
        ld c,24
        call print_lab
.hints:
        ld a,T_HINT1
        ld hl,0
        ld de,HINT_Y + 10
        ld c,24
        call print_lab
        ld a,T_HINT2
        ld hl,0
        ld de,HINT_Y + 20
        ld c,24
        jp print_lab

; a white picture, NONAME.PIC
new_pic:
        ld hl,canvas
        ld de,canvas + 1
        ld bc,PIC_SIZE - 1
        ld (hl),#C0                 ; pen 1 in both pixels
        ldir
        xor a
        ; fall through

; A = 0 a picture, 1 layers: NONAME, as new
set_mode:
        ld (lmode),a
        or a
        ld a,128
        jr z,.size
        ld a,64
.size:
        ld (cw),a
        ld a,(colour)               ; no eraser for a picture
        cp ERASE
        jr c,.colour
        xor a
        call set_colour
.colour:
        xor a
        ld (modified),a
        ld (down),a
        ld hl,noname
        ld de,fname
        ld bc,8
        ldir
        call ext_now
        ld bc,3
        ldir
        ret

; layers: the bottom one white, the others clear, all shown
new_layers:
        ld hl,canvas
        ld de,canvas + 1
        ld bc,PIC_SIZE - 1
        ld (hl),0
        ldir
        ld hl,canvas
        ld de,canvas + 1
        ld bc,LPIX - 1
        ld (hl),#C0
        ldir
        ld hl,canvas + LPIX
        ld de,canvas + LPIX + 1
        ld bc,LMASK - 1
        ld (hl),#FF
        ldir
        ld hl,layers0
        ld de,canvas + L_ORDER
        ld bc,6
        ldir
        ld a,1
        ld (cl),a
        jr set_mode

; -> HL -> "PIC" or "LYR"
ext_now:
        ld hl,ext_pic
        ld a,(lmode)
        or a
        ret z
        inc hl
        inc hl
        inc hl
        ret

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
        jr z,key
        cp VE_PTR_DOWN
        jp z,ptr_down
        cp VE_PTR_MOVE
        jp z,ptr_move
        cp VE_PTR_UP
        jp z,ptr_up
        ret

; P B L X F: the tools; TAB: the next colour; with layers 1-3 H U D E
key:
        inc hl
        ld a,(hl)
        cp VK_TAB
        jr nz,.char
        ld a,(lmode)                ; 16 colours, and with layers the
        add a,ERASE                 ; eraser
        ld d,a
        ld a,(colour)
        inc a
        cp d
        jp c,set_colour
        xor a
        jp set_colour
.char:
        inc hl
        ld a,(hl)
        or #20                      ; small letters
        ld hl,tool_keys
        ld b,TOOLS
.find:
        cp (hl)
        jr z,.tool
        inc hl
        djnz .find
        ld c,a
        ld a,(lmode)
        or a
        ret z
        ld a,c
        cp "e"
        ld a,ERASE
        jp z,set_colour
        ld a,c
        sub "1"
        cp 3
        jp c,choose
        ld a,c
        cp "h"
        jr z,show_hide
        cp "u"
        ld b,1
        jr z,move
        cp "d"
        ld b,-1
        jr z,move
        ret
.tool:
        ld a,TOOLS
        sub b
        jp set_tool

; H: the layer chosen hidden or shown
show_hide:
        ld a,(cl)
        ld e,a
        ld d,0
        ld hl,canvas + L_VIS
        add hl,de
        ld a,(hl)
        xor 1
        ld (hl),a
        jr layers_changed

; B = 1 up, -1 down: the layer chosen changes places with that one
move:
        call cur_pos                ; HL -> it in the order, A = place
        add a,b
        cp 3
        ret nc
        ld e,(hl)
        push hl
        bit 7,b
        jr nz,.down
        inc hl
        jr .swap
.down:
        dec hl
.swap:
        ld d,(hl)
        ld (hl),e
        pop hl
        ld (hl),d
        ; fall through
layers_changed:
        call changed
        call draw_canvas
        jp draw_layers

; -> HL -> the layer chosen in the order, A = its place (0: bottom)
cur_pos:
        ld hl,canvas + L_ORDER
        ld a,(cl)
        ld c,a
        xor a
.look:
        ld e,a
        ld a,(hl)
        cp c
        ld a,e
        ret z
        inc hl
        inc a
        jr .look

; A = layer: the one drawn on
choose:
        ld (cl),a
        jp draw_layers

; HL -> event -> C = x, B = y in the picture; carry if outside it.
; (ev_x, ev_y: on the screen)
ptr_at:
        inc hl
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (ev_x),de
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (ev_y),bc
        ld hl,(ev_x)
        ld de,CX
        call .part
        ret c
        ld c,a
        ld hl,(ev_y)
        ld de,CY
        call .part
        ret c
        ld b,a
        ret
; HL - DE, in the picture's pixels -> A; carry if outside
.part:
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        scf
        ret nz
        ld a,l
; L = screen pixels -> A, E: the picture's; carry if past its end
pic_part:
        call half
        ld e,a
        ld a,(cw)
        dec a
        cp e
        ld a,e
        ret

; A = screen pixels -> the picture's (half of them with layers)
half:
        ld e,a
        ld a,(lmode)
        or a
        ld a,e
        ret z
        srl a
        ret

ptr_down:
        call ptr_at
        jr c,.outside
        ld a,c
        ld (x0),a
        ld (lnx),a
        ld a,b
        ld (y0),a
        ld (lny),a
        ld a,(tool)
        cp T_FILL_
        jp z,fill
        ld a,1
        ld (down),a
        call changed
        ld a,(tool)
        cp T_LINE_
        ret nc                      ; LINE, BOX: when it comes up
        jp dot
.outside:
        ld hl,(ev_y)                ; a colour?
        ld de,SW_Y
        or a
        sbc hl,de
        jr c,.right
        ld a,h
        or a
        ret nz
        ld a,l
        cp SW_W
        ret nc
        ld a,(ev_x)
        ld b,-1
.sw:
        inc b
        sub SW_W
        jr nc,.sw
        ld a,b
        jp set_colour
.right:
        ld a,(ev_x)                 ; a tool, or a layer?
        cp TOOL_X
        ret c
        ld a,(ev_y)
        sub LAY_Y
        jr nc,.layer
        ld a,(ev_y)
        sub TOOL_Y
        ret c
        ld b,-1
.tl:
        inc b
        sub TOOL_STEP
        jr nc,.tl
        ld a,b
        cp TOOLS
        ret nc
        jp set_tool
.layer:
        ld b,-1
.ly:
        inc b
        sub LAY_STEP
        jr nc,.ly
        ld a,(lmode)
        or a
        ret z
        ld a,b
        cp 3
        ret nc
        ld a,2                      ; from the top
        sub b
        ld e,a
        ld d,0
        ld hl,canvas + L_ORDER
        add hl,de
        ld a,(hl)
        jp choose

; the button down: PENCIL and BRUSH draw from where they were
ptr_move:
        ld a,(down)
        or a
        ret z
        ld a,(tool)
        cp T_LINE_
        ret nc
        call ptr_at
        call clamp
        ld a,c
        ld (lnx1),a
        ld a,b
        ld (lny1),a
        call line
        ld a,(lnx1)
        ld (lnx),a
        ld a,(lny1)
        ld (lny),a
        ret

; the button up: LINE and BOX end here
ptr_up:
        ld a,(down)
        or a
        ret z
        xor a
        ld (down),a
        call ptr_at
        call clamp
        ld a,(tool)
        cp T_LINE_
        ret c
        jp nz,box
        ld a,c
        ld (lnx1),a
        ld a,b
        ld (lny1),a
        ld a,(x0)
        ld (lnx),a
        ld a,(y0)
        ld (lny),a
        jp line

; C = x, B = y (from ptr_at, maybe outside): into the picture
clamp:
        ld hl,(ev_x)
        ld de,CX
        call .part
        ld c,a
        ld hl,(ev_y)
        ld de,CY
        call .part
        ld b,a
        ret
.part:
        or a
        sbc hl,de
        jr c,.zero
        ld a,h
        or a
        jr nz,.max
        ld a,l
        call pic_part
        ret nc
.max:
        ld a,(cw)
        dec a
        ret
.zero:
        xor a
        ret

set_tool:
        ld (tool),a
        jp draw_tools

set_colour:
        ld (colour),a
        cp ERASE
        jr nc,.erase
        ld e,a
        ld d,0
        ld hl,pen_bytes
        add hl,de
        ld a,(hl)
        ld (col_byte),a
.erase:
        jp draw_colours

; the picture changes: "*" by its name (BC kept)
changed:
        ld a,(modified)
        or a
        ret nz
        inc a
        ld (modified),a
        push bc
        call draw_name
        pop bc
        ret

; A = command (the menu)
command:
        cp CMD_NEW
        jr nz,.not_new
        call discard_ok
        ret nz
        call new_pic
        jp redraw
.not_new:
        cp CMD_NEW_L
        jr nz,.not_new_l
        call discard_ok
        ret nz
        call new_layers
        jp redraw
.not_new_l:
        cp CMD_OPEN
        ld b,0
        jp z,open
        cp CMD_OPEN_L
        ld b,1
        jp z,open
        cp CMD_SAVE
        jp z,save_pic
        cp CMD_SAVE_AS
        jp z,save_as
        cp CMD_EXPORT
        jp z,export
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,fdrive
        ld a,(hl)
        xor 1
        ld (hl),a
        jp draw_name
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

discard_ok:
        ld a,(modified)
        or a
        ret z
        ld hl,dlg_discard
        call VOS_DIALOG
        or a
        ret

; ---------------------------------------------------------------------
; the pixels
; ---------------------------------------------------------------------
; C = x, B = y -> HL -> its byte in a picture, A = its pixel's bits
pix_addr:
        ld a,b                      ; + 64 y
        add a,a
        ld de,canvas
        ; fall through
; A = row, DE = base: + 32 A
pix_row:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ; fall through
; HL = row offset, DE = base -> HL -> the byte of pixel C, A = its bits
pix_byte:
        add hl,de
        ld a,c
        srl a
        ld e,a
        ld d,0
        add hl,de
        ld a,c
        and 1
        ld a,#AA                    ; the left pixel
        ret z
        ld a,#55                    ; the right one
        ret

; A = layer, C = x, B = y -> HL -> its pixel's byte, A = the bits;
; maddr -> its mask byte, lbit = its bit there
lay_addr:
        add a,a
        ld e,a
        ld d,0
        ld hl,lbase
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (lb_cur),hl
        ld l,b                      ; the mask: + LPIX + 8 y + x / 8
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        rrca
        rrca
        rrca
        and 31
        ld e,a
        ld d,0
        add hl,de
        ld de,(lb_cur)
        add hl,de
        ld de,LPIX
        add hl,de
        ld (maddr),hl
        ld a,c
        and 7
        ld e,a
        ld d,0
        ld hl,bits
        add hl,de
        ld a,(hl)
        ld (lbit),a
        ld de,(lb_cur)              ; the pixel: + 32 y + x / 2
        ld a,b
        jr pix_row

; C = x, B = y: the colour there, in memory only (BC kept)
set_px:
        push bc
        ld a,(lmode)
        or a
        jr nz,.layer
        call pix_addr
.put:
        ld e,a
        cpl
        and (hl)
        ld d,a
        ld a,(col_byte)
        and e
        or d
        ld (hl),a
        pop bc
        ret
.layer:
        ld a,(cl)
        call lay_addr
        push af
        ld hl,(maddr)               ; the mask bit: on, or off for the
        ld a,(lbit)                 ; eraser
        ld e,a
        ld a,(colour)
        cp ERASE
        ld a,e
        jr z,.clear
        or (hl)
        ld (hl),a
        ld a,(cl)                   ; and the pixel
        call lay_addr
        pop de
        jr .put
.clear:
        cpl
        and (hl)
        ld (hl),a
        pop af
        pop bc
        ret

; C = x, B = y -> A = the pixel's bits as for the left one, or 1 if
; the layer lets the ones below show (BC, DE kept)
get_px:
        ld a,(lmode)
        or a
        ld a,(cl)
        jr nz,lay_get
        push bc
        push de
        call pix_addr
        jr norm
; A = layer
lay_get:
        push bc
        push de
        call lay_addr
        ld e,a
        ld a,(lbit)
        push hl
        ld hl,(maddr)
        and (hl)
        pop hl
        ld a,e
        jr nz,norm
        pop de
        pop bc
        ld a,1
        ret
norm:
        and (hl)
        bit 0,c
        jr z,.left
        add a,a
.left:
        pop de
        pop bc
        ret

; C = x, B = y -> A = what shows there through the layers, as for the
; left pixel (white if nothing) (BC, DE kept)
comp:
        push de
        ld e,3
        ld hl,canvas + L_ORDER + 2
.layer:
        push hl
        push de
        ld a,(hl)
        ld e,a
        ld d,0
        ld hl,canvas + L_VIS
        add hl,de
        ld d,(hl)
        inc d
        dec d
        jr z,.next
        call lay_get
        cp 1
        jr nz,.found
.next:
        pop de
        pop hl
        dec hl
        dec e
        jr nz,.layer
        pop de
        ld a,#80                    ; pen 1
        ret
.found:
        pop de
        pop hl
        pop de
        ret

; the colour FILL puts, as get_px gives it
cur_code:
        ld a,(colour)
        cp ERASE
        ld a,1
        ret z
        ld a,(col_byte)
        and #AA
        ret

; ---------------------------------------------------------------------
; drawing
; ---------------------------------------------------------------------
; C = x, B = y: a pixel, if in the picture, in memory and on the screen
put:
        ld a,(cw)
        ld d,a
        ld a,c
        cp d
        ret nc
        ld a,b
        cp d
        ret nc
        call set_px
        push bc
        ld a,(lmode)
        or a
        jr nz,.big
        ld a,c
        add a,CX
        ld l,a
        ld h,0
        ld a,b
        add a,CY
        ld e,a
        ld d,0
        ld a,(colour)
        call VOS_PLOT
        pop bc
        ret
.big:
        call comp                   ; 2 x 2 on the screen: one byte, two
        ld e,a                      ; rows
        srl a
        or e
        ld (dot_pairs + 1),a
        ld (dot_pairs + 3),a
        ld a,c
        add a,a
        add a,CX
        ld (dblt),a
        ld a,b
        add a,a
        add a,CY
        ld (dblt + 2),a
        push ix
        ld ix,dblt
        call VOS_BLIT
        pop ix
        pop bc
        ret

; C = x, B = y: PENCIL a pixel, BRUSH 3 x 3
dot:
        ld a,(tool)
        cp T_BRUSH_
        jr nz,put
        dec b
        dec c
        ld e,3
.row:
        ld d,3
.col:
        push de
        call put
        pop de
        inc c
        dec d
        jr nz,.col
        dec c
        dec c
        dec c
        inc b
        dec e
        jr nz,.row
        ret

; a line from lnx, lny to lnx1, lny1, a dot at each point (Bresenham)
line:
        ld a,(lnx1)
        ld hl,lnx
        sub (hl)
        ld b,1
        jr nc,.dx
        neg
        ld b,-1
.dx:
        ld l,a
        ld h,0
        ld (ldx),hl
        ld a,b
        ld (lsx),a
        ld a,(lny1)
        ld hl,lny
        sub (hl)
        ld b,1
        jr nc,.dy
        neg
        ld b,-1
.dy:
        ld l,a                      ; ldy = -|dy|
        ld h,0
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        ld (ldy),hl
        ld a,b
        ld (lsy),a
        ld de,(ldx)
        add hl,de
        ld (lerr),hl
.point:
        ld a,(lnx)
        ld c,a
        ld a,(lny)
        ld b,a
        call dot
        ld a,(lnx)
        ld hl,lnx1
        cp (hl)
        jr nz,.on
        ld a,(lny)
        ld hl,lny1
        cp (hl)
        ret z
.on:
        ld hl,(lerr)                ; e2 = 2 err
        add hl,hl
        ld (le2),hl
        ld de,(ldy)                 ; e2 >= dy: a step in x
        or a
        sbc hl,de
        bit 7,h
        jr nz,.no_x
        ld hl,(lerr)
        add hl,de
        ld (lerr),hl
        ld a,(lsx)
        ld hl,lnx
        add a,(hl)
        ld (hl),a
.no_x:
        ld hl,(ldx)                 ; e2 <= dx: a step in y
        ld de,(le2)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.point
        ld hl,(lerr)
        ld de,(ldx)
        add hl,de
        ld (lerr),hl
        ld a,(lsy)
        ld hl,lny
        add a,(hl)
        ld (hl),a
        jr .point

; BOX: filled, from x0, y0 to C, B; all drawn again
box:
        ld a,(x0)                   ; the left and right
        cp c
        jr c,.xs
        ld d,a
        jr .xd
.xs:
        ld d,c
        ld c,a
.xd:
        ld a,c
        ld (bx0),a
        ld a,d
        ld (bx1),a
        ld a,(y0)                   ; the top and bottom
        cp b
        jr c,.ys
        ld d,a
        jr .yd
.ys:
        ld d,b
        ld b,a
.yd:
        ld a,d
        ld (by1),a
.row:                               ; in memory, then on the screen
        ld a,(bx0)
        ld c,a
.col:
        call set_px
        ld a,(bx1)
        cp c
        jr z,.next
        inc c
        jr .col
.next:
        ld a,(by1)
        cp b
        jr z,.screen
        inc b
        jr .row
.screen:
        jp draw_canvas

; FILL at C, B: the pixels like it joined to it, a row at a time (a
; stack of places still to look at), then the picture drawn again
fill:
        call get_px
        ld (target),a
        ld e,a
        call cur_code
        cp e
        ret z
        call changed
        ld hl,fstack
        ld (fsp),hl
        call fpush
.next:
        call fpop
        jp c,draw_canvas
        call is_target
        jr nz,.next
.left:
        ld a,c
        or a
        jr z,.lset
        dec c
        call is_target
        jr z,.left
        inc c
.lset:
        ld a,c
        ld (fxl),a
.right:
        ld a,(cw)
        dec a
        cp c
        jr z,.rset
        inc c
        call is_target
        jr z,.right
        dec c
.rset:
        ld a,c
        ld (fxr),a
        ld a,(fxl)
        ld c,a
.paint:
        call set_px
        ld a,(fxr)
        cp c
        jr z,.painted
        inc c
        jr .paint
.painted:
        ld a,b
        or a
        jr z,.below
        dec b
        call .scan
        inc b
.below:
        ld a,(cw)
        dec a
        cp b
        jr z,.next
        inc b
        call .scan
        dec b
        jr .next
; row B, from fxl to fxr: the first pixel of each run like it
.scan:
        ld a,(fxl)
        ld c,a
        ld d,0
.look:
        call is_target
        jr nz,.no
        ld a,d
        or a
        jr nz,.more
        call fpush
        ld d,1
        jr .more
.no:
        ld d,0
.more:
        ld a,(fxr)
        cp c
        ret z
        inc c
        jr .look

; C, B -> Z if like the pixel FILL started at (BC, DE kept)
is_target:
        call get_px
        push hl
        ld hl,target
        cp (hl)
        pop hl
        ret

; C, B on the stack (if there is room); all kept
fpush:
        push hl
        push de
        ld hl,(fsp)
        ld de,fstack + 2 * FILL_MAX
        or a
        sbc hl,de
        jr nc,.full
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (fsp),hl
.full:
        pop de
        pop hl
        ret

; -> C, B from the stack; carry if it is empty
fpop:
        ld hl,(fsp)
        ld de,fstack
        or a
        sbc hl,de
        scf
        ret z
        add hl,de
        dec hl
        ld b,(hl)
        dec hl
        ld c,(hl)
        ld (fsp),hl
        or a
        ret

; ---------------------------------------------------------------------
; the screen
; ---------------------------------------------------------------------
; the picture, a row at a time (VOS_BLIT: mask and pixels); layers:
; each pixel a byte, each row twice
draw_canvas:
        ld a,(lmode)
        or a
        jr nz,.layers
        ld hl,canvas
        ld b,0
.row:
        push bc
        ld de,row_pairs
        ld b,64
.pair:
        ld a,#FF
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        djnz .pair
        pop bc
        push hl
        ld a,b
        add a,CY
        call .blit
        pop hl
        inc b
        ld a,b
        cp 128
        jr c,.row
        ret
.layers:
        ld b,0
.lrow:
        ld c,0
        ld de,row_pairs
.lpx:
        call comp
        ld h,a
        srl a
        or h
        ld h,a
        ld a,#FF
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        inc c
        ld a,c
        cp 64
        jr c,.lpx
        ld a,b
        add a,a
        add a,CY
        push af
        call .blit
        pop af
        inc a
        call .blit
        inc b
        ld a,b
        cp 64
        jr c,.lrow
        ret
; A = y: row_pairs there (BC kept); for EXPORT, its pixels into the
; data bank at scr_at, the next line after it
.blit:
        ld (blt + 2),a
        push bc
        ld hl,(scr_at)
        ld a,h
        or a
        jr nz,.scr
        push ix
        ld ix,blt
        call VOS_BLIT
        pop ix
        pop bc
        ret
.scr:
        ld hl,row_pairs + 1         ; the pixels, every other byte, to
        ld de,(scr_at)              ; the data bank, one at a time
        ld b,64
.byte:
        push bc
        push hl
        push de
        ld bc,1
        call VOS_BANK_PUT
        pop de
        inc de
        pop hl
        inc hl
        inc hl
        pop bc
        djnz .byte
        ld hl,(scr_at)              ; the next screen line: + #800, or
        ld a,h                      ; + 80 - #3800 after the eighth
        add a,8
        ld h,a
        and #38
        jr nz,.next
        ld a,l
        add a,80
        ld l,a
        ld a,h
        adc a,#C0
        ld h,a
.next:
        ld (scr_at),hl
        pop bc
        ret

; the tools, the chosen one on yellow
draw_tools:
        xor a
.tool:
        push af
        ld c,a
        ld a,(tool)
        cp c
        call bg_for
        ld a,c                      ; y = TOOL_Y + 16 n
        add a,a
        add a,a
        add a,a
        add a,a
        add a,TOOL_Y
        ld e,a
        ld d,0
        ld a,c
        add a,T_PENCIL
        ld hl,TOOL_X
        ld c,7
        call print_lab
        pop af
        inc a
        cp TOOLS
        jr c,.tool
        or a                        ; (NZ: grey again)
        ; fall through
; Z: the background yellow, NZ grey
bg_for:
        ld a,UI_BG
        jr nz,.bg
        ld a,SEL_BG
.bg:
        ld (lab_bg),a
        ret

; with layers: them, from the top, "2 ON", the chosen one on yellow
draw_layers:
        ld a,(lmode)
        or a
        ret z
        ld b,2
.layer:
        push bc
        ld e,b
        ld d,0
        ld hl,canvas + L_ORDER
        add hl,de
        ld a,(hl)                   ; this layer
        ld hl,cl
        cp (hl)
        push af
        call bg_for
        pop af
        ld e,a
        add a,"1"
        ld l,a
        ld h," "                    ; (lay_text is in icon_ram)
        ld (lay_text),hl
        ld hl,canvas + L_VIS
        add hl,de
        ld a,(hl)
        add a,T_OFF
        ld c,5
        ld de,lay_text + 2
        call copy_msg
        pop bc
        push bc
        ld a,2                      ; y = LAY_Y + 12 (2 - place)
        sub b
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,a
        add a,LAY_Y
        ld e,a
        ld d,0
        ld hl,TOOL_X
        ld bc,lay_text
        call print_at
        pop bc
        dec b
        jp p,.layer
        ld a,1                      ; (NZ: grey again)
        or a
        jr bg_for

; the 16 colours, a mark on the chosen one
draw_colours:
        push ix
        ld ix,rect
        xor a
.sw:
        push af
        ld (rect + 8),a
        ld l,a                      ; x = 12 n
        add a,a
        add a,l
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld (rect),hl
        ld hl,SW_Y
        ld (rect + 2),hl
        ld hl,SW_W
        ld (rect + 4),hl
        ld (rect + 6),hl
        call VOS_RECT
        pop af
        push af
        ld hl,colour
        cp (hl)
        jr nz,.done
        ld hl,(rect)                ; the mark: a small square in the
        inc hl                      ; middle, black or (on black) white
        inc hl
        inc hl
        inc hl
        ld (rect),hl
        ld hl,SW_Y + 4
        ld (rect + 2),hl
        ld hl,4
        ld (rect + 4),hl
        ld (rect + 6),hl
        or a
        ld a,0
        jr nz,.mark
        inc a
.mark:
        ld (rect + 8),a
        call VOS_RECT
.done:
        pop af
        inc a
        cp 16
        jr c,.sw
        pop ix
        ret

; A:NAME.PIC, and "*" if not saved
draw_name:
        ld de,lbuf
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
        ld hl,0
        ld de,NAME_Y
        ld bc,lbuf
        jr print_at

; A = text, DE -> where, C = width: it, then spaces to the width, 0
copy_msg:
        push de
        push bc
        call VOS_MSG
        pop bc
        pop de
        ld b,c
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
        ret

; A = text, HL = x, DE = y, C = width: on lab_bg (black on the yellow,
; else white)
print_lab:
        push hl
        push de
        ld de,lbuf
        call copy_msg
        pop de
        pop hl
        ld bc,lbuf
        ; fall through
; HL = x, DE = y, BC -> text: on lab_bg
print_at:
        push hl
        push de
        push bc
        ld a,(lab_bg)
        ld c,a
        cp SEL_BG
        ld a,1
        jr nz,.ink
        xor a
.ink:
        call VOS_COLOURS
        pop bc
        pop de
        pop hl
        jp VOS_PRINT

; ---------------------------------------------------------------------
; files
; ---------------------------------------------------------------------
; B = 0 OPEN a .PIC, 1 OPEN LAYERS a .LYR of fdrive, through the data
; bank, if of its size
open:
        push bc
        call discard_ok
        pop bc
        ret nz
        ld a,b
        ld (open_mode),a
        ld hl,ext_pic
        or a
        jr z,.ext
        ld hl,ext_lyr
.ext:
        ld a,(fdrive)
        or VOS_CAT_EXT
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
        ld de,name_tmp
        ld bc,11
        ldir
load_file:                          ; name_tmp on fdrive, open_mode
        ld a,(fdrive)
        or VOS_DATA
        ld hl,name_tmp
        ld de,#4000
        call VOS_LOAD
        jp c,VOS_ERROR
        ld a,(open_mode)
        ld hl,PIC_SIZE
        or a
        jr z,.size
        ld hl,LYR_SIZE
.size:
        push hl
        or a
        sbc hl,bc
        pop bc
        ld hl,dlg_not_pic
        jp nz,VOS_DIALOG
        ld hl,#4000
        ld de,canvas
        call VOS_BANK_GET
        ld a,(open_mode)
        call set_mode
        ld hl,name_tmp
        ld de,fname
        ld bc,11
        ldir
        jp redraw

; SAVE: as NONAME it asks for a name first
save_pic:
        ld hl,fname
        ld de,noname
        ld b,8
.same:
        ld a,(de)
        cp (hl)
        jr nz,write
        inc hl
        inc de
        djnz .same
        ; fall through

save_as:
        ld hl,fname
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
        cp "a"
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
        push de
        call ext_now
        pop de
        ld bc,3
        ldir
        ; fall through

write:
        ld bc,PIC_SIZE
        ld a,(lmode)
        or a
        jr z,.size
        ld bc,LYR_SIZE
.size:
        ld a,(fdrive)
        ld hl,fname
        ld de,canvas
        call VOS_SAVE
        jp c,VOS_ERROR
        xor a
        ld (modified),a
        jp draw_name

; EXPORT .SCR: the picture (layers: as they show) as a CPC screen, a
; 16K file that loads at #C000 (mode 0, 160 x 200), in the middle of
; pen 0, with the palette (16 pens, the border) in the unused bytes at
; #C7D0; NAME.SCR on fdrive. Built in the data bank by draw_canvas,
; whose rows go there instead of to the screen meanwhile (scr_at).
export:
        ld hl,row_pairs             ; pen 0 everywhere: 128 x 128 bytes
        ld (hl),0                   ; (row_pairs is free here)
        ld de,row_pairs + 1
        ld bc,127
        ldir
        ld de,SCR_DATA
.clear:
        ld hl,row_pairs
        ld bc,128
        push de
        push bc
        call VOS_BANK_PUT
        pop bc
        pop hl
        add hl,bc
        ex de,hl
        bit 7,d                     ; up to #8000
        jr z,.clear
        ld hl,SCR_DATA + (SCR_Y >> 3) * 80 + (SCR_Y & 7) * #800 + SCR_X
        ld (scr_at),hl
        call draw_canvas
        xor a                       ; (H = 0: none)
        ld (scr_at + 1),a
        ld hl,palette               ; the palette
        ld de,SCR_DATA + #07D0
        ld bc,17
        call VOS_BANK_PUT
        ld hl,fname                 ; NAME.SCR
        ld de,name_tmp
        ld bc,8
        ldir
        ld hl,ext_scr
        ld c,3
        ldir
        ld a,(fdrive)
        or VOS_DATA + VOS_LOAD_IX
        ld hl,name_tmp
        ld de,SCR_DATA
        ld bc,#4000
        push ix
        ld ix,#C000
        call VOS_SAVE
        pop ix
        jp c,VOS_ERROR
        ld hl,dlg_exported
        jp VOS_DIALOG

; ---- data -----------------------------------------------------------
; black, white, blue, red, green, yellow, cyan, magenta, orange, grey,
; dark red, dark green, dark blue, olive, pink, sky blue; the border
palette:        db 0, 26, 2, 6, 18, 24, 20, 8, 15, 13, 3, 9, 1, 12, 17, 11
                db 13
; each pen in both pixels of a byte
pen_bytes:      db #00, #C0, #0C, #CC, #30, #F0, #3C, #FC
                db #03, #C3, #0F, #CF, #33, #F3, #3F, #FF
bits:           db 128, 64, 32, 16, 8, 4, 2, 1
lbase:          dw canvas, canvas + LAYER, canvas + 2 * LAYER
layers0:        db 0, 1, 2, 1, 1, 1 ; new layers: the order, all shown
tool_keys:      db "pblxf"

bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 11
                db T_NEW, CMD_NEW, 0, 0
                db T_NEW_L, CMD_NEW_L, 0, 0
                db T_OPEN, CMD_OPEN, "O", 0
                db T_OPEN_L, CMD_OPEN_L, 0, 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_SAVE_AS, CMD_SAVE_AS, 0, 0
                db T_EXPORT, CMD_EXPORT, 0, 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_exported:   db T_MENU, T_EXPORTED, 1, VM_OK
dlg_discard:    db T_MENU, T_DISCARD, 2, VM_YES, VM_NO
dlg_not_pic:    db T_MENU, T_NOT_PIC, 1, VM_OK
noname:         db "NONAME  "
ext_pic:        db "PIC"            ; (ext_now: then "LYR")
ext_lyr:        db "LYR"
ext_scr:        db "SCR"
frame_rect:     dw CX - 2, CY - 2, 132, 132
                db 0
sw_frame:       dw 0, SW_Y - 2, 192, SW_W + 4
                db 0
blt:            dw CX, 0            ; VOS_BLIT: a row of the picture
                db 64, 1
                dw row_pairs
                db 128
dblt:           dw 0, 0             ; a pixel of layers: 2 x 2
                db 1, 2
                dw dot_pairs
                db 2
dot_pairs:      db #FF, 0, #FF, 0

        include "app_texts.asm"     ; texts, from texts.txt

lmode:          db 0                ; 0 a picture, 1 layers
cw:             db 128              ; its width and height
cl:             db 1                ; the layer drawn on
tool:           db T_PENCIL_
colour:         db 0                ; black, at first
col_byte:       db #00
lab_bg:         db UI_BG
fdrive:         db 0
scr_at:         dw 0                ; EXPORT: the next line (0: none)
open_mode:      db 0
fname:          ds 11
modified:       db 0
down:           db 0                ; the button is down on the picture
ev_x:           dw 0
ev_y:           dw 0
x0:             db 0                ; where it went down
y0:             db 0
lnx:            db 0                ; line: from, to, steps, error
lny:            db 0
lnx1:           db 0
lny1:           db 0
lsx:            db 0
lsy:            db 0
ldx:            dw 0
ldy:            dw 0
lerr:           dw 0
le2:            dw 0
bx0:            db 0                ; box
bx1:            db 0
by1:            db 0
lb_cur:         dw 0
maddr:          dw 0
lbit:           db 0
target:         db 0
fxl:            db 0
fxr:            db 0
fsp:            dw 0
cat:            dw 0
rect:           dw 0, 0, 0, 0
                db 0
canvas:         ds PIC_SIZE

; =====================================================================
; paint.asm - PAINT, a drawing program for V-OS (made with the SDK)
;
; Mode 0, 16 colours. Two kinds of picture:
;   a picture   the CPC's whole screen, 160 x 200 pixels without the
;               overscan, in the data bank as a screen is (lines of 80
;               bytes, two pixels a byte, 8 blocks of #800): saved as a
;               .SCR that loads at #C000, the palette in its unused
;               bytes at #C7D0. That needs a data bank of PAINT's own
;               (a memory expansion, VX_DATA); without one, 128 x 128
;               here (.PIC, 8192 bytes; EXPORT makes it a .SCR)
;   layers      64 x 64 pixels shown twice as big, in three layers,
;               in the same 8K here.
;               Each has its pixels (2048 bytes) and a mask (512: a bit
;               a pixel, 0 where it lets the ones below show); then the
;               order of the layers, from the bottom, and which are
;               shown (.LYR, 7686 bytes). A pixel no layer shows is
;               white.
; The window shows 128 x 128 of it; the bars on its right and under it
; show which part, and move it (a click, or the button held down: the
; window's middle goes there). Under the colours: where the pointer is
; in the picture, and the window's top left (VIEW).
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
;   AS, OTHER DRIVE (A: or B:), UNDO ^Z, ABOUT, BACK ^Q
; UNDO takes back the last tool: before each, the picture is kept (the
; 8K of a picture or of layers in the data bank; of the whole screen,
; the window's 128 x 128 here, in canvas, which it does not use), and
; UNDO swaps it with the picture, so UNDO again does it again. FILL on
; the whole screen may go past the window: no UNDO for it. The data
; bank may have been another program's meanwhile (a 6128 shares it):
; nothing to undo after PAINT is back.
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
CX              equ 0               ; the window on the screen
CY              equ 16
VW              equ 128             ; its size, in screen pixels
VH              equ 128
BAR_W           equ 4               ; the scroll bars: their width
VBAR_X          equ CX + VW + 2
HBAR_Y          equ CY + VH + 2
TOOL_X          equ 136
TOOL_Y          equ 20
TOOL_STEP       equ 16
LAY_Y           equ 110             ; the layers, from the top
LAY_STEP        equ 12
SW_Y            equ 154             ; the colours
SW_W            equ 12
NAME_Y          equ 170
POS_Y           equ 180             ; the pointer's place, the window's
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
CMD_UNDO        equ VC_APP + 11
SCR_DATA        equ #4000           ; the screen, in the data bank (EXPORT,
                                    ; or the picture itself)
SCR_SIZE        equ #4000
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
        ld a,VX_DATA                ; a data bank of its own: the whole
        call VOS_EXT                ; screen
        jr c,.small
        ld (big),a
.small:
        call new_pic
.back:
        xor a                       ; nothing to undo (see above)
        ld (u_ok),a
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
        call draw_bars
        call draw_tools
        call draw_layers
        call draw_colours
        call draw_name
        call show_pos
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

; a white picture, NONAME.PIC (or .SCR)
new_pic:
        call rc_none
        ld a,(big)
        or a
        jr z,.small
        ld hl,row_pairs             ; the screen in the data bank
        ld de,row_pairs + 1
        ld bc,127
        ld (hl),#C0
        ldir
        ld de,SCR_DATA
.fill:
        push de
        ld hl,row_pairs
        ld bc,128
        call VOS_BANK_PUT
        pop hl
        ld de,128
        add hl,de
        ex de,hl
        bit 7,d                     ; up to #8000
        jr z,.fill
        jr .white
.small:
        ld hl,canvas
        ld de,canvas + 1
        ld bc,PIC_SIZE - 1
        ld (hl),#C0                 ; pen 1 in both pixels
        ldir
.white:
        xor a
        ; fall through

; A = 0 a picture, 1 layers: NONAME, as new
set_mode:
        ld (lmode),a
        ld hl,u_ok
        ld (hl),0
        or a
        ld hl,64 * 256 + 64         ; layers
        jr nz,.size
        ld hl,128 * 256 + 128
        ld a,(big)
        or a
        jr z,.size
        ld hl,200 * 256 + 160       ; the whole screen
.size:
        ld (pw),hl
        xor a                       ; the window at the top left
        ld (vx),a
        ld (vy),a
        ld (sdrag),a
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
        jp set_mode

; -> HL -> "PIC", "SCR" (the whole screen) or "LYR"
ext_now:
        ld hl,ext_lyr
        ld a,(lmode)
        or a
        ret nz
pic_ext:
        ld hl,ext_pic
        ld a,(big)
        or a
        ret z
        ld hl,ext_scr
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
        ; fall through
; ev_x, ev_y -> C = x, B = y in the picture; carry if not in the window
ev_pic:
        ld hl,(ev_x)
        ld de,CX
        call .part
        ret c
        ld hl,vx
        call view_pic
        push af
        ld hl,(ev_y)
        ld de,CY
        call .part
        jr c,.out
        ld hl,vy
        call view_pic
        ld b,a
        pop af
        ld c,a
        or a
        ret
.out:
        pop af
        scf
        ret
; HL - DE -> A, in the window; carry if outside
.part:
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        scf
        ret nz
        ld a,l
        cp VW
        ccf
        ret

; A = place in the window, HL -> vx or vy -> A = in the picture
view_pic:
        call half
        add a,(hl)
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
        jr c,.bar
        ld a,c
        ld (x0),a
        ld (lnx),a
        ld a,b
        ld (y0),a
        ld (lny),a
        ld a,(tool)
        cp T_FILL_
        jp z,fill
        push bc
        call u_keep
        pop bc
        ld a,1
        ld (down),a
        call changed
        ld a,(tool)
        cp T_LINE_
        ret nc                      ; LINE, BOX: when it comes up
        jp dot
.bar:
        call bar_at                 ; a scroll bar?
        ret nc
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

; the pointer's place shown; a scroll bar held follows it; the button
; down: PENCIL and BRUSH draw from where they were
ptr_move:
        call ptr_at
        call show_pos
        ld a,(sdrag)
        or a
        jp nz,bar_move
        ld a,(down)
        or a
        ret z
        ld a,(tool)
        cp T_LINE_
        ret nc
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
        xor a
        ld (sdrag),a
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

; C = x, B = y (ev_x, ev_y, maybe outside): the nearest in the window
clamp:
        ld hl,(ev_x)
        ld de,CX
        call view_part
        ld hl,vx
        call view_pic
        ld c,a
        ld hl,(ev_y)
        ld de,CY
        call view_part
        ld hl,vy
        call view_pic
        ld b,a
        ret

; HL - DE -> A, 0 to VW - 1 (the window is square)
view_part:
        or a
        sbc hl,de
        jr c,.zero
        ld a,h
        or a
        jr nz,.max
        ld a,l
        cp VW
        ret c
.max:
        ld a,VW - 1
        ret
.zero:
        xor a
        ret

; ---------------------------------------------------------------------
; the scroll bars and the window
; ---------------------------------------------------------------------
; ev_x, ev_y on a bar: it is held (sdrag 1 the one on the right, 2 the
; one below) and the window moves; else carry
bar_at:
        ld hl,(ev_y)                ; below?
        ld de,HBAR_Y
        or a
        sbc hl,de
        jr c,.right
        ld a,h
        or a
        jr nz,.right
        ld a,l
        cp BAR_W
        jr nc,.right
        ld hl,(ev_x)
        ld a,h
        or a
        jr nz,.right
        ld a,l
        cp CX + VW
        ld a,2
        jr c,.held
.right:
        ld hl,(ev_x)
        ld de,VBAR_X
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        scf
        ret nz
        ld a,l
        cp BAR_W
        ccf
        ret c
        ld hl,(ev_y)
        ld de,CY
        or a
        sbc hl,de
        ret c
        ld a,h
        or a
        scf
        ret nz
        ld a,l
        cp VH
        ccf
        ret c
        ld a,1
.held:
        ld (sdrag),a
        call bar_move
        or a
        ret

; the bar held: the window's middle where the pointer is along it
bar_move:
        ld a,(sdrag)
        dec a
        jr nz,.below
        ld hl,(ev_y)
        ld de,CY
        call view_part
        ld hl,ph
        ld d,(hl)
        ld hl,vy
        jr .move
.below:
        ld hl,(ev_x)
        ld de,CX
        call view_part
        ld hl,pw
        ld d,(hl)
        ld hl,vx
.move:
        call scroll_to
        ret z
        call draw_canvas
        call draw_bars
        jp show_pos

; A = place on a bar (0..127), D = the picture's size that way, HL ->
; vx or vy: there, so that the window's middle is at A (even, and
; inside the picture) -> NZ if it moved
scroll_to:
        push hl
        ld e,a
        ld a,VW                     ; the part the bar shows, by half
        call scale
        srl a
        ld b,a
        ld a,e
        sub b
        jr nc,.from
        xor a
.from:
        ld e,d                      ; A * size / 128
        call mul8
        add hl,hl
        ld c,h
        ld a,d                      ; at most size - 128
        sub VW
        jr nc,.most
        xor a
.most:
        cp c
        jr nc,.in
        ld c,a
.in:
        res 0,c
        pop hl
        ld a,c
        cp (hl)
        ret z
        ld (hl),a
        ret

; A = a place in the picture, D = its size -> A = on a bar, A * 128 /
; D, at most 128 (D kept)
scale:
        ld h,a
        ld l,0
        srl h
        rr l
        ld c,d
        call div_hl_c
        ld a,h
        or a
        jr nz,.most
        ld a,l
        cp VW + 1
        ret c
.most:
        ld a,VW
        ret

; HL = HL / C (C not 0); B lost
div_hl_c:
        ld b,16
        xor a
.bit:
        add hl,hl
        rla
        jr c,.sub
        cp c
        jr c,.next
.sub:
        sub c
        inc l
.next:
        djnz .bit
        ret

; HL = A * E (DE kept); B lost
mul8:
        push de
        ld d,0
        ld hl,0
        ld b,8
.bit:
        add hl,hl
        rla
        jr nc,.next
        add hl,de
.next:
        djnz .bit
        pop de
        ret

; the bars: grey, and yellow the part of the picture the window shows
draw_bars:
        push ix
        ld ix,rect
        ld hl,VBAR_X                ; on the right: the rows
        ld de,CY
        ld bc,BAR_W + VH * 256
        call .track
        ld a,(ph)
        ld d,a
        ld a,(vy)
        call scale
        add a,CY
        ld (rect + 2),a
        ld a,VW
        call scale
        ld (rect + 6),a
        call .part
        ld hl,CX                    ; below: the columns
        ld de,HBAR_Y
        ld bc,VW + BAR_W * 256
        call .track
        ld a,(pw)
        ld d,a
        ld a,(vx)
        call scale
        add a,CX
        ld (rect),a
        ld a,VW
        call scale
        ld (rect + 4),a
        call .part
        pop ix
        ret
; HL = x, DE = y, C = width, B = height: the track
.track:
        ld (rect),hl
        ld (rect + 2),de
        ld a,c
        ld (rect + 4),a
        ld a,b
        ld (rect + 6),a
        xor a
        ld (rect + 5),a
        ld (rect + 7),a
        ld a,UI_BG
        ld (rect + 8),a
        jp VOS_RECT
.part:
        ld a,SEL_BG
        ld (rect + 8),a
        jp VOS_RECT

; under the colours: the pointer's place in the picture ("---,---" off
; the window) and the window's top left
show_pos:
        call ev_pic
        ld de,lbuf
        jr c,.off
        ld a,c
        call num3
        ld a,","
        ld (de),a
        inc de
        ld a,b
        call num3
        jr .view
.off:
        ld hl,no_pos
        ld bc,7
        ldir
.view:
        ld a," "
        ld (de),a
        inc de
        ld (de),a
        inc de
        push de
        ld a,T_VIEW
        call VOS_MSG
        pop de
.word:
        ld a,(hl)
        or a
        jr z,.at
        ld (de),a
        inc hl
        inc de
        jr .word
.at:
        ld a," "
        ld (de),a
        inc de
        ld a,(vx)
        call num3
        ld a,","
        ld (de),a
        inc de
        ld a,(vy)
        call num3
        ld b,3                      ; over what was longer
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
        xor a
        ld (de),a
        ld hl,0
        ld de,POS_Y
        ld bc,lbuf
        jp print_at

; A -> three digits at DE (BC kept)
num3:
        push bc
        ld b,"0" - 1
.hundreds:
        inc b
        sub 100
        jr nc,.hundreds
        add a,100
        ld c,a
        ld a,b
        ld (de),a
        inc de
        ld a,c
        ld b,"0" - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,"0" + 10
        ld c,a
        ld a,b
        ld (de),a
        inc de
        ld a,c
        ld (de),a
        inc de
        pop bc
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
        cp CMD_UNDO
        jp z,undo
        cp CMD_DRIVE
        jr nz,.not_drive
        ld hl,fdrive
        call vos_next_drive
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

; ---------------------------------------------------------------------
; UNDO
; ---------------------------------------------------------------------
; the picture kept, before a tool
u_keep:
        call rc_flush
        ld a,1
        ld (u_ok),a
        ld a,(big)
        or a
        jr nz,.screen
        ld hl,canvas                ; the 8K into the data bank
        ld de,SCR_DATA
        ld bc,PIC_SIZE
        jp VOS_BANK_PUT
.screen:
        ld hl,(vx)                  ; the window's 128 rows of 64 bytes
        ld (u_vx),hl                ; into canvas
        ld hl,canvas
        ld (u_at),hl
        ld b,0
.row:
        call u_row                  ; -> HL in the data bank, B kept
        ret c
        push bc
        ld de,(u_at)
        ld bc,64
        call VOS_BANK_GET
        pop bc
        call u_next
        jr nz,.row
        ret

; B = a row of the window kept -> HL = its bytes in the data bank, at
; u_vx, u_vy; carry past the picture's end
u_row:
        ld a,(u_vy)
        add a,b
        cp 200
        ccf
        ret c
        push bc
        ld b,a
        call row_addr
        ld a,(u_vx)
        srl a
        ld e,a
        ld d,0
        add hl,de
        pop bc
        or a
        ret
; the next row: u_at on, B on -> NZ while there are more
u_next:
        ld hl,(u_at)
        ld de,64
        add hl,de
        ld (u_at),hl
        inc b
        ld a,b
        sub 128
        ret

; ^Z: the picture kept and the picture swapped
undo:
        ld a,(u_ok)
        or a
        ret z
        call rc_flush
        call rc_none
        ld a,(big)
        or a
        jr nz,.screen
        ld hl,canvas                ; 8K, 128 bytes at a time
        ld (u_at),hl
        ld de,SCR_DATA
.chunk:
        push de
        ex de,hl
        ld de,row_pairs
        ld bc,128
        call VOS_BANK_GET           ; what was kept, aside
        pop de
        push de
        ld hl,(u_at)
        ld bc,128
        call VOS_BANK_PUT           ; the picture there
        ld hl,row_pairs
        ld de,(u_at)
        ld bc,128
        ldir                        ; and what was kept here
        ld (u_at),de
        pop hl
        ld de,128
        add hl,de
        ex de,hl
        ld hl,(u_at)
        ld bc,canvas + PIC_SIZE
        or a
        sbc hl,bc
        jr c,.chunk
        jr .done
.screen:
        ld hl,canvas
        ld (u_at),hl
        ld b,0
.row:
        call u_row
        jr c,.done
        push bc
        push hl
        ld de,row_pairs             ; the row there, aside
        ld bc,64
        call VOS_BANK_GET
        pop de
        push de
        ld hl,(u_at)                ; the kept one there
        ld bc,64
        call VOS_BANK_PUT
        pop hl
        ld hl,row_pairs             ; and the other kept
        ld de,(u_at)
        ld bc,64
        ldir
        pop bc
        call u_next
        jr nz,.row
.done:
        call changed
        jp draw_canvas

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
; The picture is read and written a row at a time, through rbuf
; (rc_y: which, rc_dirty: changed since; rc_flush writes it back).
; C = x, B = y -> HL -> its byte in a picture, A = its pixel's bits
pix_addr:
        call rc_load
        ld hl,0
        ld de,rbuf
        jp pix_byte

; B = row -> HL -> it in the picture: the screen in the data bank
; (#4000 + #800 (y and 7) + 80 (y / 8)), or canvas + 64 y
row_addr:
        ld a,(big)
        or a
        jr z,.small
        ld a,b
        rrca
        rrca
        rrca
        and 31
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld a,b
        and 7
        add a,a
        add a,a
        add a,a
        add a,SCR_DATA >> 8
        add a,h
        ld h,a
        ret
.small:
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,canvas
        add hl,de
        ret

; -> BC = a row's bytes
row_len:
        ld bc,64
        ld a,(big)
        or a
        ret z
        ld c,80
        ret

; B = row: in rbuf, the one there written back first (BC kept)
rc_load:
        ld a,(rc_y)
        cp b
        ret z
        push bc
        call rc_flush
        pop bc
        push bc
        ld a,b
        ld (rc_y),a
        call row_addr
        ld de,rbuf
        call row_len
        ld a,(big)
        or a
        jr z,.ram
        call VOS_BANK_GET
        pop bc
        ret
.ram:
        ldir
        pop bc
        ret

; rbuf back to its row, if it changed
rc_flush:
        ld a,(rc_dirty)
        or a
        ret z
        xor a
        ld (rc_dirty),a
        ld a,(rc_y)
        ld b,a
        call row_addr
        ex de,hl
        ld hl,rbuf
        call row_len
        ld a,(big)
        or a
        jp nz,VOS_BANK_PUT
        ldir
        ret

; no row in rbuf (the picture is new)
rc_none:
        ld a,#FF
        ld (rc_y),a
        xor a
        ld (rc_dirty),a
        ret

; A = row, DE = base: + 32 A (layers)
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
        ld e,a
        ld a,1
        ld (rc_dirty),a
        ld a,e
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
        ld a,(pw)
        dec a
        cp c
        ret c
        ld a,(ph)
        dec a
        cp b
        ret c
        call set_px
        push bc
        ld a,(lmode)
        or a
        jr nz,.lay
        ld a,c                      ; on the screen, if in the window
        ld hl,vx
        sub (hl)
        jr c,.out
        cp VW
        jr nc,.out
        add a,CX
        ld c,a
        ld a,b
        ld hl,vy
        sub (hl)
        jr c,.out
        cp VH
        jr nc,.out
        add a,CY
        ld e,a
        ld d,0
        ld l,c
        ld h,d
        ld a,(colour)
        call VOS_PLOT
.out:
        pop bc
        ret
.lay:
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
        push bc
        call u_keep                 ; the whole screen: no UNDO
        pop bc
        ld a,(big)
        or a
        jr z,.kept
        xor a
        ld (u_ok),a
.kept:
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
        ld a,(pw)
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
        ld a,(ph)
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
; the part of the picture in the window, a row at a time (VOS_BLIT:
; mask and pixels); layers: each pixel a byte, each row twice
draw_canvas:
        ld a,(lmode)
        or a
        jr nz,.layers
        call rc_flush               ; (rbuf is used here)
        call rc_none
        ld a,(vy)
        ld b,a                      ; B: the picture's row, C: the window's
        ld c,0
.row:
        push bc
        call row_addr
        ld a,(vx)
        srl a
        ld e,a
        ld d,0
        add hl,de
        ld de,rbuf
        ld bc,VW / 2
        ld a,(big)
        or a
        jr z,.ram
        call VOS_BANK_GET
        jr .got
.ram:
        ldir
.got:
        ld hl,rbuf
        ld de,row_pairs
        ld b,VW / 2
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
        ld a,c
        add a,CY
        call .blit
        inc b
        inc c
        ld a,c
        cp VH
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
        call vos_drive_text
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
        ld b,6                      ; (lbuf: "DISK:" 5 + 13 + 6 + 0)
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
; B = 0 OPEN a picture (.SCR, or .PIC without a data bank of its own),
; 1 OPEN LAYERS a .LYR of fdrive, through the data bank, if of its size
open:
        push bc
        call discard_ok
        pop bc
        ret nz
        ld a,b
        ld (open_mode),a
        ld hl,ext_lyr
        or a
        call z,pic_ext
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
; A screen (16000 to 16384 bytes) stays in the data bank where it was
; loaded, as the picture; a .PIC (8192) there goes to its top left, on
; white; .PIC and .LYR are kept here (canvas). The name keeps the type
; the picture is saved as.
load_file:                          ; name_tmp on fdrive, open_mode
        xor a
        ld (u_ok),a
        ld a,(fdrive)
        or VOS_DATA
        ld hl,name_tmp
        ld de,SCR_DATA
        call VOS_LOAD
        jp c,VOS_ERROR
        ld a,(open_mode)
        or a
        ld hl,LYR_SIZE
        jr nz,.size
        ld a,(big)
        or a
        jr z,.pic
        ld h,b                      ; a screen?
        ld l,c
        ld de,16000
        or a
        sbc hl,de
        jr c,.pic
        ld de,SCR_SIZE - 16000 + 1
        sbc hl,de
        jr nc,.bad
        call rc_none
        xor a
        jr .mode
.pic:
        ld hl,PIC_SIZE
.size:
        push hl
        or a
        sbc hl,bc
        pop bc
        jr nz,.bad
        ld hl,SCR_DATA
        ld de,canvas
        call VOS_BANK_GET
        ld a,(open_mode)
        or a
        jr nz,.mode
        ld a,(big)
        or a
        jr z,.mode
        call new_pic                ; a .PIC on the whole screen
        ld b,0
.row:
        call rc_load
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,canvas
        add hl,de
        ld de,rbuf
        push bc
        ld bc,64
        ldir
        pop bc
        ld a,1
        ld (rc_dirty),a
        inc b
        bit 7,b
        jr z,.row
        call rc_flush
        xor a
.mode:
        call set_mode
        ld hl,name_tmp
        ld de,fname
        ld bc,8
        ldir
        push de
        call ext_now
        pop de
        ld c,3
        ldir
        jp redraw
.bad:
        ld hl,dlg_not_pic
        jp VOS_DIALOG

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
        call rc_flush
        ld bc,PIC_SIZE
        ld a,(lmode)
        or a
        jr nz,.layers
        ld a,(big)
        or a
        jr z,.size
        ld hl,palette               ; the whole screen: a .SCR, with the
        ld de,SCR_DATA + #07D0      ; palette in its unused bytes
        ld bc,17
        call VOS_BANK_PUT
        ld a,(fdrive)
        or VOS_DATA + VOS_LOAD_IX
        ld hl,fname
        ld de,SCR_DATA
        ld bc,SCR_SIZE
        push ix
        ld ix,#C000
        call VOS_SAVE
        pop ix
        jr .saved
.layers:
        ld bc,LYR_SIZE
.size:
        ld a,(fdrive)
        ld hl,fname
        ld de,canvas
        call VOS_SAVE
.saved:
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
        xor a                       ; (the data bank: kept no more)
        ld (u_ok),a
        ld a,(lmode)                ; the whole screen: a .SCR already
        or a
        jr nz,.build
        ld a,(big)
        or a
        jp nz,save_pic
.build:
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
menu:           db T_MENU, 12
                db T_NEW, CMD_NEW, 0, 0
                db T_NEW_L, CMD_NEW_L, 0, 0
                db T_OPEN, CMD_OPEN, "O", 0
                db T_OPEN_L, CMD_OPEN_L, 0, 0
                db T_SAVE, CMD_SAVE, "S", 0
                db T_SAVE_AS, CMD_SAVE_AS, 0, 0
                db T_EXPORT, CMD_EXPORT, 0, 0
                db T_DRIVE, CMD_DRIVE, 0, 0
                db T_UNDO, CMD_UNDO, "Z", 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_exported:   db T_MENU, T_EXPORTED, 1, VM_OK
dlg_discard:    db T_MENU, T_DISCARD, 2, VM_YES, VM_NO
dlg_not_pic:    db T_MENU, T_NOT_PIC, 1, VM_OK
noname:         db "NONAME  "
ext_pic:        db "PIC"
ext_lyr:        db "LYR"
ext_scr:        db "SCR"
no_pos:         db "---,---"
frame_rect:     dw CX, CY - 2, VBAR_X + BAR_W + 2 - CX, HBAR_Y + BAR_W + 2 - CY + 2
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

        include "api/vos_drive.inc"
        include "app_texts.asm"     ; texts, from texts.txt

lmode:          db 0                ; 0 a picture, 1 layers
u_ok:           db 0                ; UNDO: 1 when a picture is kept
u_vx:           db 0                ; the window's place then (vx, vy)
u_vy:           db 0
u_at:           dw 0
big:            db 0                ; 1: the whole screen (data bank)
pw:             db 128              ; its width and height
ph:             db 128
vx:             db 0                ; the window's top left in it
vy:             db 0
sdrag:          db 0                ; a scroll bar held: 1 right, 2 below
rc_y:           db #FF              ; the row in rbuf (#FF: none)
rc_dirty:       db 0
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
rbuf:           ds 80               ; a row of the picture
canvas:         ds PIC_SIZE

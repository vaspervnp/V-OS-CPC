; =====================================================================
; runtime.asm - the runtime of programs made with blocks (blocks/vbc.py)
;
; Included by the generated program after its header. The program
; provides (all generated):
;   PROG_MODE, PROG_BG, PROG_WIDTH   mode, background pen, screen width
;   SCRIPT_COUNT, SPRITE_COUNT
;   prog_palette    17 firmware colours
;   prog_scripts    per script: dw code, dw stack top, db sprite (#FF:
;                   the stage), db event (EVT_*), db parameter
;   prog_sprites    SP_SIZE bytes per sprite (live state, see SP_*)
;   costumes        per sprite: db count, dw costume...; a costume is
;                   db bytes, rows, then per row (mask, pixels) pairs
;   lists           dw length, dw room, then room words
;   rt_stacks, rt_state  room for the scripts' stacks and state
; SCRIPT_COUNT, SPRITE_COUNT and PROG_BG are immediates at rt_nscripts_n,
; rt_nsprites_n and rt_bg_n: blocks/player.asm sets them when it starts.
;
; Scripts are coroutines: each has its own stack and gives the processor
; back (rt_yield) at the end of every loop pass and in waits. On each
; frame (VE_FRAME) the scheduler resumes every running script once,
; then the sprites that changed are drawn again. So several scripts run
; side by side, as in Scratch, without interrupts.
; The script stacks are in the program's bank (#4000-#7FFF): a kernel
; call that maps another bank there (menus, texts of the system) must
; run on the main stack, as rt_clear does.
; =====================================================================

EVT_START       equ 0
EVT_KEY         equ 1               ; parameter: key number, #FF any key
EVT_CLICK       equ 2               ; script's sprite clicked (#FF stage)
EVT_RECEIVE     equ 3               ; parameter: message number

SP_X            equ 0               ; sprite record (words are signed)
SP_Y            equ 2
SP_VX           equ 4
SP_VY           equ 6
SP_W            equ 8
SP_H            equ 9
SP_COLOUR       equ 10
SP_VISIBLE      equ 11
SP_OX           equ 12              ; as last drawn
SP_OY           equ 14
SP_DRAWN        equ 16              ; 1: on the screen at SP_OX, SP_OY
SP_OCOLOUR      equ 17
SP_COSTUME      equ 18              ; number in its list, #FF: a rectangle
SP_OCOSTUME     equ 19
SP_OW           equ 20
SP_OH           equ 21
SP_CTAB         equ 22              ; -> db count, dw costume...
SP_SIZE         equ 24

ST_SP           equ 0               ; script state
ST_RUN          equ 2
ST_WAIT         equ 3
ST_SIZE         equ 5
STACK_SIZE      equ 128

RT_TOP          equ 12              ; below the menu bar
RT_BOTTOM       equ 259
        IF PROG_MODE == 0
RT_PPB          equ 2               ; pixels per screen byte
        ELSE
RT_PPB          equ 4
        ENDIF

RT_CMD_STOP     equ 1
T_RT_MENU       equ VT_FIRST
T_RT_STOP       equ VT_FIRST + 1

; ---------------------------------------------------------------------
rt_init:
        ld hl,rt_texts
        call VOS_TEXTS
        ld a,PROG_MODE
        call VOS_MODE
        ld hl,prog_palette
        call VOS_PALETTE
        call VOS_MENU_VIEW
        ld (rt_bar + 3),hl
        call VOS_MENU_HELP
        ld (rt_bar + 5),hl
        ld hl,rt_bar
        call VOS_SET_BAR
        ld a,1
        call VOS_TICKS
        call rt_redraw
        ld bc,EVT_START * 256       ; every "when started" script
        jp rt_start_all

; everything again: background, bar, sprites (printed text is lost)
rt_redraw:
        ld a,PROG_BG
rt_bg_1 equ $ - 1
        call VOS_CLS
        call VOS_DRAW_BAR
        ld ix,prog_sprites
        ld b,SPRITE_COUNT
rt_nsprites_1 equ $ - 1
        ld de,SP_SIZE
        inc b
        jr .first
.sprite:
        ld (ix + SP_DRAWN),0
        add ix,de
.first:
        djnz .sprite
        ld a,1
        ld (rt_dirty),a
        jp rt_draw_sprites

; HL -> event
rt_event:
        ld a,(hl)
        cp VE_FRAME
        jr z,rt_frame
        push hl
        call VOS_UI_EVENT           ; menus and shortcuts first
        pop hl
        or a
        jr nz,.command
        push hl
        call VOS_MENU_OPEN
        pop hl
        ret nz
        ld a,(hl)
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_PTR_DOWN
        ret nz
        inc hl                      ; a click: the sprite on top, or
        inc hl                      ; the stage
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        call rt_hit                 ; -> A = sprite or #FF
        ld c,a
        ld b,EVT_CLICK
        jp rt_start_all
.key:
        inc hl
        ld c,(hl)
        ld b,EVT_KEY
        jp rt_start_all
.command:
        cp RT_CMD_STOP
        jp z,VOS_EXIT
        jp VOS_COMMAND

rt_frame:
        call rt_run_scripts
        jp rt_draw_sprites

; ---------------------------------------------------------------------
; scripts
; ---------------------------------------------------------------------

; B = event, C = parameter: start (again) every script waiting for it
rt_start_all:
        xor a
.script:
        cp SCRIPT_COUNT
rt_nscripts_1 equ $ - 1
        ret nc
        push af
        push bc
        call rt_script_ptr          ; HL -> its prog_scripts entry
        ld de,5
        add hl,de
        ld a,(hl)                   ; event
        cp b
        jr nz,.next
        inc hl
        ld a,(hl)                   ; parameter
        cp c
        jr z,.start
        cp #FF                      ; any key
        jr nz,.next
        ld a,b
        cp EVT_KEY
        jr nz,.next
.start:
        pop bc
        pop af
        push af
        push bc
        call rt_start
.next:
        pop bc
        pop af
        inc a
        jr .script

; A = script -> HL -> its prog_scripts entry (7 bytes)
rt_script_ptr:
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,prog_scripts
        add hl,de
        ret

; A = script -> HL -> its state (ST_SIZE bytes)
rt_state_ptr:
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,rt_state
        add hl,de
        ret

; A = script: (re)start it from the beginning
rt_start:
        push af
        call rt_script_ptr
        ld e,(hl)                   ; code
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)                   ; stack top
        inc hl
        ld h,(hl)
        ld l,a
        dec hl                      ; the code's address is what the
        ld (hl),d                   ; first resume returns to
        dec hl
        ld (hl),e
        pop af
        push hl                     ; the script's stack pointer
        call rt_state_ptr
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),1                   ; running
        inc hl
        ld (hl),0                   ; no wait
        inc hl
        ld (hl),0
        ret

; every running script once, in order
rt_run_scripts:
        xor a
.script:
        cp SCRIPT_COUNT
rt_nscripts_2 equ $ - 1
        ret nc
        ld (rt_cur),a
        call rt_state_ptr
        ld (rt_cur_state),hl
        inc hl
        inc hl
        ld a,(hl)
        or a
        jr z,.next
        inc hl
        ld e,(hl)                   ; waiting?
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr z,.run
        dec de
        ld (hl),d
        dec hl
        ld (hl),e
        jr .next
.run:
        call rt_resume
.next:
        ld a,(rt_cur)
        inc a
        jr .script

rt_resume:
        ld (rt_main_sp),sp
        ld hl,(rt_cur_state)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld sp,hl
        ret                         ; into the script

; called by a script: give the processor back until the next frame
rt_yield:
        ld hl,0
        add hl,sp
        ex de,hl
        ld hl,(rt_cur_state)
        ld (hl),e
        inc hl
        ld (hl),d
        ld sp,(rt_main_sp)
        ret                         ; into rt_run_scripts

; HL = frames: wait, then go on
rt_wait:
        ex de,hl
        ld hl,(rt_cur_state)
        inc hl
        inc hl
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        jr rt_yield

; the script's end
rt_end:
        ld hl,(rt_cur_state)
        inc hl
        inc hl
        ld (hl),0
        ld sp,(rt_main_sp)
        ret

; called by a script: clear the stage. On the main stack, since
; VOS_DRAW_BAR maps the language bank over the script's stack
rt_clear:
        ld (rt_script_sp),sp
        ld sp,(rt_main_sp)
        call rt_redraw
        ld sp,(rt_script_sp)
        ret

; A = message: start the scripts that receive it
rt_broadcast:
        ld c,a
        ld b,EVT_RECEIVE
        jp rt_start_all

; ---------------------------------------------------------------------
; sprites (IX -> record)
; ---------------------------------------------------------------------

; x += vx, y += vy
rt_move:
        ld l,(ix + SP_X)
        ld h,(ix + SP_X + 1)
        ld e,(ix + SP_VX)
        ld d,(ix + SP_VX + 1)
        add hl,de
        ld (ix + SP_X),l
        ld (ix + SP_X + 1),h
        ld l,(ix + SP_Y)
        ld h,(ix + SP_Y + 1)
        ld e,(ix + SP_VY)
        ld d,(ix + SP_VY + 1)
        add hl,de
        ld (ix + SP_Y),l
        ld (ix + SP_Y + 1),h
        ret

; past an edge: turn back (vx or vy = -it) and stay inside
rt_bounce:
        ld l,(ix + SP_X)            ; left
        ld h,(ix + SP_X + 1)
        bit 7,h
        jr z,.right
        ld hl,0
        ld (ix + SP_X),l
        ld (ix + SP_X + 1),h
        call .turn_x
.right:
        ld l,(ix + SP_X)
        ld h,(ix + SP_X + 1)
        ld e,(ix + SP_W)
        ld d,0
        add hl,de
        ld de,PROG_WIDTH + 1
        call rt_lt_signed           ; x + w <= width ?
        jr c,.top
        ld hl,PROG_WIDTH
        ld e,(ix + SP_W)
        ld d,0
        or a
        sbc hl,de
        ld (ix + SP_X),l
        ld (ix + SP_X + 1),h
        call .turn_x
.top:
        ld l,(ix + SP_Y)
        ld h,(ix + SP_Y + 1)
        ld de,RT_TOP
        call rt_lt_signed
        jr nc,.bottom
        ld (ix + SP_Y),e
        ld (ix + SP_Y + 1),d
        call .turn_y
.bottom:
        ld l,(ix + SP_Y)
        ld h,(ix + SP_Y + 1)
        ld e,(ix + SP_H)
        ld d,0
        add hl,de
        ld de,RT_BOTTOM + 1
        call rt_lt_signed
        ret c
        ld hl,RT_BOTTOM
        ld e,(ix + SP_H)
        ld d,0
        or a
        sbc hl,de
        ld (ix + SP_Y),l
        ld (ix + SP_Y + 1),h
.turn_y:
        ld l,(ix + SP_VY)
        ld h,(ix + SP_VY + 1)
        call rt_neg
        ld (ix + SP_VY),l
        ld (ix + SP_VY + 1),h
        ret
.turn_x:
        ld l,(ix + SP_VX)
        ld h,(ix + SP_VX + 1)
        call rt_neg
        ld (ix + SP_VX),l
        ld (ix + SP_VX + 1),h
        ret

; IX, IY -> HL = 1 if the two rectangles overlap
rt_touching:
        ld a,(ix + SP_VISIBLE)
        and (iy + SP_VISIBLE)
        jr z,rt_false
        ld l,(ix + SP_X)            ; ax < bx + bw
        ld h,(ix + SP_X + 1)
        ld e,(iy + SP_X)
        ld d,(iy + SP_X + 1)
        ld a,(iy + SP_W)
        call .end
        jr nc,rt_false
        ld l,(iy + SP_X)            ; bx < ax + aw
        ld h,(iy + SP_X + 1)
        ld e,(ix + SP_X)
        ld d,(ix + SP_X + 1)
        ld a,(ix + SP_W)
        call .end
        jr nc,rt_false
        ld l,(ix + SP_Y)
        ld h,(ix + SP_Y + 1)
        ld e,(iy + SP_Y)
        ld d,(iy + SP_Y + 1)
        ld a,(iy + SP_H)
        call .end
        jr nc,rt_false
        ld l,(iy + SP_Y)
        ld h,(iy + SP_Y + 1)
        ld e,(ix + SP_Y)
        ld d,(ix + SP_Y + 1)
        ld a,(ix + SP_H)
        call .end
        jr nc,rt_false
        jr rt_true
.end:                               ; HL < DE + A ?
        ex de,hl
        add a,l
        ld l,a
        jr nc,.added
        inc h
.added:
        ex de,hl
        jp rt_lt_signed
rt_true:
        ld hl,1
        ret
rt_false:
        ld hl,0
        ret

; IX -> HL = 1 if the sprite touches or passes an edge
rt_at_edge:
        ld l,(ix + SP_X)
        ld h,(ix + SP_X + 1)
        ld de,1
        call rt_lt_signed           ; x < 1
        jr c,rt_true
        ld e,(ix + SP_W)
        ld d,0
        add hl,de
        ld de,PROG_WIDTH
        call rt_lt_signed           ; x + w < width
        jr nc,rt_true
        ld l,(ix + SP_Y)
        ld h,(ix + SP_Y + 1)
        ld de,RT_TOP + 1
        call rt_lt_signed
        jr c,rt_true
        ld e,(ix + SP_H)
        ld d,0
        add hl,de
        ld de,RT_BOTTOM
        call rt_lt_signed
        jr nc,rt_true
        jr rt_false

; DE, BC = x, y -> A = the sprite there (the last drawn on top), or #FF
rt_hit:
        ld (rt_hx),de
        ld (rt_hy),bc
        ld a,SPRITE_COUNT
rt_nsprites_2 equ $ - 1
.sprite:
        dec a
        cp #FF
        ret z
        push af
        call rt_sprite_ptr
        push hl
        pop ix
        ld a,(ix + SP_VISIBLE)
        or a
        jr z,.no
        ld hl,(rt_hx)               ; x <= px < x + w
        ld e,(ix + SP_X)
        ld d,(ix + SP_X + 1)
        call rt_lt_signed
        jr c,.no
        ld a,(ix + SP_W)
        call rt_touching.end
        jr nc,.no
        ld hl,(rt_hy)
        ld e,(ix + SP_Y)
        ld d,(ix + SP_Y + 1)
        call rt_lt_signed
        jr c,.no
        ld a,(ix + SP_H)
        call rt_touching.end
        jr nc,.no
        pop af
        ret
.no:
        pop af
        jr .sprite

; A = sprite -> HL -> its record
rt_sprite_ptr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de                   ; * 24
        ld de,prog_sprites
        add hl,de
        ret

; the sprites that changed: erase where they were, then draw all
; visible ones again (an erase may have cut into another)
rt_draw_sprites:
        ld ix,prog_sprites
        ld b,SPRITE_COUNT
rt_nsprites_3 equ $ - 1
        inc b
        jr .first
.erase:
        push bc
        call .changed
        jr z,.kept
        ld a,1
        ld (rt_dirty),a
        ld a,(ix + SP_DRAWN)
        or a
        jr z,.kept
        ld (ix + SP_DRAWN),0
        ld l,(ix + SP_OX)
        ld h,(ix + SP_OX + 1)
        ld a,(ix + SP_OCOSTUME)     ; an image: from its first byte
        inc a
        jr z,.at
        ld a,l
        and 256 - RT_PPB
        ld l,a
.at:
        ld e,(ix + SP_OY)
        ld d,(ix + SP_OY + 1)
        ld b,(ix + SP_OW)
        ld c,(ix + SP_OH)
        ld a,PROG_BG
rt_bg_2 equ $ - 1
        call rt_rect
.kept:
        pop bc
        ld de,SP_SIZE
        add ix,de
.first:
        djnz .erase
        ld a,(rt_dirty)
        or a
        ret z
        xor a
        ld (rt_dirty),a
        ld ix,prog_sprites
        ld b,SPRITE_COUNT
rt_nsprites_4 equ $ - 1
        inc b
        jr .next
.draw:
        push bc
        ld a,(ix + SP_VISIBLE)
        or a
        call nz,rt_draw_one
        pop bc
        ld de,SP_SIZE
        add ix,de
.next:
        djnz .draw
        ret
; -> NZ if the sprite is not on the screen as it is now
.changed:
        ld a,(ix + SP_DRAWN)
        xor (ix + SP_VISIBLE)
        ret nz
        ld a,(ix + SP_DRAWN)
        or a
        ret z
        ld a,(ix + SP_X)
        cp (ix + SP_OX)
        ret nz
        ld a,(ix + SP_X + 1)
        cp (ix + SP_OX + 1)
        ret nz
        ld a,(ix + SP_Y)
        cp (ix + SP_OY)
        ret nz
        ld a,(ix + SP_Y + 1)
        cp (ix + SP_OY + 1)
        ret nz
        ld a,(ix + SP_W)
        cp (ix + SP_OW)
        ret nz
        ld a,(ix + SP_H)
        cp (ix + SP_OH)
        ret nz
        ld a,(ix + SP_COLOUR)
        cp (ix + SP_OCOLOUR)
        ret nz
        ld a,(ix + SP_COSTUME)
        cp (ix + SP_OCOSTUME)
        ret

; IX -> a visible sprite: draw it, and remember where
rt_draw_one:
        ld l,(ix + SP_X)
        ld h,(ix + SP_X + 1)
        ld (ix + SP_OX),l
        ld (ix + SP_OX + 1),h
        ld e,(ix + SP_Y)
        ld d,(ix + SP_Y + 1)
        ld (ix + SP_OY),e
        ld (ix + SP_OY + 1),d
        ld a,(ix + SP_W)
        ld (ix + SP_OW),a
        ld a,(ix + SP_H)
        ld (ix + SP_OH),a
        ld a,(ix + SP_COLOUR)
        ld (ix + SP_OCOLOUR),a
        ld (ix + SP_DRAWN),1
        ld a,(ix + SP_COSTUME)
        ld (ix + SP_OCOSTUME),a
        cp #FF
        jr nz,.image
        ld b,(ix + SP_W)
        ld c,(ix + SP_H)
        ld a,(ix + SP_COLOUR)
        jp rt_rect
.image:
        push de
        push hl
        call rt_costume_ptr
        ld b,h
        ld c,l
        pop hl
        pop de
        ld a,l
        and 256 - RT_PPB
        ld l,a
        jp rt_blit

; HL = x, DE = y, B = w, C = h, A = pen: the rectangle, cut to the stage
rt_rect:
        ld (rt_box + 8),a
        ld a,b
        or a
        ret z
        ld a,c
        or a
        ret z
        ld (rt_box),hl
        ld (rt_box + 2),de
        ld l,b
        ld h,0
        ld (rt_box + 4),hl
        ld l,c
        ld (rt_box + 6),hl
        call rt_clip
        ret c
        push ix
        ld ix,rt_box
        call VOS_RECT
        pop ix
        ret

; HL = x (a whole byte), DE = y, BC -> costume: the image, cut to the
; stage
rt_blit:
        ld (rt_box),hl
        ld (rt_box + 2),de
        ld a,(bc)                   ; bytes
        or a
        ret z
        ld l,a
        add a,a
        ld (rt_blt + 8),a           ; stride
        ld h,0
        add hl,hl
        IF RT_PPB == 4
        add hl,hl
        ENDIF
        ld (rt_box + 4),hl
        inc bc
        ld a,(bc)                   ; rows
        or a
        ret z
        ld l,a
        ld h,0
        ld (rt_box + 6),hl
        inc bc
        ld (rt_blt + 6),bc
        call rt_clip
        ret c
        ld a,(rt_blt + 8)           ; source += cut rows * stride
        ld l,a
        ld h,0
        ld de,(rt_skip_y)
        call rt_mul
        ld de,(rt_skip_x)           ; + cut bytes * 2
        IF RT_PPB == 4
        srl d
        rr e
        ENDIF
        add hl,de
        ld de,(rt_blt + 6)
        add hl,de
        ld (rt_blt + 6),hl
        ld hl,(rt_box)
        ld (rt_blt),hl
        ld hl,(rt_box + 2)
        ld (rt_blt + 2),hl
        ld hl,(rt_box + 4)          ; pixels -> bytes
        srl h
        rr l
        IF RT_PPB == 4
        srl h
        rr l
        ENDIF
        ld a,l
        ld (rt_blt + 4),a
        ld a,(rt_box + 6)
        ld (rt_blt + 5),a
        push ix
        ld ix,rt_blt
        call VOS_BLIT
        pop ix
        ret

; rt_box = x, y, w, h (words, w and h > 0): cut to the stage. rt_skip_x,
; rt_skip_y = what was cut at the left and top. Carry: nothing is left
rt_clip:
        ld hl,0
        ld (rt_skip_x),hl
        ld (rt_skip_y),hl
        ld hl,(rt_box)              ; left
        bit 7,h
        jr z,.right
        call rt_neg
        ld (rt_skip_x),hl
        ex de,hl
        ld hl,(rt_box + 4)
        or a
        sbc hl,de
        jr c,.none
        jr z,.none
        ld (rt_box + 4),hl
        ld hl,0
        ld (rt_box),hl
.right:
        ld hl,(rt_box)
        ld de,PROG_WIDTH
        call rt_lt_signed
        jr nc,.none
        ex de,hl
        or a
        sbc hl,de                   ; room = width - x
        ld de,(rt_box + 4)
        call rt_lt_signed
        jr nc,.top
        ld (rt_box + 4),hl
.top:
        ld hl,(rt_box + 2)
        ld de,RT_TOP
        call rt_lt_signed
        jr nc,.bottom
        ex de,hl
        or a
        sbc hl,de                   ; cut = top - y
        ld (rt_skip_y),hl
        ex de,hl
        ld hl,(rt_box + 6)
        or a
        sbc hl,de
        jr c,.none
        jr z,.none
        ld (rt_box + 6),hl
        ld hl,RT_TOP
        ld (rt_box + 2),hl
.bottom:
        ld hl,(rt_box + 2)
        ld de,RT_BOTTOM
        call rt_lt_signed
        jr nc,.none
        ex de,hl
        or a
        sbc hl,de                   ; room = bottom - y
        ld de,(rt_box + 6)
        call rt_lt_signed
        ret nc
        ld (rt_box + 6),hl
        or a
        ret
.none:
        scf
        ret

; ---------------------------------------------------------------------
; costumes (IX -> sprite)
; ---------------------------------------------------------------------

; -> HL -> the current costume
rt_costume_ptr:
        ld a,(ix + SP_COSTUME)
        ld l,(ix + SP_CTAB)
        ld h,(ix + SP_CTAB + 1)
        inc hl
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; A = costume number: wear it (its size becomes the sprite's)
rt_set_costume:
        ld l,(ix + SP_CTAB)
        ld h,(ix + SP_CTAB + 1)
        cp (hl)
        ret nc                      ; no such costume
        ld (ix + SP_COSTUME),a
        call rt_costume_ptr
        ld a,(hl)
        add a,a
        IF RT_PPB == 4
        add a,a
        ENDIF
        ld (ix + SP_W),a
        inc hl
        ld a,(hl)
        ld (ix + SP_H),a
        ret

rt_next_costume:
        ld l,(ix + SP_CTAB)
        ld h,(ix + SP_CTAB + 1)
        ld a,(ix + SP_COSTUME)
        inc a
        cp (hl)
        jr c,rt_set_costume
        xor a
        jr rt_set_costume

; -> HL = the costume's number, from 1 (0: none)
rt_costume_number:
        ld a,(ix + SP_COSTUME)
        inc a
        ld l,a
        ld h,0
        ret

; ---------------------------------------------------------------------
; sound
; ---------------------------------------------------------------------

; A = channel, HL = note (MIDI: 60 = middle C, 24..119), DE = frames
rt_note:
        ld (rt_t),a
        call rt_frames_b
        push bc
        ld de,24
        or a
        sbc hl,de
        jr nc,.high
        ld hl,0
.high:
        ld a,h
        or a
        ld a,l
        jr nz,.top
        cp 96
        jr c,.octave
.top:
        ld a,95
.octave:
        ld c,0
.down:
        cp 12
        jr c,.found
        sub 12
        inc c
        jr .down
.found:
        add a,a
        ld e,a
        ld d,0
        ld hl,rt_periods
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld b,c
        inc b
        jr .shift
.half:
        srl h
        rr l
.shift:
        djnz .half
        jr rt_sound

; A = channel, HL = noise pitch 0..31, DE = frames
rt_noise:
        ld (rt_t),a
        call rt_frames_b
        push bc
        ld a,l
        and 31
        ld l,a
        ld h,#80
rt_sound:
        pop bc
        ld a,(rt_volume)
        ld c,a
        ld a,(rt_t)
        jp VOS_SOUND

; DE = frames -> B = 1..255 (more: 255)
rt_frames_b:
        ld b,255
        ld a,d
        or a
        ret nz
        ld b,e
        inc b
        dec b
        ret nz
        inc b
        ret

; every channel silent
rt_silence:
        xor a
.channel:
        push af
        ld bc,0
        call VOS_SOUND
        pop af
        inc a
        cp 3
        jr c,.channel
        ret

; HL = 0..15
rt_set_volume:
        ld a,l
        and 15
        ld (rt_volume),a
        ret

; ---------------------------------------------------------------------
; lists (DE -> list: dw length, room, then the items)
; ---------------------------------------------------------------------

; HL = index from 1 -> HL -> the item; carry if there is no such item
rt_list_at:
        ld a,h
        or l
        scf
        ret z
        dec hl
        ex de,hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        inc hl
        inc hl
        ex de,hl                    ; HL = index - 1, DE -> items
        push hl
        or a
        sbc hl,bc
        pop hl
        ccf
        ret c
        add hl,hl
        add hl,de
        or a
        ret

; HL = index -> HL = the item (0 if there is none)
rt_list_item:
        call rt_list_at
        jp c,rt_false
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; HL = value: at the end, if there is room
rt_list_add:
        push hl
        ex de,hl
        ld e,(hl)                   ; length
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)                   ; room
        inc hl
        ld b,(hl)
        inc hl
        push hl                     ; -> items
        ex de,hl
        or a
        sbc hl,bc
        jr nc,.full
        add hl,bc
        inc hl                      ; the new length
        ex de,hl
        pop hl
        dec hl
        dec hl
        dec hl
        ld (hl),d
        dec hl
        ld (hl),e
        dec de                      ; the old length: the new item's place
        ex de,hl
        add hl,hl
        add hl,de
        inc hl
        inc hl
        inc hl
        inc hl
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ret
.full:
        pop hl
        pop hl
        ret

; HL = index: that item out, the ones after it move up
rt_list_delete:
        push de
        call rt_list_at
        pop de
        ret c
        push hl                     ; -> the item
        ex de,hl
        ld e,(hl)                   ; length - 1
        inc hl
        ld d,(hl)
        dec de
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
        inc hl
        inc hl
        inc hl                      ; -> items
        ex de,hl
        add hl,hl
        add hl,de                   ; the end of the shorter list
        pop de                      ; -> the item
        or a
        sbc hl,de                   ; bytes to move
        ld b,h
        ld c,l
        ld h,d
        ld l,e
        inc hl
        inc hl
        ld a,b
        or c
        ret z
        ldir
        ret

; BC = index, HL = value: put it there
rt_list_replace:
        push hl
        ld h,b
        ld l,c
        call rt_list_at
        pop de
        ret c
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; BC = index (up to length + 1), HL = value: put it in before that item
rt_list_insert:
        ld (rt_hx),hl               ; the value
        ld (rt_hy),de               ; the list
        ex de,hl
        ld e,(hl)                   ; length
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)                   ; room = length: full
        inc hl
        cp e
        jr nz,.room
        ld a,(hl)
        cp d
        ret z
.room:
        ld a,b                      ; index 0: none
        or c
        ret z
        ld h,d                      ; index - 1 <= length ?
        ld l,e
        dec bc
        or a
        sbc hl,bc
        ret c
        ld (rt_t),hl                ; items to move: length - (index - 1)
        inc de
        ld hl,(rt_hy)               ; length + 1
        ld (hl),e
        inc hl
        ld (hl),d
        dec de
        ex de,hl
        add hl,hl
        ld de,(rt_hy)
        add hl,de
        inc hl
        inc hl
        inc hl
        inc hl                      ; HL -> after the last item
        ld d,h
        ld e,l
        inc de                      ; DE -> the last byte, two on
        dec hl                      ; HL -> the last byte
        ld bc,(rt_t)
        sla c
        rl b
        ld a,b
        or c
        jr z,.store
        lddr                        ; HL ends one before the place
.store:
        inc hl
        ld de,(rt_hx)
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; HL = value -> HL = 1 if the list has it
rt_list_contains:
        ld b,h
        ld c,l
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        inc hl
        inc hl
.item:
        ld a,d
        or e
        jp z,rt_false
        ld a,(hl)
        inc hl
        cp c
        jr nz,.next
        ld a,(hl)
        cp b
        jp z,rt_true
.next:
        inc hl
        dec de
        jr .item

; ---------------------------------------------------------------------
; numbers (16-bit signed)
; ---------------------------------------------------------------------

; HL -> -HL.  Preserves DE
rt_neg:
        push de
        ex de,hl
        ld hl,0
        or a
        sbc hl,de
        pop de
        ret

; HL < DE (signed) -> carry
rt_lt_signed:
        ld a,h
        xor d
        jp m,.signs
        or a
        sbc hl,de
        add hl,de
        ret
.signs:                             ; different signs: the negative one
        ld a,h
        rla
        ret

; DE op HL -> HL, for comparisons 1 or 0
rt_lt:
        ex de,hl
rt_gt:
        call rt_lt_signed
        jp c,rt_true
        jp rt_false
rt_eq:
        or a
        sbc hl,de
        jp z,rt_true
        jp rt_false

; HL = DE * HL
rt_mul:
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
.bit:
        add hl,hl
        ex de,hl
        add hl,hl
        ex de,hl
        jr nc,.skip
        add hl,bc
.skip:
        dec a
        jr nz,.bit
        ret

; HL = DE / HL, DE = remainder (signed; by 0 gives 0)
rt_div:
        ld a,h
        or l
        jp z,rt_false
        ld a,d                      ; the sign of the result
        xor h
        push af
        ld a,d                      ; and of the remainder
        push af
        bit 7,h
        call nz,rt_neg
        ld b,h
        ld c,l
        ex de,hl
        bit 7,h
        call nz,rt_neg
        ex de,hl                    ; DE = |a|, BC = |b|
        ld hl,0
        ld a,16
.bit:
        ex de,hl                    ; shift DE into HL
        add hl,hl
        ex de,hl
        adc hl,hl
        or a
        sbc hl,bc
        jr nc,.one
        add hl,bc
        jr .next
.one:
        inc e
.next:
        dec a
        jr nz,.bit
        pop af                      ; remainder: sign of a
        bit 7,a
        call nz,rt_neg
        ex de,hl                    ; HL = quotient, DE = remainder
        pop af
        bit 7,a
        ret z
        jp rt_neg

rt_mod:
        call rt_div
        ex de,hl
        ret

; HL = from, DE = to -> HL = random in from..to
rt_random:
        push hl
        ex de,hl
        or a
        sbc hl,de                   ; range - 1
        inc hl
        push hl
        call VOS_RANDOM
        ld (rt_t),a
        call VOS_RANDOM
        ld d,a
        ld a,(rt_t)
        ld e,a
        pop hl                      ; DE mod range
        ld a,h
        or l
        jr z,.whole
        call rt_div_unsigned
.whole:
        pop hl
        add hl,de
        ret

; DE = DE mod HL, unsigned
rt_div_unsigned:
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
.bit:
        ex de,hl
        add hl,hl
        ex de,hl
        adc hl,hl
        or a
        sbc hl,bc
        jr nc,.next
        add hl,bc
.next:
        dec a
        jr nz,.bit
        ex de,hl
        ret

; A = key number -> HL = 1 while it is held
rt_key_held:
        call VOS_KEY_HELD
        jp nz,rt_true
        jp rt_false

; HL = x, DE = y, BC -> text: print it in the text colours
rt_print:
        push hl
        push de
        push bc
        ld a,(rt_ink)
        ld c,PROG_BG
rt_bg_3 equ $ - 1
        call VOS_COLOURS
        pop bc
        pop de
        pop hl
        jp VOS_PRINT

; HL = number, then (rt_px), (rt_py): print it in decimal
rt_print_number:
        ld de,rt_number
        bit 7,h
        jr z,.positive
        ld a,"-"
        ld (de),a
        inc de
        call rt_neg
.positive:
        ld ix,rt_tens
        ld c,0                      ; digits so far
.ten:
        ld a,(ix)
        or (ix + 1)
        jr z,.done
        push de
        ld e,(ix)
        ld d,(ix + 1)
        ld a,"0" - 1
.sub:
        inc a
        or a
        sbc hl,de
        jr nc,.sub
        add hl,de
        pop de
        ld b,a
        ld a,(ix)                   ; the ones: always a digit
        dec a
        or (ix + 1)
        jr z,.store
        ld a,b
        cp "0"
        jr nz,.store
        ld a,c                      ; no leading zeros
        or a
        jr z,.skip
.store:
        ld a,b
        ld (de),a
        inc de
        inc c
.skip:
        inc ix
        inc ix
        jr .ten
.done:
        ex de,hl                    ; spaces after it, over a longer
.pad:                               ; number printed there before
        ld de,rt_number + 6
        push hl
        or a
        sbc hl,de
        pop hl
        jr nc,.end
        ld (hl)," "
        inc hl
        jr .pad
.end:
        ld (hl),0
        ld hl,(rt_px)
        ld de,(rt_py)
        ld bc,rt_number
        jp rt_print

; ---- data -----------------------------------------------------------
rt_tens:        dw 10000, 1000, 100, 10, 1, 0
rt_bar:         db 3
                dw rt_menu, 0, 0
rt_menu:        db T_RT_MENU, 1
                db T_RT_STOP, RT_CMD_STOP, "Q", 0
rt_texts:       db 2
                dw rt_t_menu_en, rt_t_menu_el
                dw rt_t_stop_en, rt_t_stop_el
rt_t_menu_en:   db "PROGRAM", 0
rt_t_stop_en:   db "STOP", 0
rt_t_menu_el:   db #D0, #D1, #CF, #C3, #D1, #C1, #CC, #CC, #C1, 0   ; ΠΡΟΓΡΑΜΜΑ
rt_t_stop_el:   db #D4, #C5, #CB, #CF, #D3, 0                     ; ΤΕΛΟΣ

rt_main_sp:     dw 0
rt_script_sp:   dw 0
rt_cur:         db 0
rt_cur_state:   dw 0
rt_dirty:       db 0
rt_hx:          dw 0
rt_hy:          dw 0
rt_box:         dw 0, 0, 0, 0
                db 0
rt_ink:         db 1
rt_px:          dw 0
rt_py:          dw 0
rt_t:           dw 0
rt_number:      ds 8
rt_skip_x:      dw 0
rt_skip_y:      dw 0
rt_blt:         dw 0, 0
                db 0, 0
                dw 0
                db 0
rt_volume:      db 12
rt_periods:     dw 1911, 1804, 1703, 1607, 1517, 1432   ; C1..B1 (AY at 1 MHz)
                dw 1351, 1276, 1204, 1136, 1073, 1012

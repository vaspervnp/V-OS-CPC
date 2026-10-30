; =====================================================================
; player.asm - VBRUN: runs a Studio program (.VBS) with the runtime
;
; Studio (apps/studio) writes NAME.BIN as this binary followed by the
; program's VBS record (vbs_data). When it starts, the player compiles
; the VBS lines to Z80 code after them, the same code blocks/vbc.py
; writes for those blocks, then the runtime (runtime.asm) runs it:
; scripts are coroutines, sprites rectangles or costumes, in mode 0 or
; 1 (V_MODE1). The costumes (16 x 16 pens, after the lines) become
; images in place for the mode (pl_costumes); every sprite may wear any
; of them: COSTUME n (from 1; 0 changes nothing), NEXT COSTUME, and the
; value COSTUME (0: a rectangle).
;
;   #4000  the player and the runtime, then the VBS record: its head,
;          texts and costumes (moved down over the lines, which the
;          compiler reads from the data bank), then the compiled
;          scripts, up to CODE_LIMIT
;          the REPEATs' counters (REPEATS words)
;   #7500  sprites, the script table and state
;   #7650  the 128 variables (A..H, A1..H15: n mod 8 the letter, n / 8
;          the number), cleared with the state
;   #7750  SAVE VARS and LOAD VARS: the file's name and a buffer
;   #7800  the scripts' stacks (MAX_SCRIPTS x 128)
;
; SAVE VARS group TO text writes the variables, all 128 or the 8 of a
; group (A..H, A1..H1, ... A15..H15), to the file the text names (.TXT
; when it has no type) as text, a line each: "A1=-5". LOAD VARS group
; FROM text sets those of the group that the file names (pl_save_vars).
; WHEN I RECEIVE n starts on SEND n (a number; SEND takes any value).
; WINDOW title w h draws a window in the middle of the stage; BUTTON,
; TEXT and PRINT then place things from its inside top left (without
; one, from the screen's). Buttons are the kernel's (VOS_SET_WIDGETS),
; numbered from 0 in the order they appear, at most 16 for a window;
; pressing one starts WHEN BUTTON, and the value BUTTON gives its
; number. A new window takes the last one and its buttons away.
; Lines before the first WHEN, and the lines of a script whose sprite
; does not exist, are left out. A script ends at the next WHEN, or at
; the end: blocks still open are closed there. Motion and looks blocks
; in a stage script do nothing; X, Y, TOUCHING and AT EDGE give 0.
;
;   rasm blocks/player.asm -I src -I blocks -o build/vbrun
; =====================================================================

        include "api/vos_api.inc"

RT_UI           equ 1               ; windows and buttons (runtime.asm)
RT_ANY_MODE     equ 1               ; images in mode 1 too (pl_costumes)
PROG_RUNS       equ 0               ; set at rt_runs_1 (V_RUNS)
PROG_MODE       equ 0               ; set at rt_mode_1: the program's
PROG_WIDTH      equ 192             ; mode, and at rt_width_n (mode 1: 384)
PROG_BG         equ 0               ; set at rt_bg_n, see pl_init
SCRIPT_COUNT    equ 0               ; rt_nscripts_n
SPRITE_COUNT    equ 0               ; rt_nsprites_n

; the VBS record, version 3 (as apps/studio/studio.asm)
SPR_MAX         equ 6
SPR_SIZE        equ 8
TEXT_MAX        equ 32
TEXT_SIZE       equ 16
LINE_SIZE       equ 10
MAX_LINES       equ 240
V_BG            equ 4                   ; pen 0..15; + V_MODE1: mode 1;
                                        ; + V_RUNS: it goes on behind
V_NSPR          equ 5
V_SPR           equ 6
V_TEXTS         equ V_SPR + SPR_MAX * SPR_SIZE
V_NLINES        equ V_TEXTS + TEXT_MAX * TEXT_SIZE
V_LINES         equ V_NLINES + 2

K_NUM           equ 1
K_VAR           equ 2
K_X             equ 3
K_Y             equ 4
K_RND           equ 5
K_KEY           equ 6
K_TOUCH         equ 7
K_EDGE          equ 8
K_CMP           equ 9
K_BUTTON        equ 12
K_COSTUME       equ 14
K_GROUP         equ 15              ; 0..15: A..H, A1..H1 ...; 16: all

OP_HATS         equ 3               ; WHEN START, KEY, CLICKED = EVT_*
OP_RECEIVE      equ 24              ; WHEN I RECEIVE: EVT_RECEIVE
OP_PRESSED      equ 32              ; WHEN BUTTON: EVT_BUTTON
OP_COUNT        equ 39
COS_MAX         equ 8               ; costumes after the lines: db count,
COS_SIZE        equ 258             ; then db 0, 0, 16 x 16 pens (bit 7:
                                    ; none); pl_costumes makes them images

MAX_SCRIPTS     equ 16
MAX_DEPTH       equ 16              ; open FOREVER / REPEAT / IF
T_LOOP          equ 1               ; control stack: FOREVER
T_REPEAT        equ 2
T_IF            equ 3
T_ELSE          equ 4
CT_SIZE         equ 5               ; db type, dw a, dw b

V_MODE1         equ #80
V_RUNS          equ #40

prog_sprites    equ #7500           ; SPR_MAX * SP_SIZE
prog_scripts    equ #7590           ; MAX_SCRIPTS * 7
rt_state        equ #7600           ; MAX_SCRIPTS * ST_SIZE
VARS            equ 128
pl_vars         equ rt_state + MAX_SCRIPTS * ST_SIZE
REPEATS         equ 64              ; REPEATs in a program, each with a
pl_counters     equ prog_sprites - REPEATS * 2 ; word, set as the loop starts
rt_stacks       equ #7800
CODE_LIMIT      equ pl_counters - 64 ; a line's code is shorter

        org VOS_APP_ADDR
        jp pl_init
        jp rt_event
        jp rt_redraw
        db "VA", VOS_API_VERSION
        include "icon_blocks.asm"       ; VOS_ICON, from apps/icons/blocks.txt

        include "runtime.asm"

prog_palette:   db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16, 0

; ---------------------------------------------------------------------
pl_init:
        cp 2                        ; going on: all is in place
        jp z,rt_init
        ld hl,vbs_data              ; "VBS", 1? Else no program
        ld de,pl_magic
        ld b,4
.magic:
        ld a,(de)
        cp (hl)
        jr nz,.empty
        inc hl
        inc de
        djnz .magic
        ld a,(vbs_data + V_NSPR)
        cp SPR_MAX + 1
        jr nc,.empty
        ld hl,(vbs_data + V_NLINES)
        ld de,MAX_LINES + 1
        or a
        sbc hl,de
        jr c,.read
.empty:
        xor a
        ld (vbs_data + V_NSPR),a
        ld h,a
        ld l,a
        ld (vbs_data + V_NLINES),hl
.read:
        ld a,(vbs_data + V_BG)
        and 15
        ld hl,pl_bg_sites
        call pl_patch
        ld a,(vbs_data + V_BG)      ; mode 0 or 1: 192 or 384 pixels
        rlca
        push af
        rlca                        ; V_RUNS
        and 1
        ld (rt_runs_1),a
        pop af
        and 1
        ld (rt_mode_1),a
        ld hl,PROG_WIDTH
        jr z,.width
        add hl,hl
.width:
        ld (rt_ui_width),hl
        ex de,hl
        ld hl,pl_width_sites
.site:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,b
        or c
        jr z,.sized
        ld a,e
        ld (bc),a
        inc bc
        ld a,d
        ld (bc),a
        jr .site
.sized:
        ld a,(vbs_data + V_NSPR)
        ld (pl_nspr),a
        ld hl,pl_spr_sites
        call pl_patch
        call pl_costumes
        call pl_sprites
        ld hl,rt_state              ; script state 0
        ld de,rt_state + 1
        ld bc,rt_stacks - rt_state - 1
        ld (hl),0                   ; and the variables
        ldir
        call pl_compile
        ld a,(pl_nscripts)
        ld hl,pl_script_sites
        call pl_patch
        jp rt_init

; A = value, HL -> dw address... 0: the value at each address
pl_patch:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,a
        ld a,d
        or e
        ret z
        ld a,c
        ld (de),a
        jr pl_patch

; the VBS sprites -> runtime records
pl_sprites:
        ld ix,prog_sprites
        ld hl,vbs_data + V_SPR
        ld a,(pl_nspr)
        or a
        ret z
        ld b,a
.sprite:
        push bc
        push hl
        push ix                     ; all 0 first
        pop hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,SP_SIZE - 1
        ldir
        pop hl
        push ix
        pop de
        ld bc,4                     ; dw x, y
        ldir
        ld a,(hl)                   ; w, h, colour
        ld (ix + SP_W),a
        inc hl
        ld a,(hl)
        ld (ix + SP_H),a
        inc hl
        ld a,(hl)
        ld (ix + SP_COLOUR),a
        inc hl
        ld (ix + SP_VISIBLE),1
        ld (ix + SP_COSTUME),#FF
        ld (ix + SP_CTAB),pl_ctab & #FF
        ld (ix + SP_CTAB + 1),pl_ctab >> 8
        ld a,(hl)                   ; its costume, 0: none
        inc hl
        push hl
        dec a
        call rt_set_costume
        pop hl
        ld de,SP_SIZE
        add ix,de
        pop bc
        djnz .sprite
        ret

; ---------------------------------------------------------------------
; the compiler: VBS lines (IX -> line) -> code at (pl_out)
; ---------------------------------------------------------------------
; The lines are read one at a time from the file's copy in the data
; bank (the kernel loads a program there first, at the same addresses:
; VOS_APP_ADDR = #4000), so the code may go over them; pl_costumes has
; moved the costumes down to where the lines start.
pl_compile:
        xor a
        ld (pl_nscripts),a
        ld (pl_open),a
        ld (pl_depth),a
        ld (pl_lineno),a
        ld (pl_nrep),a
        ld bc,(vbs_data + V_NLINES)
        ld hl,vbs_data + V_LINES
        ld (pl_src),hl
        ld hl,(pl_cos_end)          ; the code after the costumes
        ld (pl_out),hl
        ld a,c
        or a
        jr z,.done
        ld b,a
.line:
        push bc
        ld hl,(pl_out)              ; no more room: the rest is left out
        ld de,CODE_LIMIT
        or a
        sbc hl,de
        jr nc,.full
        ld hl,(pl_src)              ; the line -> pl_line
        push hl
        ld de,pl_line
        ld bc,LINE_SIZE
        call VOS_BANK_GET
        pop hl
        ld de,LINE_SIZE
        add hl,de
        ld (pl_src),hl
        ld ix,pl_line
        ld a,(ix + 0)
        cp OP_COUNT
        jr nc,.next
        cp OP_RECEIVE
        jr z,.hat
        cp OP_PRESSED
        jr z,.hat
        cp OP_HATS
        jr nc,.block
.hat:
        call pl_hat
        jr .next
.block:
        ld a,(pl_open)
        or a
        call nz,.run
.next:
        ld hl,pl_lineno
        inc (hl)
        pop bc
        djnz .line
.done:
        jp pl_close
.full:
        pop bc
        jr .done
.run:
        ld a,(ix + 0)
        add a,a
        ld l,a
        ld h,0
        ld de,pl_ops
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

; WHEN ...: a new script (the one before ends)
pl_hat:
        call pl_close
        ld a,(pl_nscripts)
        cp MAX_SCRIPTS
        ret nc
        xor a                       ; slot 0: 0 the stage, 1..6 a sprite
        call pl_slot
        ld a,e
        or a
        ld a,#FF
        jr z,.own
        ld a,e
        dec a
        ld hl,pl_nspr
        cp (hl)
        ret nc                      ; no such sprite: left out
        push af
        call rt_sprite_ptr
        ld (pl_own_rec),hl
        pop af
.own:
        ld (pl_own),a
        ld (pl_param),a             ; WHEN CLICKED: its sprite
        ld a,(ix + 0)
        cp OP_RECEIVE
        ld b,EVT_RECEIVE
        jr z,.mapped
        cp OP_PRESSED
        ld b,EVT_BUTTON
        jr nz,.event
.mapped:
        ld a,b
.event:
        ld (pl_event),a
        cp EVT_BUTTON               ; WHEN BUTTON: any button
        jr nz,.not_button
        xor a
        ld (pl_param),a
        jr .entry
.not_button:
        cp EVT_KEY
        jr z,.slot1
        cp EVT_RECEIVE
        jr nz,.entry
.slot1:
        ld a,1                      ; WHEN KEY: the key; WHEN I RECEIVE:
        call pl_slot                ; the message (a number, else 0)
        ld a,b
        cp K_NUM
        ld a,e
        jr z,.param
        ld a,(pl_event)
        cp EVT_KEY
        ld a,e
        jr z,.param
        xor a
.param:
        ld (pl_param),a
.entry:
        ld a,(pl_nscripts)
        call rt_script_ptr
        ld de,(pl_out)              ; dw code
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(pl_nscripts)          ; dw stack top
        inc a
        ld (pl_nscripts),a
        ld d,a
        ld e,0
        srl d
        rr e
        push hl
        ld hl,rt_stacks
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(pl_own)               ; db sprite, event, parameter
        ld (hl),a
        inc hl
        ld a,(pl_event)
        ld (hl),a
        inc hl
        or a
        jr z,.start
        ld a,(pl_param)
.start:
        ld (hl),a
        ld a,1
        ld (pl_open),a
        ret

; the open script ends: its open blocks, then rt_end
pl_close:
        ld a,(pl_open)
        or a
        ret z
.open:
        ld a,(pl_depth)
        or a
        jr z,.end
        call op_end
        jr .open
.end:
        ld (pl_open),a
        ld de,rt_end
        jp e_jp

; ---- blocks ---------------------------------------------------------
pl_ops:
        dw 0, 0, 0                  ; the WHENs (pl_hat)
        dw op_forever, op_repeat, op_if, op_else, op_end
        dw op_wait, op_until, op_stop
        dw op_goto, op_chx, op_chy, op_speed, op_move, op_bounce
        dw op_colour, op_show, op_hide
        dw op_print, op_note, op_set, op_change
        dw 0, op_broadcast          ; WHEN I RECEIVE (pl_hat), SEND
        dw op_sub, op_mul, op_div, op_mod
        dw op_window, op_button, 0, op_write    ; WHEN BUTTON: pl_hat
        dw op_costume, op_next_costume, op_label
        dw op_save_vars, op_load_vars
        assert $ - pl_ops == OP_COUNT * 2     ; as in apps/studio/studio.asm

op_forever:
        ld a,T_LOOP
        ld de,(pl_out)
        jp ct_push

op_repeat:
        ld hl,pl_nrep               ; its own counter (the 65th shares
        inc (hl)                    ; the first one's)
        xor a                       ; counter = times
        call pl_value
        call pl_counter
        ld a,#22                    ; ld (cnt),hl
        call e_op_w
        ld hl,(pl_out)              ; top: ld hl,(cnt)
        push hl
        call pl_counter
        ld a,#2A
        call e_op_w
        call e_test                 ; jp z,end
        ld a,#CA
        call e_byte
        ld hl,(pl_out)
        push hl
        call e_word
        ld a,#2B                    ; dec hl
        call e_byte
        call pl_counter
        ld a,#22
        call e_op_w
        pop bc                      ; b: the end's jump
        pop de                      ; a: the top
        ld a,T_REPEAT
        jp ct_push

op_if:
        call pl_cond
        call e_test
        ld a,#CA                    ; jp z,else
        call e_byte
        ld de,(pl_out)
        call e_word
        ld a,T_IF
        jp ct_push

op_else:
        call ct_top
        ret z
        ld a,(hl)
        cp T_IF
        ret nz
        ld (hl),T_ELSE
        inc hl
        push hl
        ld a,#C3                    ; jp end
        call e_byte
        ld de,(pl_out)
        call e_word
        pop hl
        ld c,(hl)                   ; IF's jump comes here
        ld (hl),e
        inc hl
        ld b,(hl)
        ld (hl),d
        jp pl_land

op_end:
        call ct_top
        ret z
        ld a,(pl_depth)
        dec a
        ld (pl_depth),a
        ld a,(hl)
        inc hl
        ld e,(hl)                   ; a
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)                   ; b
        inc hl
        ld b,(hl)
        cp T_IF
        jr nc,.if
        push af                     ; loops: yield, back to the top
        push bc
        push de
        ld de,rt_yield
        call e_call
        pop de
        call e_jp
        pop bc
        pop af
        cp T_REPEAT
        ret nz
        jr pl_land
.if:
        ld b,d
        ld c,e
        ; fall through

; BC -> a jump's address: it jumps to (pl_out)
pl_land:
        ld hl,(pl_out)
        ld a,l
        ld (bc),a
        inc bc
        ld a,h
        ld (bc),a
        ret

op_wait:
        xor a
        call pl_value
        ld de,rt_wait
        jp e_call

op_until:
        ld hl,(pl_out)
        push hl
        call pl_cond
        call e_test
        ld a,#20                    ; jr nz,past the next two
        call e_byte
        ld a,6
        call e_byte
        ld de,rt_yield
        call e_call
        pop de
        jp e_jp

op_stop:
        ld de,rt_end
        jp e_jp

op_goto:
        ld de,SP_X
        ld bc,SP_Y
        jr op_pair
op_speed:
        ld de,SP_VX
        ld bc,SP_VY
op_pair:                            ; DE, BC = offsets: slots 0, 1 there
        call pl_own_prop
        ret c
        push bc
        push de
        xor a
        call pl_value
        pop de
        ld a,#22
        call e_op_w
        pop de
        call pl_own_prop
        push de
        ld a,1
        call pl_value
        pop de
        ld a,#22
        jp e_op_w

op_chx:
        ld de,SP_X
        jr op_add
op_chy:
        ld de,SP_Y
op_add:                             ; DE = offset: += slot 0
        call pl_own_prop
        ret c
        push de
        xor a
        call pl_value
        pop de
        ; fall through

; DE = a word: it += HL
e_add_to:
        push de
        call e_plus
        pop de
        ld a,#22                    ; ld (word),hl
        jp e_op_w

; DE = a word: HL += it
e_plus:
        ld a,#ED                    ; ld de,(word)
        call e_byte
        ld a,#5B
        call e_op_w
        ld a,#19                    ; add hl,de
        jp e_byte

op_move:
        ld hl,rt_move
        jr op_ix_call
op_bounce:
        ld hl,rt_bounce
op_ix_call:                         ; ld ix,own : call HL
        ld de,0
        call pl_own_prop
        ret c
        push hl
        call e_ld_ix
        pop de
        jp e_call

op_colour:
        ld de,SP_COLOUR
        call pl_own_prop
        ret c
        push de
        xor a
        call pl_value
        ld a,#7D                    ; ld a,l
        call e_byte
        pop de
        ld a,#32
        jp e_op_w

op_show:
        ld c,1
        jr op_visible
op_hide:
        ld c,0
op_visible:
        ld de,SP_VISIBLE
        call pl_own_prop
        ret c
        ld a,#3E                    ; ld a,n
        call e_byte
        ld a,c
        call e_byte
        ld a,#32
        jp e_op_w

op_costume:                         ; COSTUME n: 1.., 0 none (no change)
        ld de,0
        call pl_own_prop
        ret c
        push de
        xor a
        call pl_value
        ld a,#7D                    ; ld a,l
        call e_byte
        ld a,#3D                    ; dec a
        call e_byte
        pop de
        call e_ld_ix
        ld de,rt_set_costume
        jp e_call

op_next_costume:
        ld de,0
        call pl_own_prop
        ret c
        call e_ld_ix
        ld de,rt_next_costume
        jp e_call

op_print:                           ; PRINT value AT x y
        call pl_at
        xor a
        call pl_value
        ld de,rt_print_number
        jp e_call

op_window:                          ; WINDOW text w h
        ld a,1
        call pl_value
        ld de,rt_ww
        ld a,#22
        call e_op_w
        ld a,2
        call pl_value
        ld de,rt_wh
        ld a,#22
        call e_op_w
        ld hl,rt_window
        jr op_texted
op_button:                          ; BUTTON text AT x y
        ld hl,rt_button
        jr op_placed
op_label:                           ; LABEL button TO text: HL = the
        ld a,1                      ; button, A = the text
        call pl_value
        ld hl,rt_label
        jr op_texted
op_write:                           ; TEXT text AT x y
        ld hl,rt_write
op_placed:
        push hl
        call pl_at
        pop hl
op_texted:                          ; HL = routine: ld a,text, ld de,HL,
        push hl                     ; call rt_on_main
        xor a
        call pl_slot
        ld a,#3E
        call e_byte
        ld a,e
        call e_byte
        pop de
        ld a,#11
        call e_op_w
        ld de,rt_on_main
        jp e_call

; slots 1, 2: code for (rt_px), (rt_py) = x, y from the window's inside
pl_at:
        ld a,1
        call pl_value
        ld de,rt_ox
        call e_plus
        ld de,rt_px
        ld a,#22
        call e_op_w
        ld a,2
        call pl_value
        ld de,rt_oy
        call e_plus
        ld de,rt_py
        ld a,#22
        jp e_op_w

op_save_vars:                       ; SAVE VARS group TO text: ld hl,
        ld hl,pl_save_vars          ; group, ld a,text, ld de,routine,
        jr op_vars                  ; call rt_on_main
op_load_vars:
        ld hl,pl_load_vars
op_vars:
        push hl
        ld a,1
        call pl_slot
        ld a,b
        cp K_GROUP
        jr nz,.all
        ld a,e
        cp 16
        jr c,.group
.all:
        ld de,16
.group:
        ld a,#21
        call e_op_w
        pop hl
        jr op_texted

op_note:                            ; NOTE note FOR frames: and wait
        ld a,1
        call pl_value
        ld a,#E5                    ; push hl
        call e_byte
        xor a
        call pl_value
        ld hl,pl_note_code
        ld b,pl_note_end - pl_note_code
.copy:
        ld a,(hl)
        call e_byte
        inc hl
        djnz .copy
        ret

op_broadcast:                       ; SEND n: ld a,l : call rt_broadcast
        xor a
        call pl_value
        ld a,#7D
        call e_byte
        ld de,rt_broadcast
        jp e_call

op_set:
        ld a,1
        call pl_value
        call pl_var0
        ld a,#22
        jp e_op_w

op_change:
        ld a,1
        call pl_value
        call pl_var0
        jp e_add_to

op_sub:                             ; var -= slot 1
        ld a,1
        call pl_value
        ld a,#EB                    ; ex de,hl
        call e_byte
        call pl_var0
        push de
        ld a,#2A                    ; ld hl,(var)
        call e_op_w
        ld a,#B7                    ; or a
        call e_byte
        ld a,#ED                    ; sbc hl,de
        call e_byte
        ld a,#52
        call e_byte
        pop de
        ld a,#22
        jp e_op_w

op_mul:
        ld hl,rt_mul
        jr op_arith
op_div:
        ld hl,rt_div
        jr op_arith
op_mod:
        ld hl,rt_mod
op_arith:                           ; var = var (HL = rt_*) slot 1
        push hl
        ld a,1
        call pl_value
        call pl_var0
        push de
        ld a,#ED                    ; ld de,(var)
        call e_byte
        ld a,#5B
        call e_op_w
        pop bc
        pop de
        push bc
        call e_call
        pop de
        ld a,#22                    ; ld (var),hl
        jp e_op_w

; ---- values ---------------------------------------------------------

; A = slot: code that puts its value in HL
pl_value:
        call pl_slot
        ld a,b
        cp K_NUM
        jr z,.num
        cp K_VAR
        jr z,.var
        cp K_X
        jr z,.x
        cp K_Y
        jr z,.y
        cp K_RND
        jr z,.rnd
        cp K_KEY
        jr z,.key
        cp K_TOUCH
        jr z,.touch
        cp K_EDGE
        jr z,.edge
        cp K_BUTTON
        jp z,.button
        cp K_COSTUME
        jp z,.costume
.zero:
        ld de,0
.num:
        ld a,#21                    ; ld hl,n
        jp e_op_w
.var:
        call pl_var
        ld a,#2A                    ; ld hl,(var)
        jp e_op_w
.x:
        ld de,SP_X
        jr .prop
.y:
        ld de,SP_Y
.prop:
        call pl_own_prop
        jr c,.zero
        ld a,#2A
        jp e_op_w
.rnd:                               ; 1..n
        push de
        ld de,1
        ld a,#21
        call e_op_w
        pop de
        ld a,#11                    ; ld de,n
        call e_op_w
        ld de,rt_random
        jp e_call
.key:
        ld a,#3E
        call e_byte
        ld a,e
        call e_byte
        ld de,rt_key_held
        jp e_call
.touch:
        ld a,e                      ; sprite 1..n
        dec a
        ld hl,pl_nspr
        cp (hl)
        jr nc,.zero
        push af
        ld de,0
        call pl_own_prop
        pop bc
        jr c,.zero
        push bc
        call e_ld_ix
        pop af
        call rt_sprite_ptr
        ex de,hl
        ld a,#FD                    ; ld iy,sprite
        call e_byte
        ld a,#21
        call e_op_w
        ld de,rt_touching
        jp e_call
.edge:
        ld de,0
        call pl_own_prop
        jr c,.zero
        call e_ld_ix
        ld de,rt_at_edge
        jp e_call
.button:
        ld de,rt_button_n
        ld a,#2A
        jp e_op_w
.costume:
        ld de,0
        call pl_own_prop
        jp c,.zero
        call e_ld_ix
        ld de,rt_costume_number
        jp e_call

; IF / WAIT UNTIL: code for HL = 0 when false. Slot 1 compares slots
; 0 and 2; without a comparison, slot 0 alone.
pl_cond:
        ld a,1
        call pl_slot
        ld a,b
        cp K_CMP
        ld a,0
        jp nz,pl_value
        push de
        call pl_value
        ld a,#E5                    ; push hl
        call e_byte
        ld a,2
        call pl_value
        ld a,#D1                    ; pop de
        call e_byte
        pop de
        ld a,e
        ld de,rt_lt
        or a
        jr z,.call
        ld de,rt_eq
        dec a
        jr z,.call
        ld de,rt_gt
.call:
        jp e_call

; A = slot of the line at IX -> B = kind, DE = value
pl_slot:
        ld c,a
        add a,a
        add a,c
        inc a
        ld e,a
        ld d,0
        push ix
        pop hl
        add hl,de
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ret

; slot 0's variable -> DE; DE = variable 0..63 -> DE = its address
pl_var0:
        xor a
        call pl_slot
pl_var:
        ld a,e
        and VARS - 1
        add a,a
        ld e,a
        ld d,0
        ld hl,pl_vars
        add hl,de
        ex de,hl
        ret

; DE = offset -> DE = the script's sprite + offset; carry: a stage
; script (keeps BC, HL)
pl_own_prop:
        ld a,(pl_own)
        inc a
        scf
        ret z
        push hl
        ld hl,(pl_own_rec)
        add hl,de
        ex de,hl
        pop hl
        or a
        ret

; -> DE = this REPEAT's counter (pl_nrep)
pl_counter:
        ld a,(pl_nrep)
        and REPEATS - 1
        ld e,a
        ld d,0
        ex de,hl
        add hl,hl
        ld de,pl_counters
        add hl,de
        ex de,hl
        ret

; ---- control stack --------------------------------------------------

; A = type, DE = a, BC = b (a block beyond MAX_DEPTH is left open:
; its END closes the one around it)
ct_push:
        push af
        ld a,(pl_depth)
        cp MAX_DEPTH
        jr nc,.full
        inc a
        ld (pl_depth),a
        push de
        call ct_top
        pop de
        pop af
        ld (hl),a
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        ret
.full:
        pop af
        ret

; -> HL -> the top entry; Z if there is none
ct_top:
        ld a,(pl_depth)
        or a
        ret z
        dec a
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,pl_ctrl
        add hl,de
        or h                        ; NZ
        ret

; ---- emitting -------------------------------------------------------

; ld a,h : or l
e_test:
        ld a,#7C
        call e_byte
        ld a,#B5
        ; fall through
e_byte:
        push hl
        ld hl,(pl_out)
        ld (hl),a
        inc hl
        ld (pl_out),hl
        pop hl
        ret

e_word:                             ; DE
        ld a,e
        call e_byte
        ld a,d
        jr e_byte

e_op_w:                             ; A = opcode, DE = its word
        call e_byte
        jr e_word

e_call:
        ld a,#CD
        jr e_op_w

e_jp:
        ld a,#C3
        jr e_op_w

e_ld_ix:                            ; ld ix,DE
        ld a,#DD
        call e_byte
        ld a,#21
        jr e_op_w

; NOTE's code after its push hl: pop de, play on channel 0, then wait
pl_note_code:
        pop de
        push de
        xor a
        call rt_note
        pop hl
        call rt_wait
pl_note_end:

; ---------------------------------------------------------------------
; the program's texts, for the runtime's windows and buttons
; ---------------------------------------------------------------------
; A = text -> HL -> it
rt_text_ptr:
        and TEXT_MAX - 1
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,vbs_data + V_TEXTS
        add hl,de
        ret

; ---------------------------------------------------------------------
; SAVE VARS and LOAD VARS (on the main stack: the disc, the data bank)
; ---------------------------------------------------------------------
; The file is text, a line a variable: its name, "=", its value
; ("A=12", "C3=-5"). It is made and read in the data bank, at PV_BANK.
; LOAD VARS sets the variables of the group its lines name and leaves
; the others as they are; other lines are left out, and so is a file
; that is not there.
PV_BANK         equ #4000
PV_CHUNK        equ 32                  ; read from the bank at a time

; A = text (the file's name), HL = group (16: all)
pl_save_vars:
        call pv_file
        ld hl,PV_BANK
        ld (pv_ptr),hl
        xor a
.var:
        ld (pv_n),a
        call pv_in_group
        jr nz,.next
        ld a,(pv_n)
        ld de,pv_line
        call pv_name_text
        ld a,"="
        ld (de),a
        inc de
        ld a,(pv_n)
        call pv_var_ptr
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call rt_number_text
        ex de,hl
        ld (hl),13
        inc hl
        ld (hl),10
        inc hl
        ld de,pv_line
        or a
        sbc hl,de
        ld b,h
        ld c,l
        push bc
        ex de,hl
        ld de,(pv_ptr)
        call VOS_BANK_PUT
        pop bc
        ld hl,(pv_ptr)
        add hl,bc
        ld (pv_ptr),hl
.next:
        ld a,(pv_n)
        inc a
        cp VARS
        jr c,.var
        ld hl,(pv_ptr)
        ld de,PV_BANK
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,VOS_DATA
        ld hl,pv_fcb
        jp VOS_SAVE

; A = text, HL = group (16: all)
pl_load_vars:
        call pv_file
        ld a,VOS_DATA
        ld hl,pv_fcb
        ld de,PV_BANK
        call VOS_LOAD
        ret c
        ld (pv_left),bc
        ld hl,PV_BANK
        ld (pv_ptr),hl
        xor a
        ld (pv_have),a
.find:                                  ; a name: A..H, then 1..15
        call pv_next
        or a
        ret z
        and #DF                         ; a..h too
        sub "A"
        cp 8
        jr nc,.find
        ld (pv_n),a
        call pv_next
        call pv_number
        ld a,h
        or a
        jr nz,.skip
        ld a,l
        cp 16
        jr nc,.skip
        add a,a
        add a,a
        add a,a
        ld hl,pv_n
        add a,(hl)
        ld (hl),a
        ld a,(pv_ch)
.equals:                                ; spaces, "="
        cp " "
        jr z,.more
        cp "="
        jr nz,.value
.more:
        call pv_next
        jr .equals
.value:
        cp "-"
        push af
        call z,pv_next
        sub "0"
        cp 10
        jr nc,.not_number
        ld a,(pv_ch)
        call pv_number
        pop af
        call z,rt_neg
        push hl
        ld a,(pv_n)
        call pv_in_group
        jr nz,.not_set
        ld a,(pv_n)
        call pv_var_ptr
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        jr .skip
.not_number:
.not_set:
        pop af
.skip:                                  ; the rest of the line
        ld a,(pv_ch)
        or a
        ret z
        cp 10
        jr z,.find
        cp 13
        jr z,.find
        call pv_next
        jr .skip

; A = character, then pv_next: digits -> HL (A = the next character)
pv_number:
        ld hl,0
.digit:
        sub "0"
        cp 10
        ld a,(pv_ch)
        ret nc
        push hl
        add hl,hl
        add hl,hl
        pop de
        add hl,de
        add hl,hl
        sub "0"
        ld e,a
        ld d,0
        add hl,de
        push hl
        call pv_next
        pop hl
        jr .digit

; the file's next character -> A, (pv_ch); 0 at its end
pv_next:
        ld hl,(pv_left)
        ld a,h
        or l
        jr z,.put
        dec hl
        ld (pv_left),hl
        ld a,(pv_have)
        or a
        jr nz,.have
        ld hl,(pv_ptr)
        ld de,pv_buf
        ld bc,PV_CHUNK
        call VOS_BANK_GET
        ld hl,(pv_ptr)
        ld bc,PV_CHUNK
        add hl,bc
        ld (pv_ptr),hl
        ld a,PV_CHUNK
.have:
        dec a
        ld (pv_have),a
        cpl
        add a,PV_CHUNK                  ; PV_CHUNK - 1 - left: its place
        ld e,a
        ld d,0
        ld hl,pv_buf
        add hl,de
        ld a,(hl)
.put:
        ld (pv_ch),a
        ret

; A = text, HL = group -> pv_group, pv_fcb: its name, 8 + 3 capitals
; (".TXT" when it has none)
pv_file:
        ld b,a
        ld a,h
        or a
        ld a,16
        jr nz,.group
        ld a,l
        cp 16
        jr c,.group
        ld a,16
.group:
        ld (pv_group),a
        ld hl,pv_fcb
        ld c,11
.space:
        ld (hl)," "
        inc hl
        dec c
        jr nz,.space
        ld a,b
        call rt_text_ptr
        ld de,pv_fcb
        ld b,8
        call .part
        ld de,pv_fcb + 8
        ld a,(hl)
        cp "."
        ld b,3
        jr z,.type
        ex de,hl
        ld (hl),"T"
        inc hl
        ld (hl),"X"
        inc hl
        ld (hl),"T"
        ret
.type:
        inc hl
.part:                                  ; up to B characters before "."
        ld a,(hl)
        or a
        ret z
        cp "."
        ret z
        inc hl
        cp " "
        jr z,.part
        cp "a"
        jr c,.put
        cp "z" + 1
        jr nc,.put
        sub #20
.put:
        ld (de),a
        inc de
        djnz .part
        ret

; A = variable -> Z if it is in pv_group
pv_in_group:
        ld c,a
        ld a,(pv_group)
        cp 16
        ret z
        ld b,a
        ld a,c
        rrca
        rrca
        rrca
        and 15
        cp b
        ret

; A = variable -> HL -> it (keeps DE)
pv_var_ptr:
        push de
        add a,a
        ld l,a
        ld h,0
        ld de,pl_vars
        add hl,de
        pop de
        ret

; A = variable, DE -> room: its name there -> DE after it
pv_name_text:
        ld c,a
        and 7
        add a,"A"
        ld (de),a
        inc de
        ld a,c
        rrca
        rrca
        rrca
        and 15
        ret z
        cp 10
        jr c,.digit
        sub 10
        ld c,a
        ld a,"1"
        ld (de),a
        inc de
        ld a,c
.digit:
        add a,"0"
        ld (de),a
        inc de
        ret

; their data, after the variables (below the stacks)
pv_fcb          equ pl_vars + VARS * 2  ; 12
pv_group        equ pv_fcb + 12
pv_n            equ pv_group + 1
pv_ch           equ pv_n + 1
pv_have         equ pv_ch + 1
pv_ptr          equ pv_have + 1         ; dw
pv_left         equ pv_ptr + 2          ; dw
pv_line         equ pv_left + 2         ; "A15=-32768", 13, 10
pv_buf          equ pv_line + 12
pv_end          equ pv_buf + PV_CHUNK

; ---- data -----------------------------------------------------------
rt_texts:       db 2 + TEXT_MAX, "EL" ; the runtime's, then the program's
                dw rt_t_menu_en, rt_t_menu_el
                dw rt_t_stop_en, rt_t_stop_el
        REPEAT TEXT_MAX, n
                dw vbs_data + V_TEXTS + (n - 1) * TEXT_SIZE, 0
        REND

pl_magic:       db "VBS", 3
pl_bg_sites:    dw rt_bg_1, rt_bg_2, rt_bg_3, rt_bg_4, 0
pl_spr_sites:   dw rt_nsprites_1, rt_nsprites_2, rt_nsprites_3, rt_nsprites_4, 0
pl_script_sites: dw rt_nscripts_1, rt_nscripts_2, 0
pl_width_sites: dw rt_width_1, rt_width_2, rt_width_3, rt_width_4, 0

pl_nspr:        db 0
pl_nscripts:    db 0
pl_open:        db 0                ; a script is being compiled
pl_own:         db 0                ; its sprite, #FF: the stage
pl_own_rec:     dw 0
pl_param:       db 0
pl_event:       db 0
pl_lineno:      db 0
pl_nrep:        db 0                ; REPEATs so far
pl_out:         dw 0
pl_src:         dw 0                ; the next line, in the data bank
pl_line:        ds LINE_SIZE
pl_depth:       db 0
pl_ctrl:        ds MAX_DEPTH * CT_SIZE

; ---------------------------------------------------------------------
; costumes: after the lines, made images in place for the program's
; mode; one table for all sprites (pl_ctab). Mode 1 also writes the
; runtime's mode 1 instructions (rt_m1_n).
; ---------------------------------------------------------------------
pl_costumes:
        ld a,(rt_mode_1)
        or a
        ld hl,pl_mode0
        jr z,.mode
        ld hl,pl_m1_sites
.site:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.patched
        ld a,(hl)
        inc hl
        ld (de),a
        jr .site
.patched:
        ld hl,pl_mode1
.mode:
        ld de,pl_ppb
        ld bc,5
        ldir
        ld hl,(vbs_data + V_NLINES) ; after the lines
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,vbs_data + V_LINES
        add hl,de
        ld a,(hl)
        cp COS_MAX + 1
        jr c,.count
        xor a
.count:
        ld (pl_ctab),a
        ld (hl),a                   ; down to where the lines start (the
        push af                     ; compiler reads them from the data
        ld b,a                      ; bank): db count, COS_SIZE each
        push hl
        ld hl,1
        ld de,COS_SIZE
        or a
        jr z,.sized
.size:
        add hl,de
        djnz .size
.sized:
        ld b,h
        ld c,l
        pop hl
        ld de,vbs_data + V_LINES
        push de
        ldir
        pop hl
        pop af
        inc hl
        ld de,pl_ctab + 1
        or a
        jr z,.end
        ld b,a
.costume:
        ex de,hl                    ; its address in the table
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex de,hl
        push bc
        push de
        ld a,(pl_rowb)              ; bytes, rows
        ld (hl),a
        inc hl
        ld (hl),16
        inc hl
        push hl
        call pl_image
        pop hl
        ld bc,256
        add hl,bc
        pop de
        pop bc
        djnz .costume
.end:
        ld (pl_cos_end),hl
        ret

; HL -> 16 x 16 pens: (mask, pixels) pairs there. Each byte's pixels
; are read last first: acc = acc / 2 + the bits of a pixel 0
pl_image:
        ld d,h
        ld e,l
        ld a,(pl_obytes)
        ld b,a
.out:
        push bc
        ld a,(pl_ppb)
        ld b,a
        dec a
        add a,l                     ; HL -> the byte's last pixel
        ld l,a
        adc a,h
        sub l
        ld h,a
        push hl
        ld c,0                      ; mask
        xor a
        ld (pl_px),a
.pixel:
        srl c
        ld a,(pl_px)
        srl a
        ld (pl_px),a
        ld a,(hl)
        dec hl
        bit 7,a                     ; none
        jr nz,.next
        push hl
        ld hl,pl_pens
        and (hl)
        ld hl,pl_spread
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(pl_px)
        or (hl)
        ld (pl_px),a
        ld a,(pl_m0)
        or c
        ld c,a
        pop hl
.next:
        djnz .pixel
        ld a,c
        ld (de),a
        inc de
        ld a,(pl_px)
        ld (de),a
        inc de
        pop hl
        inc hl
        pop bc
        djnz .out
        ret

; a pen's bits as pixel 0 of a byte (mode 1: pens 0..3, the same)
pl_spread:      db #00, #80, #08, #88, #20, #A0, #28, #A8
                db #02, #82, #0A, #8A, #22, #A2, #2A, #AA
pl_mode0:       db 2, 128, 15, #AA, 8   ; pl_ppb .. pl_rowb
pl_mode1:       db 4, 64, 3, #88, 4
pl_ppb:         db 0                ; pixels a byte
pl_obytes:      db 0                ; bytes of an image (pairs)
pl_pens:        db 0                ; the pen bits used
pl_m0:          db 0                ; pixel 0's bits
pl_rowb:        db 0                ; bytes a row
pl_px:          db 0
pl_cos_end:     dw 0
pl_ctab:        db 0                ; count, dw costume...
                ds COS_MAX * 2
pl_m1_sites:    dw rt_m1_and_1 : db #FC
                dw rt_m1_and_2 : db #FC
                dw rt_m1_1 : db #29         ; add hl,hl
                dw rt_m1_2 : db #CB         ; srl d
                dw rt_m1_2 + 1 : db #3A
                dw rt_m1_2 + 2 : db #CB     ; rr e
                dw rt_m1_2 + 3 : db #1B
                dw rt_m1_3 : db #CB         ; srl h
                dw rt_m1_3 + 1 : db #3C
                dw rt_m1_3 + 2 : db #CB     ; rr l
                dw rt_m1_3 + 3 : db #1D
                dw rt_m1_4 : db #87         ; add a,a
                dw 0

; Studio appends the program here
vbs_data:
        assert pv_end <= rt_stacks
        assert VOS_APP_ADDR == #4000    ; where the kernel loads it, in the data bank too
        ; the longest program, 240 lines and 8 costumes, has 4000 bytes
        ; for its code (the lines take none: the code goes over them)
        assert vbs_data + V_LINES + 1 + COS_MAX * COS_SIZE <= CODE_LIMIT - 4000
        save "build/VBRUN.BIN", VOS_APP_ADDR, vbs_data - VOS_APP_ADDR

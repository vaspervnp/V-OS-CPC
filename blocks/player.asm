; =====================================================================
; player.asm - VBRUN: runs a Studio program (.VBS) with the runtime
;
; Studio (apps/studio) writes NAME.BIN as this binary followed by the
; program's VBS record (vbs_data). When it starts, the player compiles
; the VBS lines to Z80 code after them, the same code blocks/vbc.py
; writes for those blocks, then the runtime (runtime.asm) runs it:
; scripts are coroutines, sprites rectangles, in mode 0.
;
;   #4000  the player and the runtime, then the VBS record
;          the compiled scripts, up to CODE_LIMIT
;   #7500  sprites, the script table and state, variables, counters
;   #7800  the scripts' stacks (MAX_SCRIPTS x 128)
;
; WHEN I RECEIVE n starts on SEND n (a number; SEND takes any value).
; Lines before the first WHEN, and the lines of a script whose sprite
; does not exist, are left out. A script ends at the next WHEN, or at
; the end: blocks still open are closed there. Motion and looks blocks
; in a stage script do nothing; X, Y, TOUCHING and AT EDGE give 0.
;
;   rasm blocks/player.asm -I src -I blocks -o build/vbrun
; =====================================================================

        include "api/vos_api.inc"

PROG_MODE       equ 0
PROG_WIDTH      equ 192
PROG_BG         equ 0               ; set at rt_bg_n, see pl_init
SCRIPT_COUNT    equ 0               ; rt_nscripts_n
SPRITE_COUNT    equ 0               ; rt_nsprites_n

; the VBS record (as apps/studio/studio.asm)
SPR_MAX         equ 6
SPR_SIZE        equ 8
LINE_SIZE       equ 10
MAX_LINES       equ 200
V_BG            equ 4
V_NSPR          equ 5
V_SPR           equ 6
V_NLINES        equ V_SPR + SPR_MAX * SPR_SIZE
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

OP_HATS         equ 3               ; WHEN START, KEY, CLICKED = EVT_*
OP_RECEIVE      equ 24              ; WHEN I RECEIVE: EVT_RECEIVE
OP_COUNT        equ 26

MAX_SCRIPTS     equ 16
MAX_DEPTH       equ 16              ; open FOREVER / REPEAT / IF
T_LOOP          equ 1               ; control stack: FOREVER
T_REPEAT        equ 2
T_IF            equ 3
T_ELSE          equ 4
CT_SIZE         equ 5               ; db type, dw a, dw b

prog_sprites    equ #7500           ; SPR_MAX * SP_SIZE
prog_scripts    equ #7590           ; MAX_SCRIPTS * 7
rt_state        equ #7600           ; MAX_SCRIPTS * ST_SIZE
pl_vars         equ #7650           ; A..H
pl_counters     equ #7660           ; a word for each REPEAT line
rt_stacks       equ #7800
CODE_LIMIT      equ prog_sprites - 64   ; a line's code is shorter

        org VOS_APP_ADDR
        jp pl_init
        jp rt_event
        jp rt_redraw
        db "VA", VOS_API_VERSION
        include "icon_blocks.asm"       ; VOS_ICON, from apps/icons/blocks.txt

        include "runtime.asm"

prog_palette:   db 0, 26, 1, 2, 11, 20, 18, 9, 24, 15, 6, 3, 8, 5, 13, 16, 0
rt_no_costumes: db 0

; ---------------------------------------------------------------------
pl_init:
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
        ld a,(vbs_data + V_NSPR)
        ld (pl_nspr),a
        ld hl,pl_spr_sites
        call pl_patch
        call pl_sprites
        ld hl,rt_state              ; script state, variables and
        ld de,rt_state + 1          ; counters 0
        ld bc,rt_stacks - rt_state - 1
        ld (hl),0
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
        inc hl
        ld (ix + SP_VISIBLE),1
        ld (ix + SP_COSTUME),#FF
        ld (ix + SP_CTAB),rt_no_costumes & #FF
        ld (ix + SP_CTAB + 1),rt_no_costumes >> 8
        ld de,SP_SIZE
        add ix,de
        pop bc
        djnz .sprite
        ret

; ---------------------------------------------------------------------
; the compiler: VBS lines (IX -> line) -> code at (pl_out)
; ---------------------------------------------------------------------
pl_compile:
        xor a
        ld (pl_nscripts),a
        ld (pl_open),a
        ld (pl_depth),a
        ld (pl_lineno),a
        ld bc,(vbs_data + V_NLINES)
        ld ix,vbs_data + V_LINES
        ld h,b                      ; the code after the lines
        ld l,c
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,vbs_data + V_LINES
        add hl,de
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
        ld a,(ix + 0)
        cp OP_COUNT
        jr nc,.next
        cp OP_RECEIVE
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
        ld de,LINE_SIZE
        add ix,de
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
        jr nz,.event
        ld a,EVT_RECEIVE
.event:
        ld (pl_event),a
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

op_forever:
        ld a,T_LOOP
        ld de,(pl_out)
        jp ct_push

op_repeat:
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

; DE = a word: HL += it
e_add_to:
        push de
        ld a,#ED                    ; ld de,(word)
        call e_byte
        ld a,#5B
        call e_op_w
        ld a,#19                    ; add hl,de
        call e_byte
        pop de
        ld a,#22                    ; ld (word),hl
        jp e_op_w

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

op_print:                           ; PRINT value AT x y
        ld a,1
        call pl_value
        ld de,rt_px
        ld a,#22
        call e_op_w
        ld a,2
        call pl_value
        ld de,rt_py
        ld a,#22
        call e_op_w
        xor a
        call pl_value
        ld de,rt_print_number
        jp e_call

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

; slot 0's variable -> DE; DE = variable 0..7 -> DE = its address
pl_var0:
        xor a
        call pl_slot
pl_var:
        ld a,e
        and 7
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

; -> DE = this line's REPEAT counter
pl_counter:
        ld a,(pl_lineno)
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

; ---- data -----------------------------------------------------------
pl_magic:       db "VBS", 1
pl_bg_sites:    dw rt_bg_1, rt_bg_2, rt_bg_3, 0
pl_spr_sites:   dw rt_nsprites_1, rt_nsprites_2, rt_nsprites_3, rt_nsprites_4, 0
pl_script_sites: dw rt_nscripts_1, rt_nscripts_2, 0

pl_nspr:        db 0
pl_nscripts:    db 0
pl_open:        db 0                ; a script is being compiled
pl_own:         db 0                ; its sprite, #FF: the stage
pl_own_rec:     dw 0
pl_param:       db 0
pl_event:       db 0
pl_lineno:      db 0
pl_out:         dw 0
pl_depth:       db 0
pl_ctrl:        ds MAX_DEPTH * CT_SIZE

; Studio appends the program here
vbs_data:
        assert vbs_data + V_LINES + MAX_LINES * LINE_SIZE <= CODE_LIMIT - 2048
        save "build/VBRUN.BIN", VOS_APP_ADDR, vbs_data - VOS_APP_ADDR

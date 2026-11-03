; =====================================================================
; calc.asm - the formula engine (CALC.SYS): numbers, formulas and the
; functions of a spreadsheet, for programs through VOS_EXT, VX_CALC
; (API 24). SHEET uses it; any program may.
;
; It runs in base RAM bank 1 at CALC_ADDR (include/memmap.inc): the
; kernel loads CALC.SYS from drive A: the first time a program uses it
; (calc_entry, kernel/ext2.asm). Its text buffer is the UTF-8 one
; there (u8_buf). A program's memory comes and goes through bank_copy.
;
; A number is 32 bits, signed, in hundredths: 1234 is 12.34; from
; -21474836.46 to 21474836.46. Two values are no number: CALC_NONE (an
; empty cell, or text: 0 in a sum, left out by SUM, AVG, MIN, MAX and
; COUNT) and CALC_BAD (a cell with an error: a formula that uses it has
; one too).
; A formula: + - * / ( ), numbers (12, 3.5, .25), cells (A1 .. Z255,
; in a grid of the program's, CB_GRID) and functions: SUM AVG MIN MAX
; COUNT of values and ranges (B2:D9) between "," or ";", and ABS(x),
; INT(x) (down to a whole number), ROUND(x) or ROUND(x, 0..2).
; Products and quotients are rounded to the hundredth.
;
; CALC_HARNESS builds it alone for tools/calc_check.py (a Z80
; emulator): a program's memory is plain RAM there.
; =====================================================================

        IFDEF CALC_HARNESS
        include "api/vos_api.inc"
CALC_ADDR       equ #4D80
        org CALC_ADDR
        ENDIF

CALC_DEPTH      equ 8               ; ( and functions inside each other
T_ROOM            equ 128             ; a text from a program, at most
N_FUNCS         equ 8

calc_start:
        jp calc_call
        db "CA", 1

; C = CALC_* call, DE -> the program's block (CB_*), HL -> its text ->
; A, DE, HL; carry, A = error
calc_call:
        push ix
        ld (c_hl),hl
        ld (c_cb),de
        ld a,c
        ld (c_fn),a
        cp CALC_CALLS
        ld a,DB_ERR_BAD
        jr nc,.bad
        ld hl,.done
        push hl
        ld (c_sp),sp                ; an error: back to .done from anywhere
        ld a,c
        cp CALC_CELL
        jr nc,.go
        ld hl,(c_cb)                ; its block, but for CELL
        ld de,cb
        ld bc,CB_SIZE
        call c_in
.go:
        ld a,(c_fn)
        add a,a
        ld l,a
        ld h,0
        ld de,c_table
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.bad:
        scf
.done:
        pop ix
        ret

c_table:        dw c_eval, c_number, c_text, c_cell
        assert $ - c_table == CALC_CALLS * 2

; ---- the calls -------------------------------------------------------
; EVAL: HL -> a formula ("=" first or not)
c_eval:
        call get_text
        ld a,(vw_cfg)               ; the grid: in the program, or its
        ld hl,cb + CB_BANK          ; data bank
        bit 7,(hl)
        call nz,data_get
        ld (g_cfg),a
        xor a
        ld (depth),a
        call peek
        cp 61                       ; "="
        call z,skip1
        call expr
        jr c_end

; NUMBER: HL -> text: a number, maybe "-" or "+" first, nothing more
c_number:
        call get_text
        call peek
        cp "+"
        jr z,.plus
        cp "-"
        jr nz,.lit
        call skip1
        call num_lit
        call neg32
        jr c_end
.plus:
        call skip1
.lit:
        call num_lit
        ; fall through
; DEHL: the result, if the text has nothing after it
c_end:
        call peek
        or a
        jp nz,e_syntax
        ld (cb + CB_RESULT),hl
        ld (cb + CB_RESULT + 2),de
        push de
        push hl
        call put_cb
        pop hl
        pop de
        or a
        ret

; TEXT: CB_RESULT as text at HL, A = its length (CALC_NONE: none,
; CALC_BAD: "#ERR")
c_text:
        ld hl,(cb + CB_RESULT)
        ld de,(cb + CB_RESULT + 2)
        call mark
        ld de,obuf
        or a
        jr z,.number
        dec a
        jr z,.out
        ld hl,t_err
        ld bc,4
        ldir
        jr .out
.number:
        ld hl,(cb + CB_RESULT)
        ld de,(cb + CB_RESULT + 2)
        call num_text
.out:
        xor a
        ld (de),a
        ld hl,obuf
        ex de,hl
        sbc hl,de                   ; (no carry) its length
        ld a,l
        push af
        ld c,a
        ld b,0
        inc bc
        ld hl,obuf
        ld de,(c_hl)
        call c_out
        pop af
        or a
        ret
t_err:          db "#ERR"

; CELL: a cell at the text's start? -> D = column, E = row (from 0),
; A = its characters; carry: none
c_cell:
        call get_text
        call peek
        call cell_at
        jr c,.none
        ld hl,(tp)
        push de
        ld de,tbuf
        or a
        sbc hl,de
        pop de
        ld a,l
        or a
        ret
.none:
        ld a,CALC_ERR_SYNTAX
        ret

; the text at c_hl into tbuf, tp there
get_text:
        ld hl,(c_hl)
        ld de,tbuf
        ld (tp),de
        ld bc,T_ROOM
        call c_in
        xor a
        ld (tbuf + T_ROOM - 1),a
        ret

; the block back to the program (EVAL and NUMBER)
put_cb:
        ld hl,cb
        ld de,(c_cb)
        ld bc,CB_SIZE
        jp c_out

; ---- errors: from any depth back to calc_call ------------------------
e_syntax:
        ld a,CALC_ERR_SYNTAX
        jr c_fail
e_div0:
        ld a,CALC_ERR_DIV0
        jr c_fail
e_big:
        ld a,CALC_ERR_BIG
        jr c_fail
e_ref:
        ld a,CALC_ERR_REF
        jr c_fail
e_value:
        ld a,CALC_ERR_VALUE
c_fail:
        ld sp,(c_sp)
        push af
        ld a,(c_fn)                 ; EVAL, NUMBER: CB_RESULT = CALC_BAD,
        cp CALC_TEXT                ; CB_AT = where it was
        jr nc,.out
        ld hl,1
        ld (cb + CB_RESULT),hl
        ld hl,#8000
        ld (cb + CB_RESULT + 2),hl
        ld hl,(tp)
        ld de,tbuf
        or a
        sbc hl,de
        ld a,l
        ld (cb + CB_AT),a
        call put_cb
.out:
        pop af
        scf
        ret

; ---- the text --------------------------------------------------------
; -> A = the next character past spaces (tp there); DEHL, BC kept
peek:
        push hl
        ld hl,(tp)
.space:
        ld a,(hl)
        cp " "
        jr nz,.at
        inc hl
        jr .space
.at:
        ld (tp),hl
        pop hl
        ret

; past one character; DEHL, BC, A kept
skip1:
        push hl
        ld hl,(tp)
        inc hl
        ld (tp),hl
        pop hl
        ret

; A -> in capitals (Latin letters)
upper:
        cp "a"
        ret c
        cp "z" + 1
        ret nc
        sub 32
        ret

; a ")" next, or a wrong formula
close:
        call peek
        cp ")"
        jp nz,e_syntax
        jr skip1

deeper:
        ld a,(depth)
        inc a
        cp CALC_DEPTH + 1
        jp nc,e_syntax
        ld (depth),a
        ret
shallower:
        ld a,(depth)
        dec a
        ld (depth),a
        ret

; ---- formulas: DEHL the value ----------------------------------------
expr:
        call term
.more:
        call peek
        cp "+"
        jr z,.op
        cp "-"
        ret nz
.op:
        call skip1
        push af
        push de
        push hl
        call term
        ld (opb),hl
        ld (opb + 2),de
        pop hl
        pop de
        pop af
        cp "-"
        jr z,.sub
        call add32
        jr .more
.sub:
        call sub32
        jr .more

term:
        call unary
.more:
        call peek
        cp "*"
        jr z,.op
        cp "/"
        ret nz
.op:
        call skip1
        push af
        push de
        push hl
        call unary
        ld (opb),hl
        ld (opb + 2),de
        pop hl
        pop de
        pop af
        call set_x
        ld hl,opb
        cp "/"
        jr z,.div
        ld de,md_y                  ; x * y / 100
        call copy4
        ld bc,100
        call set_z
        jr .go
.div:
        ld de,md_z                  ; x * 100 / y
        call copy4
        ld bc,100
        call set_y
.go:
        ld a,1
        call muldiv
        jr .more

; signs before a primary
unary:
        ld b,0
.sign:
        call peek
        cp "+"
        jr z,.skip
        cp "-"
        jr nz,.prim
        inc b
.skip:
        call skip1
        jr .sign
.prim:
        push bc
        call primary
        pop bc
        bit 0,b
        ret z
        jp neg32

primary:
        call peek
        cp "("
        jr z,.paren
        cp "."
        jp z,num_lit
        cp "0"
        jr c,.word
        cp "9" + 1
        jp c,num_lit
.word:
        call cell_at
        jp c,func
        call fetch                  ; a cell: as a number, empty 0
        call mark
        or a
        ret z
        dec a
        jp nz,e_value
        ld hl,0
        ld d,h
        ld e,l
        ret
.paren:
        call skip1
        call deeper
        call expr
        call close
        jp shallower

; a cell at tp? -> D = column, E = row (from 0), tp after it; carry:
; none (tp kept)
cell_at:
        ld hl,(tp)
        ld a,(hl)
        call upper
        sub "A"
        cp 26
        ccf
        ret c
        ld d,a
        inc hl
        ld a,(hl)
        sub "0"
        cp 10
        ccf
        ret c
        ld c,0                      ; the row, 1..255
.digit:
        ld a,(hl)
        sub "0"
        cp 10
        jr nc,.end
        ld b,a
        ld a,c
        cp 26
        ccf
        ret c                       ; > 255
        add a,a
        ld c,a
        add a,a
        add a,a
        add a,c                     ; * 10
        add a,b
        ret c
        ld c,a
        inc hl
        jr .digit
.end:
        ld a,c
        or a
        scf
        ret z
        dec a
        ld e,a
        ld (tp),hl
        or a
        ret

; D = column, E = row -> DEHL: its value in the grid
fetch:
        ld a,(cb + CB_COLS)
        ld b,a
        ld a,d
        cp b
        jp nc,e_ref
        ld a,(cb + CB_ROWS)
        ld c,a
        ld a,e
        cp c
        jp nc,e_ref
        ld c,d                      ; (row * columns + column) * 4
        ld d,0
        ld hl,0
.row:
        add hl,de
        djnz .row
        ld b,0
        add hl,bc
        add hl,hl
        add hl,hl
        ld de,(cb + CB_GRID)
        add hl,de
        ld de,cellv
        ld bc,4
        ld a,(g_cfg)
        call c_in_cfg
        ld hl,(cellv)
        ld de,(cellv + 2)
        ret

; DEHL -> A = 0 a number, 1 CALC_NONE, 2 CALC_BAD
mark:
        ld a,d
        cp #80
        jr nz,.number
        ld a,e
        or h
        jr nz,.number
        ld a,l
        cp 2
        jr nc,.number
        inc a
        ret
.number:
        xor a
        ret

; ---- functions -------------------------------------------------------
; a name at tp, then "(": its arguments, its value
func:
        ld hl,nm                    ; the name, up to 5 letters
        ld b,5
.blank:
        ld (hl)," "
        inc hl
        djnz .blank
        ld hl,(tp)
        ld de,nm
        ld b,6
.letter:
        ld a,(hl)
        call upper
        cp "A"
        jr c,.named
        cp "Z" + 1
        jr nc,.named
        dec b
        jp z,e_syntax
        ld (de),a
        inc de
        inc hl
        jr .letter
.named:
        ld (tp),hl
        ld hl,fn_names              ; which?
        ld c,0
.find:
        push hl
        ld de,nm
        ld b,5
.cmp:
        ld a,(de)
        cp (hl)
        jr nz,.no
        inc hl
        inc de
        djnz .cmp
        pop hl
        jr .found
.no:
        pop hl
        ld de,5
        add hl,de
        inc c
        ld a,c
        cp N_FUNCS
        jr c,.find
        jp e_syntax
.found:
        call peek
        cp "("
        jp nz,e_syntax
        call skip1
        call deeper
        ld a,c
        cp FN_ABS
        jr nc,one_arg
        ld hl,(ag_n)                ; an aggregate: the one around it kept
        push hl
        ld hl,(ag_v)
        push hl
        ld hl,(ag_v + 2)
        push hl
        ld hl,(ag_k)
        push hl
        ld (ag_k),a
        ld hl,0
        ld (ag_n),hl
        ld (ag_v),hl
        ld (ag_v + 2),hl
.arg:
        call agg_arg
        call peek
        cp ","
        jr z,.next
        cp ";"
        jr nz,.end
.next:
        call skip1
        jr .arg
.end:
        call close
        call agg_value
        pop bc
        ld a,c
        ld (ag_k),a
        pop bc
        ld (ag_v + 2),bc
        pop bc
        ld (ag_v),bc
        pop bc
        ld (ag_n),bc
        jp shallower

; A = ABS, INT, ROUND: x (and ROUND's places)
one_arg:
        push af
        call expr
        pop af
        cp FN_INT
        jr z,.int
        jr nc,.round
        bit 7,d                     ; ABS
        call nz,neg32
        jr .end
.int:
        push de
        call set_x                  ; whole hundreds, down
        ld bc,1
        call set_y
        ld bc,100
        call set_z
        xor a
        call muldiv
        pop af
        bit 7,a
        jr z,.whole
        ld a,(rem)
        or a
        jr z,.whole
        ld bc,-1                    ; below 0, not whole: one less
        add hl,bc
        jr c,.whole
        dec de
.whole:
        ld bc,100
        call scale
        jr .end
.round:
        call peek
        ld bc,100                   ; 0 places: to whole hundreds
        cp ","
        jr z,.places
        cp ";"
        jr nz,.to
.places:
        call skip1
        push de
        push hl
        call expr                   ; 0, 1, 2 (or more: as it is)
        ld a,d
        or e
        or h
        ld b,h
        ld c,l
        pop hl
        pop de
        jp m,e_syntax               ; (S from or h: below 0)
        jr nz,.end                  ; >= 2.56: as it is
        ld a,c                      ; 0, 1 or 2 (in hundredths)
        or a
        jr z,.r100
        cp 200
        jr z,.end
        cp 100
        jp nz,e_syntax
        ld bc,10
        jr .to
.r100:
        ld bc,100
.to:
        push bc
        call set_x
        call set_z
        ld bc,1
        call set_y
        ld a,1
        call muldiv
        pop bc
        call scale
.end:
        call close
        jp shallower

; an argument of an aggregate: a range, a cell, or a formula
agg_arg:
        ld hl,(tp)
        ld (ap),hl
        call peek
        call cell_at
        jr c,.expr
        call peek
        cp ":"
        jr z,.range
        cp ","
        jr z,.one
        cp ";"
        jr z,.one
        cp ")"
        jr z,.one
.expr:
        ld hl,(ap)                  ; from its start again
        ld (tp),hl
        call expr
        jp agg_add
.one:
        ld b,d
        ld c,e
        jr .walk
.range:
        call skip1
        push de
        call peek
        call cell_at
        pop bc
        jp c,e_syntax
.walk:
        ld a,d                      ; B, D the columns, C, E the rows:
        cp b                        ; from the lower ones
        jr nc,.cols
        ld d,b
        ld b,a
.cols:
        ld a,e
        cp c
        jr nc,.rows
        ld e,c
        ld c,a
.rows:
        ld a,b
        ld (rg_c1),a
        ld a,d
        ld (rg_c2),a
        ld a,c
        ld (rg_r),a
        ld a,e
        ld (rg_r2),a
.row:
        ld a,(rg_c1)
        ld (rg_c),a
.col:
        ld a,(rg_c)
        ld d,a
        ld a,(rg_r)
        ld e,a
        call fetch
        call mark
        cp 1
        jr z,.skip                  ; no number
        or a
        jp nz,e_value
        call agg_add
.skip:
        ld a,(rg_c)
        ld hl,rg_c2
        cp (hl)
        jr z,.row_end
        inc a
        ld (rg_c),a
        jr .col
.row_end:
        ld a,(rg_r)
        ld hl,rg_r2
        cp (hl)
        ret z
        inc a
        ld (rg_r),a
        jr .row

; DEHL one more value for the aggregate
agg_add:
        ld bc,(ag_n)
        inc bc
        ld (ag_n),bc
        ld a,(ag_k)
        cp FN_MIN
        jr nc,.ext
        ld (opb),hl                 ; SUM, AVG
        ld (opb + 2),de
        ld hl,(ag_v)
        ld de,(ag_v + 2)
        call add32
        jr .keep
.ext:
        cp FN_COUNT
        ret z
        dec bc                      ; the first one
        ld a,b
        or c
        jr z,.keep
        push de
        push hl
        ld bc,(ag_v)                ; it - the one so far
        or a
        sbc hl,bc
        ex de,hl
        ld bc,(ag_v + 2)
        sbc hl,bc
        pop hl
        pop de
        jp po,.no_ov
        jp m,.more                  ; overflow: the sign the other way
        jr .less
.no_ov:
        jp p,.more
.less:
        ld a,(ag_k)
        cp FN_MIN
        ret nz
        jr .keep
.more:
        ld a,(ag_k)
        cp FN_MAX
        ret nz
.keep:
        ld (ag_v),hl
        ld (ag_v + 2),de
        ret

; the aggregate's value -> DEHL
agg_value:
        ld a,(ag_k)
        ld hl,(ag_v)
        ld de,(ag_v + 2)
        cp FN_AVG
        ret c                       ; SUM
        jr z,.avg
        cp FN_COUNT
        ret c                       ; MIN, MAX (none: 0)
        ld hl,(ag_n)
        ld de,0
        ld bc,100
        jr scale
.avg:
        ld bc,(ag_n)
        ld a,b
        or c
        jp z,e_div0
        call set_z
        call set_x
        ld bc,1
        call set_y
        ld a,1
        jr muldiv

; ---- arithmetic: DEHL the value --------------------------------------
; DEHL * BC (whole)
scale:
        call set_x
        call set_y
        ld bc,1
        call set_z
        xor a
        ; fall through
; A = 1: rounded. md_x * md_y / md_z -> DEHL, rem (the remainder)
muldiv:
        ld (md_rnd),a
        xor a
        ld (md_sign),a
        ld hl,md_x
        call absm
        ld hl,md_y
        call absm
        ld hl,md_z
        call absm
        ld hl,md_z
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        inc hl
        or (hl)
        jp z,e_div0
        ld hl,prod                  ; prod = x * y, 64 bits
        ld b,8
.clear:
        ld (hl),0
        inc hl
        djnz .clear
        ld b,32
.mul:
        push bc
        ld hl,prod
        ld b,8
        or a
        call rlm
        ld hl,md_y
        ld b,4
        or a
        call rlm
        jr nc,.no_add
        ld hl,prod
        ld de,md_x
        ld b,8
        call addm
.no_add:
        pop bc
        djnz .mul
        ld a,(md_rnd)               ; rounded: + z / 2
        or a
        jr z,.div
        ld hl,md_z
        ld de,md_t
        call copy4
        ld hl,md_t + 3
        ld b,4
        or a
.half:
        rr (hl)
        dec hl
        djnz .half
        ld hl,prod
        ld de,md_t
        ld b,8
        call addm
.div:
        ld hl,rem                   ; prod / z: 64 steps
        ld b,5
.zero:
        ld (hl),0
        inc hl
        djnz .zero
        ld b,64
.step:
        push bc
        ld hl,prod
        ld b,8
        or a
        call rlm
        ld hl,rem
        ld b,5
        call rlm
        ld hl,rem
        ld de,md_z
        ld b,5
        call subm
        jr nc,.fits
        ld hl,rem
        ld de,md_z
        ld b,5
        call addm
        jr .next
.fits:
        ld hl,prod
        set 0,(hl)
.next:
        pop bc
        djnz .step
        ld hl,(prod + 4)            ; the quotient: 31 bits at most
        ld a,h
        or l
        ld hl,(prod + 6)
        or h
        or l
        jp nz,e_big
        ld hl,(prod)
        ld de,(prod + 2)
        bit 7,d
        jp nz,e_big
        call fit
        ld a,(md_sign)
        or a
        ret z
        ; fall through
neg32:
        xor a
        sub l
        ld l,a
        ld a,0
        sbc a,h
        ld h,a
        ld a,0
        sbc a,e
        ld e,a
        ld a,0
        sbc a,d
        ld d,a
        ret

; DEHL + opb, DEHL - opb
add32:
        ld bc,(opb)
        add hl,bc
        ex de,hl
        ld bc,(opb + 2)
        adc hl,bc
        ex de,hl
        jp pe,e_big
        jr fit
sub32:
        ld bc,(opb)
        or a
        sbc hl,bc
        ex de,hl
        ld bc,(opb + 2)
        sbc hl,bc
        ex de,hl
        jp pe,e_big
        ; fall through
; DEHL must be a number: not CALC_NONE, CALC_BAD, or #7FFFFFFF (whose
; negative is CALC_BAD)
fit:
        call mark
        or a
        jp nz,e_big
        ld a,d
        cp #7F
        ret nz
        ld a,e
        and h
        and l
        inc a
        ret nz
        jp e_big

; HL -> 4 bytes: their absolute value (md_sign changes if below 0)
absm:
        push hl
        inc hl
        inc hl
        inc hl
        bit 7,(hl)
        pop hl
        ret z
        ld a,(md_sign)
        xor 1
        ld (md_sign),a
        ld b,4
        or a
.neg:
        ld a,0
        sbc a,(hl)
        ld (hl),a
        inc hl
        djnz .neg
        ret

; B bytes at HL one bit left, the carry in (-> the top bit in carry)
rlm:
        rl (hl)
        inc hl
        djnz rlm
        ret
; B bytes: (HL) + (DE), (HL) - (DE) -> carry
addm:
        or a
.add:
        ld a,(de)
        adc a,(hl)
        ld (hl),a
        inc hl
        inc de
        djnz .add
        ret
subm:
        or a
.sub:
        ld a,(de)
        ld c,a
        ld a,(hl)
        sbc a,c
        ld (hl),a
        inc hl
        inc de
        djnz .sub
        ret

; DEHL into md_x; BC into md_y, md_z (and 0 above them)
set_x:
        ld (md_x),hl
        ld (md_x + 2),de
        push hl
        ld hl,0
        ld (md_x + 4),hl
        ld (md_x + 6),hl
        pop hl
        ret
set_y:
        ld (md_y),bc
        push hl
        ld hl,0
        ld (md_y + 2),hl
        pop hl
        ret
set_z:
        ld (md_z),bc
        push hl
        ld hl,0
        ld (md_z + 2),hl
        ld (md_z + 4),hl
        ld (md_z + 6),hl
        pop hl
        ret
; 4 bytes from HL to DE (and 0 in the 4 after them)
copy4:
        push bc
        ld bc,4
        ldir
        ex de,hl
        ld b,4
.zero:
        ld (hl),0
        inc hl
        djnz .zero
        pop bc
        ret

; ---- numbers and text ------------------------------------------------
; a number at tp: digits, maybe a "." and decimals (the third one
; rounds, the ones after it do not count) -> DEHL
num_lit:
        ld hl,0
        ld d,h
        ld e,l
        ld a,#FF
        ld (n_dec),a                ; #FF: no "." yet
        xor a
        ld (n_any),a
        ld (n_rnd),a
.char:
        push hl
        ld hl,(tp)
        ld a,(hl)
        inc hl
        ld (tp),hl
        pop hl
        cp "."
        jr z,.point
        sub "0"
        cp 10
        jr nc,.end
        ld c,a
        ld a,1
        ld (n_any),a
        ld a,(n_dec)
        cp 2
        jr c,.add                   ; a first or second decimal
        inc a
        jr z,.add                   ; before the "."
        dec a
        cp 2
        jr nz,.char                 ; after the third
        ld a,3
        ld (n_dec),a
        ld a,c                      ; the third: rounds
        cp 5
        jr c,.char
        ld a,1
        ld (n_rnd),a
        jr .char
.add:
        push bc
        call mul10
        pop bc
        ld b,0
        add hl,bc
        jr nc,.added
        inc de
.added:
        bit 7,d
        jp nz,e_big
        ld a,(n_dec)
        inc a
        jr z,.char
        ld (n_dec),a
        jr .char
.point:
        ld a,(n_dec)
        inc a
        jr nz,.end                  ; a second one
        ld (n_dec),a
        jr .char
.end:
        push hl                     ; tp back at what ended it
        ld hl,(tp)
        dec hl
        ld (tp),hl
        pop hl
        ld a,(n_any)
        or a
        jp z,e_syntax
        ld a,(n_dec)                ; hundredths
        inc a
        jr nz,.places
        ld a,1                      ; none: * 100
.places:
        dec a                       ; decimals
        cp 2
        jr nc,.round
        call mul10
        cp 1
        jr z,.round
        call mul10
.round:
        ld a,(n_rnd)
        ld c,a
        ld b,0
        add hl,bc
        jr nc,.fit
        inc de
.fit:
        jp fit

; DEHL * 10; too big: e_big
mul10:
        push af
        push de
        push hl
        call dbl                    ; * 4 + 1, * 2
        call dbl
        pop bc
        add hl,bc
        ex de,hl
        pop bc
        adc hl,bc
        ex de,hl
        jp c,e_big
        call dbl
        bit 7,d
        jp nz,e_big
        pop af
        ret
dbl:
        add hl,hl
        ex de,hl
        adc hl,hl
        ex de,hl
        ret nc
        jp e_big

; DEHL (a number) -> text at obuf, DE after it: "-12.5", "0.25", "7"
num_text:
        ld bc,obuf
        push bc
        bit 7,d
        jr z,.pos
        call neg32
        ex (sp),hl
        ld (hl),"-"
        inc hl
        ex (sp),hl
.pos:
        ld ix,dg                    ; digits, the last first, 3 at least
        ld c,0
.digit:
        call div10
        add a,"0"
        ld (ix + 0),a
        inc ix
        inc c
        ld a,d
        or e
        or h
        or l
        jr nz,.digit
        ld a,c
        cp 3
        jr c,.digit
        pop de
        dec ix
        ld b,c
        dec b
        dec b
.whole:
        ld a,(ix + 0)
        ld (de),a
        inc de
        dec ix
        djnz .whole
        ld a,(dg)                   ; ".5", ".25", or none
        ld c,a
        ld a,(dg + 1)
        cp "0"
        jr nz,.point
        ld a,c
        cp "0"
        ret z
        ld a,(dg + 1)
.point:
        ex de,hl
        ld (hl),"."
        inc hl
        ld (hl),a
        inc hl
        ex de,hl
        ld a,c
        cp "0"
        ret z
        ld (de),a
        inc de
        ret

; DEHL / 10 -> DEHL, A = the remainder
div10:
        ld b,32
        xor a
.bit:
        add hl,hl
        rl e
        rl d
        rla
        cp 10
        jr c,.next
        sub 10
        inc l
.next:
        djnz .bit
        ret

; ---- the program's memory --------------------------------------------
        IFDEF CALC_HARNESS
c_in:                               ; BC bytes from HL (program) to DE
c_out:                              ; HL -> DE (program)
c_in_cfg:                           ; (A: its bank)
        ldir
        ret
data_get:
vw_cfg          equ #0040           ; (any byte)
        ret
        ELSE
c_in:
        ld a,(vw_cfg)
c_in_cfg:                           ; A = its bank
        ld (ab_from),a
        ld a,EXT2_CFG
        ld (ab_to),a
        jp bank_copy
c_out:
        ld a,EXT2_CFG
        ld (ab_from),a
        ld a,(vw_cfg)
        ld (ab_to),a
        jp bank_copy
        ENDIF

; ---- data ------------------------------------------------------------
FN_SUM          equ 0
FN_AVG          equ 1
FN_MIN          equ 2
FN_MAX          equ 3
FN_COUNT        equ 4
FN_ABS          equ 5
FN_INT          equ 6
FN_ROUND        equ 7
fn_names:       db "SUM  AVG  MIN  MAX  COUNTABS  INT  ROUND"
        assert $ - fn_names == N_FUNCS * 5

c_fn:           db 0
c_hl:           dw 0
c_cb:           dw 0
c_sp:           dw 0
cb:             ds CB_SIZE
g_cfg:          db 0
tp:             dw 0
ap:             dw 0
depth:          db 0
opb:            ds 4
cellv:          ds 4
nm:             ds 5
ag_k:           dw 0                ; (a byte; dw to push)
ag_n:           dw 0
ag_v:           ds 4
rg_c1:          db 0
rg_c2:          db 0
rg_c:           db 0
rg_r:           db 0
rg_r2:          db 0
n_dec:          db 0
n_any:          db 0
n_rnd:          db 0
md_rnd:         db 0
md_sign:        db 0
md_x:           ds 8
md_y:           ds 4
md_z:           ds 8
md_t:           ds 8
prod:           ds 8
rem:            ds 5
dg:             ds 12
        IFDEF CALC_HARNESS
tbuf:           ds T_ROOM
obuf:           ds 16
        ELSE
tbuf            equ u8_buf          ; (kernel/ext2.asm)
obuf            equ u8_buf + T_ROOM
        ENDIF
calc_stop:

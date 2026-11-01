; =====================================================================
; vrouves.asm - VROUVES: LET'S GO FOR VROUVES for V-OS (made with the SDK)
;
; A tower defence game after the CPC game by the same author: the
; invaders of Frankenstein & Moreau CO. come down the road to the
; Kafenio of Zoniana, and the villagers build defenders beside it to
; save its sacks of vrouves. Simplified: the seven stages, each with
; ten waves of three invaders and the defenders the original has there;
; no neighbour bonus, no projectiles in flight, no music. VROUVES.SAV,
; beside the stages, keeps the furthest stage reached (CONTINUE) and
; the five best scores (a score: the rewards, and the greens left at
; each stage won).
;
; Mode 0, the original's art and palette (art.asm, import_art.py). A
; stage, VROUVn.DAT, from the drive the game was run from, is loaded
; into the data bank: its head (map, cell kinds, roads, waves, the
; defenders it has, its name) is copied here, and its cells
; (8 x 12 pixels) are read from there when they are drawn, through a
; small cache. Logic runs at 25 Hz (every other VE_FRAME); the screen
; is brought up to date every other tick: what moved is erased by
; drawing the stage's cells there again, then every invader, effect and
; the cursor are drawn.
;
;   make app NAME=vrouves     build/VROUVES.BIN, on build/vrouves.dsk
;                             with the seven stages
; =====================================================================

        include "api/vos_api.inc"

MW              equ 20              ; the map: 20 x 14 cells of 8 x 12
MH              equ 14
CELLS           equ MW * MH
PF_X            equ 16              ; the playfield on the screen (pixels)
PF_Y            equ 16
PF_XB           equ PF_X / 2        ; in screen bytes (2 pixels each)
HUD_Y           equ PF_Y + MH * 12 + 4

STAGE_BANK      equ #4000           ; VROUV1.DAT in the data bank
CELL_BANK       equ STAGE_BANK + #400
ST_KIND         equ #118            ; offsets in the stage (import_art.py)
ST_ROAD         equ #230
ST_AIR          equ #258
ST_WAVES        equ #280
ST_UNLOCK       equ #2E0            ; bit n-1: it has defender n
ST_TOUGH        equ #2E1            ; invaders as this many waves later
ST_NAME         equ #2E2            ; in English, then Greek: 0-ended
ST_NAME_EL      equ #2FB
ST_HEAD         equ #320            ; what is copied here
STAGES          equ 7
CACHE_N         equ 4               ; cells kept ready for VOS_BLIT
K_GRASS         equ 0
K_ROAD          equ 1
K_BLOCK         equ 2

; invader (16 bytes)
E_TYPE          equ 0               ; 0 free, 1 drone, 2 guard, 3 tank
E_HP            equ 1
E_ARM           equ 2
E_SPD           equ 3               ; path steps a tick, x 16
E_ACC           equ 4
E_FX            equ 5               ; fine position: 12 a cell, 3 a byte
E_FY            equ 6
E_WP            equ 7               ; the waypoint it goes to
E_SLOW          equ 8               ; ticks of half speed left
E_ANIM          equ 9
E_DIR           equ 10              ; 0 up / down, 1 left, 2 right
E_OX            equ 11              ; where it is drawn (byte), #FF none
E_OY            equ 12
E_OFR           equ 13              ; and with which frame
E_PROG          equ 14              ; steps walked (word)
EN_SZ           equ 16
MAX_EN          equ 16

; defender (4 bytes)
T_TYPE          equ 0               ; 0 free, 1..6
T_C             equ 1
T_R             equ 2
T_CD            equ 3               ; ticks until it fires again
T_SZ            equ 4
MAX_T           equ 48

; effect (4 bytes)
X_SPR           equ 0               ; FX_*, #FF free
X_XB            equ 1
X_Y             equ 2
X_LIFE          equ 3
X_SZ            equ 4
MAX_FX          equ 8
FX_SPARK        equ 0
FX_PUFF         equ 1
FX_BASH         equ 2
FX_POOF         equ 3
FX_BOOM         equ 4
FX_ZAP          equ 5

; defender types: cost, range, cooldown, damage, flags, effect, sell, -
TF_AIR          equ 1               ; hits drones
TF_PIERCE       equ 2               ; ignores armour
TF_SLOW         equ 4               ; slows the walkers in range
TF_AREA         equ 8               ; hits every walker in range
TF_SPLASH       equ 16              ; and those next to its target
TF_CRIT         equ 32              ; every fourth shot x 3
TF_HOVER        equ 64              ; may stand on blocked cells

START_FUNDS     equ 120
FIRST_WAIT      equ 45              ; seconds before the first wave
NEXT_WAIT       equ 15
WAVES           equ 10

HUD_FUNDS       equ 1               ; what the HUD writes again
HUD_HP          equ 2
HUD_WAVE        equ 4
HUD_CD          equ 8
HUD_INFO        equ 16
HUD_BAR         equ 32
HUD_SCORE       equ 64
HUD_ALL         equ 127

CMD_NEW         equ VC_APP + 1
CMD_NEXT        equ VC_APP + 2
CMD_PAUSE       equ VC_APP + 3
CMD_ABOUT       equ VC_APP + 4
CMD_BACK        equ VC_APP + 5
CMD_CONT        equ VC_APP + 6
CMD_SCORES      equ VC_APP + 7
SAVE_SIZE       equ 1 + 5 * 10      ; stage reached; 5 x name (8), score

KEY_1           equ 64              ; key numbers (lang/en/keymap.txt)
KEY_2           equ 65
KEY_3           equ 57
KEY_4           equ 56
KEY_5           equ 49
KEY_6           equ 48
KEY_N           equ 46
KEY_P           equ 27
KEY_S           equ 60

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION
        include "app_icon.asm"      ; VOS_ICON, from icon.txt

; A = 0: a new start; 2: back from a view or another program (the data
; bank is shared, so the stage is loaded again)
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
        ld a,1
        call VOS_TICKS
        pop af
        push af
        cp 2
        jr z,.again
        ld a,(VOS_SELF)             ; the stages are on its drive
        ld (drive),a
        ld a,1
        ld (stage_no),a
        call load_save
.again:
        call load_stage
        call c,VOS_ERROR
        pop af
        cp 2
        call nz,new_game
        ; fall through

; everything, again
redraw:
        ld a,(loaded)
        or a
        ret z
        xor a
        call VOS_CLS
        call VOS_DRAW_BAR
        ld bc,0                     ; every cell (and its defender)
.cell:
        push bc
        call draw_cell
        pop bc
        inc c
        ld a,c
        cp MW
        jr c,.cell
        ld c,0
        inc b
        ld a,b
        cp MH
        jr c,.cell
        call forget_drawn
        ld a,HUD_ALL
        ld (hud),a
        ld a,1
        ld (dirty),a
        call draw_tick
        call hud_draw
        ld a,(board)
        or a
        ret z
        jp draw_board

; stage_no into the data bank, its head here -> carry, A = error
load_stage:
        xor a
        ld (loaded),a
        ld a,(stage_no)
        add a,"0"
        ld (stage_name + 5),a
        ld a,(drive)
        or VOS_DATA
        ld hl,stage_name
        ld de,STAGE_BANK
        call VOS_LOAD
        ret c
        ld hl,STAGE_BANK
        ld de,stage
        ld bc,ST_HEAD
        call VOS_BANK_GET
        ld hl,cache_tag             ; the cache is empty
        ld b,CACHE_N
.tag:
        ld (hl),0
        inc hl
        djnz .tag
        ld a,1
        ld (loaded),a
        or a
        ret

; NEW GAME, and after the last stage: stage 1; CONTINUE: the furthest
; one (stage 1 if it is not on this disc). A new run: no score.
stage_one:
        ld a,1
start_at:
        ld (stage_no),a
        ld hl,0
        ld (score),hl
        call load_stage
        jr nc,.ok
        ld a,1
        ld (stage_no),a
        call load_stage
        call c,VOS_ERROR
.ok:
        call new_game
        jp redraw
continue:
        ld a,(save_buf)
        jr start_at

; the save file -> save_buf; none: stage 1, no scores
load_save:
        ld a,(drive)
        ld hl,save_name
        ld de,save_buf
        call VOS_LOAD
        ret nc
        ld hl,save_buf
        ld de,save_buf + 1
        ld bc,SAVE_SIZE - 1
        ld (hl),0
        ldir
        ld a,1
        ld (save_buf),a
        ret

write_save:
        ld a,(drive)
        ld hl,save_name
        ld de,save_buf
        ld bc,SAVE_SIZE
        call VOS_SAVE
        ret nc
        jp VOS_ERROR

; DE = points: to the score, at most 9999
add_score:
        ld hl,(score)
        add hl,de
        push hl
        ld de,-10000
        add hl,de
        pop hl
        jr nc,.ok
        ld hl,9999
.ok:
        ld (score),hl
        ld a,HUD_SCORE
        jp hud_set

; the run is over: a score better than the fifth gets a name and a
; place, is saved, and the best five are shown
record:
        ld ix,save_buf + 1 + 4 * 10
        ld e,(ix + 8)
        ld d,(ix + 9)
        ld hl,(score)
        or a
        sbc hl,de
        ret c
        ret z
        xor a
        ld (name_buf),a
        ld a,T_NAME
        ld hl,name_buf
        ld c,8
        call VOS_INPUT
        ret c
        ld ix,save_buf + 1          ; its place: above the first lower one
        ld b,5
.find:
        ld e,(ix + 8)
        ld d,(ix + 9)
        ld hl,(score)
        or a
        sbc hl,de
        jr z,.below
        jr nc,.here
.below:
        ld de,10
        add ix,de
        djnz .find
        ret
.here:
        push ix                     ; the lower ones down one place
        pop de
        ld hl,save_buf + SAVE_SIZE - 10
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld a,b
        or c
        jr z,.put
        ld hl,save_buf + SAVE_SIZE - 11
        ld de,save_buf + SAVE_SIZE - 1
        lddr
.put:
        push ix
        pop de
        ld hl,name_buf
        ld b,8
.name:
        ld a,(hl)
        or a
        jr z,.pad
        ld (de),a
        inc hl
        inc de
        djnz .name
        jr .score
.pad:
        ld a," "
        ld (de),a
        inc de
        djnz .pad
.score:
        ld hl,(score)
        ld (ix + 8),l
        ld (ix + 9),h
        call write_save
        ; fall through

; HIGH SCORES: the best five over the playfield, until a key or a click
show_board:
        ld a,1
        ld (board),a
draw_board:
        push ix
        ld ix,board_rect
        call VOS_RECT
        ld a,T_SCORES
        ld hl,40
        ld de,52
        ld c,14
        call label_w
        ld ix,save_buf + 1
        ld a,72
        ld (bd_y),a
        ld b,5
.line:
        push bc
        push ix                     ; the name, 8 characters
        pop hl
        ld de,line
        ld b,8
.copy:
        ld a,(hl)
        or a
        jr nz,.char
        ld a," "
.char:
        ld (de),a
        inc hl
        inc de
        djnz .copy
        xor a
        ld (de),a
        ld a,1
        ld c,0
        call VOS_COLOURS
        ld a,(bd_y)
        ld e,a
        ld d,0
        ld hl,40
        ld bc,line
        call VOS_PRINT
        ld l,(ix + 8)               ; the score, if any
        ld h,(ix + 9)
        ld a,h
        or l
        jr z,.empty
        ld a,(bd_y)
        ld c,a
        ld b,0
        ld de,112
        call number
.empty:
        ld de,10
        add ix,de
        ld hl,bd_y
        ld a,12
        add a,(hl)
        ld (hl),a
        pop bc
        djnz .line
        pop ix
        ret

new_game:
        ld hl,game_vars
        ld de,game_vars + 1
        ld bc,game_end - game_vars - 1
        ld (hl),0
        ldir
        ld hl,towers                ; no defenders, no invaders, effects
        ld de,towers + 1
        ld bc,MAX_T * T_SZ - 1
        ld (hl),0
        ldir
        ld hl,enemies
        ld de,enemies + 1
        ld bc,MAX_EN * EN_SZ - 1
        ld (hl),0
        ldir
        ld hl,fxs
        ld b,MAX_FX * X_SZ
.fx:
        ld (hl),#FF
        inc hl
        djnz .fx
        ld hl,tmap
        ld de,tmap + 1
        ld bc,CELLS - 1
        ld (hl),0
        ldir
        ld hl,START_FUNDS
        ld (funds),hl
        ld a,100
        ld (hp),a
        ld a,FIRST_WAIT
        ld (cd_sec),a
        ld a,1
        ld (sel),a
        ld a,10
        ld (cur_c),a
        ld a,6
        ld (cur_r),a
        ld a,HUD_ALL
        ld (hud),a
        ret

; ---------------------------------------------------------------------
; events
; ---------------------------------------------------------------------
event:
        ld a,(hl)
        cp VE_FRAME
        jp z,frame
        push hl
        call VOS_UI_EVENT
        pop hl
        or a
        jp nz,command
        call VOS_MENU_OPEN
        ret nz
        ld a,(board)
        or a
        jr z,.play
        ld a,(hl)                   ; the best five shown: a key or a
        cp VE_KEY_DOWN              ; click closes them
        jr z,.close
        cp VE_PTR_DOWN
        ret nz
.close:
        xor a
        ld (board),a
        jp redraw
.play:
        ld a,(hl)
        cp VE_PTR_DOWN
        jp z,click
        cp VE_KEY_DOWN
        jr z,.key
        cp VE_KEY_REPEAT
        ret nz
.key:
        inc hl
        ld a,(hl)                   ; the key number
        ld hl,keys
.find:
        ld b,(hl)                   ; key, handler (0: the end)
        inc hl
        inc b
        ret z
        dec b
        cp b
        jr z,.found
        inc hl
        inc hl
        jr .find
.found:
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

; db key: dw handler; ends with #FF
keys:           db VK_UP : dw cur_up
                db VK_DOWN : dw cur_down
                db VK_LEFT : dw cur_left
                db VK_RIGHT : dw cur_right
                db VK_SPACE : dw build
                db VK_RETURN : dw build
                db VK_ENTER : dw build
                db KEY_S : dw sell
                db VK_DEL : dw sell
                db KEY_N : dw next_wave
                db KEY_P : dw pause
                db KEY_1 : dw sel_1
                db KEY_2 : dw sel_2
                db KEY_3 : dw sel_3
                db KEY_4 : dw sel_4
                db KEY_5 : dw sel_5
                db KEY_6 : dw sel_6
                db #FF

command:
        cp CMD_NEW
        jp z,stage_one
        cp CMD_CONT
        jp z,continue
        cp CMD_SCORES
        jp z,show_board
        cp CMD_NEXT
        jp z,next_wave
        cp CMD_PAUSE
        jp z,pause
        cp CMD_ABOUT
        jr nz,.not_about
        ld hl,dlg_about
        jp VOS_DIALOG
.not_about:
        cp CMD_BACK
        jp z,VOS_EXIT
        jp VOS_COMMAND

pause:
        ld hl,paused
        ld a,(hl)
        xor 1
        ld (hl),a
        ld a,HUD_INFO
        jp hud_set

sel_1:  ld a,1
        jr select
sel_2:  ld a,2
        jr select
sel_3:  ld a,3
        jr select
sel_4:  ld a,4
        jr select
sel_5:  ld a,5
        jr select
sel_6:  ld a,6
select:
        ld c,a
        call has_type
        ret nc
        ld a,c
        ld (sel),a
        ld a,HUD_BAR + HUD_INFO
        call hud_set
        call cursor_moved
        jp hud_draw

; A = defender 1..6 -> carry if this stage has it (BC kept)
has_type:
        push bc
        ld b,a
        ld a,(stage + ST_UNLOCK)
.bit:
        rrca
        djnz .bit
        pop bc
        ret

cur_up:
        ld hl,cur_r
        ld a,(hl)
        or a
        ret z
        dec a
        jr cur_set
cur_down:
        ld hl,cur_r
        ld a,(hl)
        cp MH - 1
        ret nc
        inc a
        jr cur_set
cur_left:
        ld hl,cur_c
        ld a,(hl)
        or a
        ret z
        dec a
        jr cur_set
cur_right:
        ld hl,cur_c
        ld a,(hl)
        cp MW - 1
        ret nc
        inc a
cur_set:                            ; HL -> cur_c or cur_r, A = new
        push af
        push hl
        call cursor_off
        pop hl
        pop af
        ld (hl),a
cursor_moved:
        ld a,1
        ld (cur_dirty),a
        ret

; the cell under the cursor drawn again (the cursor gone)
cursor_off:
        ld a,(cur_c)
        ld c,a
        ld a,(cur_r)
        ld b,a
        jp draw_cell

; a click: on the playfield, the cursor there and build; on the bar,
; choose that defender
click:
        inc hl
        inc hl
        inc hl
        inc hl
        ld e,(hl)                   ; x
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)                   ; y
        inc hl
        ld b,(hl)
        ld a,b
        or a
        ret nz
        ld a,c
        cp HUD_Y + 24               ; the bar: x 16 + 28 each
        jr c,.field
        cp HUD_Y + 24 + 14
        ret nc
        ld a,d
        or a
        ret nz
        ld a,e
        sub PF_X
        ret c
        ld b,0
.slot:
        inc b
        sub 28
        jr nc,.slot
        ld a,b
        cp 7
        ret nc
        jp select
.field:
        sub PF_Y
        ret c
        ld b,0                      ; row = y / 12
.row:
        cp 12
        jr c,.rowed
        sub 12
        inc b
        jr .row
.rowed:
        ld a,b
        cp MH
        ret nc
        ld a,d
        or a
        ret nz
        ld a,e
        sub PF_X
        ret c
        rrca                        ; column = x / 8
        rrca
        rrca
        and 31
        cp MW
        ret nc
        push af
        push bc
        call cursor_off
        pop bc
        pop af
        ld (cur_c),a
        ld a,b
        ld (cur_r),a
        call cursor_moved
        ; fall through

; build the chosen defender on the cursor's cell
build:
        call cur_cell               ; HL = cell number
        push hl
        ld de,tmap
        add hl,de
        ld a,(hl)
        pop hl
        or a
        jp nz,err_sound             ; taken
        ld de,stage + ST_KIND
        add hl,de
        ld a,(hl)
        cp K_GRASS
        jr z,.place
        cp K_BLOCK
        jp nz,err_sound             ; the road or the Kafenio
        ld a,(sel)
        call ttype_ptr
        inc hl
        inc hl
        inc hl
        inc hl
        bit 6,(hl)                  ; TF_HOVER
        jp z,err_sound
.place:
        ld a,(sel)
        call ttype_ptr
        ld e,(hl)                   ; the cost
        ld d,0
        ld hl,(funds)
        or a
        sbc hl,de
        jp c,err_sound
        push hl
        ld ix,towers                ; a free record
        ld b,MAX_T
        ld de,T_SZ
.free:
        ld a,(ix + T_TYPE)
        or a
        jr z,.got
        add ix,de
        djnz .free
        pop hl
        jp err_sound
.got:
        pop hl
        ld (funds),hl
        ld a,(sel)
        ld (ix + T_TYPE),a
        ld a,(cur_c)
        ld (ix + T_C),a
        ld a,(cur_r)
        ld (ix + T_R),a
        ld (ix + T_CD),0
        call cur_cell
        ld de,tmap
        add hl,de
        ld a,(sel)
        ld (hl),a
        call cursor_off             ; the cell, with the defender
        call cursor_moved
        ld a,2                      ; a short note
        ld hl,95
        ld bc,#040C
        call VOS_SOUND
        ld a,HUD_FUNDS
        call hud_set
        jp hud_draw

; sell the defender on the cursor's cell: half its cost back
sell:
        call cur_cell
        ld de,tmap
        add hl,de
        ld a,(hl)
        or a
        jp z,err_sound
        ld (hl),0
        push af
        call ttype_ptr
        ld de,6
        add hl,de
        ld e,(hl)
        ld d,0
        ld hl,(funds)
        add hl,de
        ld (funds),hl
        pop af
        ld ix,towers                ; its record
        ld b,MAX_T
.find:
        ld a,(ix + T_TYPE)
        or a
        jr z,.next
        ld a,(cur_c)
        cp (ix + T_C)
        jr nz,.next
        ld a,(cur_r)
        cp (ix + T_R)
        jr z,.found
.next:
        ld de,T_SZ
        add ix,de
        djnz .find
        jr .gone
.found:
        ld (ix + T_TYPE),0
.gone:
        call cursor_off
        call cursor_moved
        ld a,HUD_FUNDS
        call hud_set
        jp hud_draw

err_sound:
        ld a,2
        ld hl,600
        ld bc,#060C
        jp VOS_SOUND

; -> HL = the cursor's cell number
cur_cell:
        ld a,(cur_r)
        ld c,a
        ld a,(cur_c)
; C = row, A = column -> HL = row * 20 + column
cell_num:
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld e,a
        ld d,0
        add hl,de
        ret

; N: the next wave now, half the seconds left paid
next_wave:
        ld a,(state)
        or a
        ret nz                      ; only while counting down
        ld a,(cd_sec)
        srl a
        ld e,a
        ld d,0
        ld hl,(funds)
        add hl,de
        ld (funds),hl
        jp start_wave

; ---------------------------------------------------------------------
; the game, 25 times a second
; ---------------------------------------------------------------------
frame:
        call VOS_MENU_OPEN          ; a menu over the screen: nothing
        ret nz
        ld a,(loaded)
        or a
        ret z
        ld a,(board)
        or a
        ret nz
        ld hl,ticks
        inc (hl)
        bit 0,(hl)
        ret z
        ld a,(paused)
        or a
        jr z,.play
        call draw_tick              ; paused: the cursor still moves
        jr .drawn
.play:
        call waves_tick
        call enemies_tick
        call towers_tick
        call fx_tick
        ld a,(ticks)                ; the screen every other tick
        and 2
        call nz,draw_tick
.drawn:
        call hud_draw
        ld a,(hp)
        or a
        jr z,.lost
        ld a,(state)
        cp 2
        ret nz
.won:                               ; on to the next stage
        ld a,(hp)                   ; the greens left: points
        ld e,a
        ld d,0
        call add_score
        ld a,(stage_no)
        cp STAGES
        ld hl,dlg_final
        jr nc,.over
        ld hl,dlg_win
        call VOS_DIALOG
        ld hl,stage_no
        inc (hl)
        call load_stage
        jr c,.more
        ld a,(stage_no)             ; the furthest stage, saved
        ld hl,save_buf
        cp (hl)
        jr c,.again
        jr z,.again
        ld (hl),a
        call write_save
        jr .again
.more:
        ld hl,dlg_more              ; not on this disc
.over:                              ; the run is over
        call VOS_DIALOG
        call record
        jp stage_one
.lost:                              ; this stage again, a new run
        ld hl,dlg_lose
        call VOS_DIALOG
        call record
        ld hl,0
        ld (score),hl
.again:
        call new_game
        jp redraw

; the waves: a countdown, then the groups spawn, then all gone
waves_tick:
        ld a,(state)
        or a
        jr nz,.running
        ld hl,cd_sub                ; counting down: a second is 25 ticks
        inc (hl)
        ld a,(hl)
        cp 25
        ret c
        ld (hl),0
        ld hl,cd_sec
        dec (hl)
        ld a,HUD_CD
        call hud_set
        ld a,(cd_sec)
        or a
        ret nz
        jp start_wave
.running:
        cp 1
        ret nz
        ld ix,groups                ; each group: type, left, interval, timer
        ld b,3
        ld c,0                      ; groups still spawning
.group:
        ld a,(ix + 1)
        or a
        jr z,.done
        inc c
        dec (ix + 3)
        jr nz,.done
        ld a,(ix + 2)
        ld (ix + 3),a
        push bc
        ld a,(ix + 0)
        call spawn
        pop bc
        jr nc,.done                 ; no room: try again next tick
        dec (ix + 1)
.done:
        ld de,4
        add ix,de
        djnz .group
        ld a,c
        or a
        ret nz
        ld a,(en_count)             ; all spawned: and all gone?
        or a
        ret nz
        ld a,(wave)
        cp WAVES
        jr nc,.won
        xor a
        ld (state),a
        ld (cd_sub),a
        ld a,NEXT_WAIT
        ld (cd_sec),a
        ld a,HUD_CD + HUD_WAVE
        jp hud_set
.won:
        ld a,2
        ld (state),a
        ret

start_wave:
        ld a,(wave)
        cp WAVES
        ret nc
        ld l,a                      ; its groups: stage + ST_WAVES + 9 x
        add a,a
        add a,a
        add a,a
        add a,l
        ld e,a
        ld d,0
        inc l
        ld a,l
        ld (wave),a
        ld hl,stage + ST_WAVES
        add hl,de
        ld de,groups
        ld b,3
.group:
        ld a,(hl)                   ; type
        ld (de),a
        inc de
        inc hl
        ld a,(hl)                   ; count
        ld (de),a
        inc de
        inc hl
        ld a,(hl)                   ; interval
        ld (de),a
        inc de
        inc hl
        ld a,4                      ; the first one soon
        ld (de),a
        inc de
        djnz .group
        ld a,1
        ld (state),a
        ld a,2                      ; the wave's horn
        ld hl,213
        ld bc,#140C
        call VOS_SOUND
        ld a,HUD_WAVE + HUD_CD + HUD_INFO
        jp hud_set

; A = type -> carry: an invader at the start of its way
spawn:
        push ix
        ld e,a
        ld ix,enemies
        ld b,MAX_EN
.free:
        ld a,(ix + E_TYPE)
        or a
        jr z,.got
        push de
        ld de,EN_SZ
        add ix,de
        pop de
        djnz .free
        pop ix
        or a
        ret
.got:
        ld a,e
        ld (ix + E_TYPE),a
        call etype_ptr              ; hp: base + per wave x (wave
        ld a,(stage + ST_TOUGH)     ; + the stage's toughness)
        ld b,a
        ld a,(wave)
        add a,b
        ld b,a
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
.hp:
        add a,e
        jr nc,.ok
        ld a,255
.ok:
        djnz .hp
        ld (ix + E_HP),a
        ld a,(hl)
        inc hl
        ld (ix + E_SPD),a
        ld a,(hl)
        ld (ix + E_ARM),a
        xor a
        ld (ix + E_ACC),a
        ld (ix + E_SLOW),a
        ld (ix + E_DIR),a
        ld (ix + E_PROG),a
        ld (ix + E_PROG + 1),a
        ld (ix + E_OX),#FF
        call VOS_RANDOM
        ld (ix + E_ANIM),a
        call way_ptr                ; its first waypoint
        inc hl
        ld a,(hl)
        call times12
        ld (ix + E_FX),a
        inc hl
        ld a,(hl)
        call times12
        ld (ix + E_FY),a
        ld (ix + E_WP),1
        ld hl,en_count
        inc (hl)
        ld a,HUD_CD
        call hud_set
        pop ix
        scf
        ret

; A -> A x 12
times12:
        add a,a
        add a,a
        ld c,a
        add a,a
        add a,c
        ret

; IX = invader -> HL -> its way (db count, then column, row pairs)
way_ptr:
        ld hl,stage + ST_ROAD
        ld a,(ix + E_TYPE)
        cp 1
        ret nz
        ld hl,stage + ST_AIR
        ret

; A = type -> HL -> etype_tab entry
etype_ptr:
        dec a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,etype_tab
        add hl,de
        ret

; A = type 1..6 -> HL -> ttype_tab entry
ttype_ptr:
        dec a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,ttype_tab
        add hl,de
        ret

; the invaders walk
enemies_tick:
        ld ix,enemies
        ld b,MAX_EN
.e:
        push bc
        ld a,(ix + E_TYPE)
        or a
        call nz,walk
        ld de,EN_SZ
        add ix,de
        pop bc
        djnz .e
        ret

walk:
        inc (ix + E_ANIM)
        ld a,(ix + E_SPD)           ; steps this tick: (acc + speed) / 16
        ld c,a
        ld a,(ix + E_SLOW)
        or a
        jr z,.fast
        dec (ix + E_SLOW)
        srl c
.fast:
        ld a,(ix + E_ACC)
        add a,c
        ld c,a
        and 15
        ld (ix + E_ACC),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 15
        ret z
        ld b,a
.step:
        push bc
        call step
        pop bc
        ret c                       ; it reached the Kafenio
        djnz .step
        ret

; one step towards the waypoint -> carry if it is gone (at the end)
step:
        call way_ptr
        ld a,(ix + E_WP)
        cp (hl)
        jr nc,.arrived
        add a,a
        ld e,a
        ld d,0
        add hl,de
        inc hl
        ld a,(hl)                   ; target x
        call times12
        ld d,a
        inc hl
        ld a,(hl)
        call times12
        ld e,a                      ; target y
        ld c,0                      ; moved: bit 0 x, bit 1 y
        ld a,(ix + E_FX)
        cp d
        jr z,.y
        ld (ix + E_DIR),2
        jr c,.right
        dec (ix + E_FX)
        ld (ix + E_DIR),1
        jr .xm
.right:
        inc (ix + E_FX)
.xm:
        set 0,c
.y:
        ld a,(ix + E_FY)
        cp e
        jr z,.ym
        jr c,.down
        dec (ix + E_FY)
        jr .yd
.down:
        inc (ix + E_FY)
.yd:
        bit 0,c
        jr nz,.ym
        ld (ix + E_DIR),0
.ym:
        inc (ix + E_PROG)
        jr nz,.prog
        inc (ix + E_PROG + 1)
.prog:
        ld a,(ix + E_FX)
        cp d
        jr nz,.on
        ld a,(ix + E_FY)
        cp e
        jr nz,.on
        inc (ix + E_WP)
.on:
        or a
        ret
.arrived:                           ; the Kafenio loses greens
        ld a,(ix + E_TYPE)
        call etype_ptr
        ld de,5
        add hl,de
        ld c,(hl)
        ld a,(hp)
        sub c
        jr nc,.hp
        xor a
.hp:
        ld (hp),a
        ld (ix + E_TYPE),0
        ld hl,en_count
        dec (hl)
        ld a,2
        ld hl,1200
        ld bc,#080F
        call VOS_SOUND
        ld a,HUD_HP + HUD_CD
        call hud_set
        scf
        ret

; the defenders fire
towers_tick:
        ld hl,towers
        ld b,MAX_T
.t:
        push bc
        push hl
        ld a,(hl)
        or a
        jr z,.next
        ld (tw),hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)                   ; T_CD
        or a
        jr z,.ready
        dec (hl)
        jr .next
.ready:
        call fire
.next:
        pop hl
        ld de,T_SZ
        add hl,de
        pop bc
        djnz .t
        ret

; (tw) -> a defender ready: find a target and fire
fire:
        ld hl,(tw)
        ld a,(hl)
        ld (tw_type),a
        inc hl
        ld a,(hl)                   ; its centre, fine: column x 12 + 6
        call times12
        add a,6
        ld (tw_x),a
        inc hl
        ld a,(hl)
        call times12
        add a,6
        ld (tw_y),a
        ld a,(tw_type)
        call ttype_ptr
        inc hl
        ld a,(hl)
        ld (tw_range),a
        inc hl
        ld a,(hl)
        ld (tw_cool),a
        inc hl
        ld a,(hl)
        ld (tw_dmg),a
        inc hl
        ld a,(hl)
        ld (tw_flags),a
        inc hl
        ld a,(hl)
        ld (tw_fx),a
        ld a,(tw_flags)             ; the cauldron: all walkers in range
        and TF_AREA
        jr z,.single
        call area_hit
        jr nc,.none
        ld a,(tw_x)                 ; a puff on itself
        sub 6
        ld e,a
        ld a,(tw_y)
        sub 6
        ld d,a
        ld a,(tw_fx)
        call fx_at
        jr .cool
.single:
        call find_target
        jr nc,.none
        ld a,(tw_flags)
        and TF_SLOW
        call nz,slow_all
        ld a,(tw_dmg)
        ld c,a
        ld a,(tw_flags)
        and TF_CRIT
        jr z,.hit
        ld hl,crit                  ; every fourth shot x 3
        inc (hl)
        ld a,(hl)
        and 3
        jr nz,.hit
        ld a,c
        add a,a
        add a,c
        ld c,a
.hit:
        ld a,(tw_flags)
        and TF_SPLASH
        call nz,splash
        ld a,(ix + E_FX)
        ld e,a
        ld a,(ix + E_FY)
        ld d,a
        push de
        call hurt
        pop de
        ld a,(tw_fx)
        call fx_at
.cool:
        ld hl,(tw)
        inc hl
        inc hl
        inc hl
        ld a,(tw_cool)
        ld (hl),a
        ld a,1                      ; a shot
        ld hl,#8004
        ld bc,#0208
        jp VOS_SOUND
.none:
        ld hl,(tw)                  ; look again a little later
        inc hl
        inc hl
        inc hl
        ld (hl),4
        ret

; -> carry, IX = the invader furthest along within range that it can
; hit (drones only with TF_AIR)
find_target:
        ld hl,0
        ld (best),hl
        ld ix,enemies
        ld b,MAX_EN
.e:
        push bc
        ld a,(ix + E_TYPE)
        or a
        jr z,.n
        cp 1
        jr nz,.walker
        ld a,(tw_flags)
        and TF_AIR
        jr z,.n
.walker:
        call in_range
        jr nc,.n
        ld l,(ix + E_PROG)
        ld h,(ix + E_PROG + 1)
        inc hl
        ld de,(best)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.n
        jr z,.n
        ld (best),hl
        ld (best_ix),ix
.n:
        ld de,EN_SZ
        add ix,de
        pop bc
        djnz .e
        ld hl,(best)
        ld a,h
        or l
        ret z
        ld ix,(best_ix)
        scf
        ret

; IX = invader -> carry if its centre is within tw_range of tw_x, tw_y
in_range:
        ld a,(tw_x)
        ld d,a
        ld a,(tw_y)
        ld e,a
; D, E = a point, (tw_range) the reach
near:
        ld a,(ix + E_FX)
        add a,6
        sub d
        jr nc,.px
        neg
.px:
        ld c,a
        ld a,(tw_range)
        cp c
        jr c,.no
        ld a,(ix + E_FY)
        add a,6
        sub e
        jr nc,.py
        neg
.py:
        ld b,a
        ld a,(tw_range)
        cp b
        jr c,.no
        ld a,c                      ; dx^2 + dy^2 <= range^2
        call square
        push hl
        ld a,b
        call square
        pop de
        add hl,de
        push hl
        ld a,(tw_range)
        call square
        pop de
        or a
        sbc hl,de                   ; range^2 - (dx^2 + dy^2)
        ccf
        ret
.no:
        or a
        ret

; A = 0..63 -> HL = A x A
square:
        add a,a
        ld e,a
        ld d,0
        ld hl,squares
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

; the yiayia: every walker in range slowed
slow_all:
        push ix
        ld ix,enemies
        ld b,MAX_EN
.e:
        ld a,(ix + E_TYPE)
        or a
        jr z,.n
        cp 1
        jr z,.n
        push bc
        call in_range
        pop bc
        jr nc,.n
        ld (ix + E_SLOW),40
.n:
        ld de,EN_SZ
        add ix,de
        djnz .e
        pop ix
        ret

; the cauldron -> carry if it hit any: every walker in range, armour or not
area_hit:
        xor a
        ld (any),a
        ld ix,enemies
        ld b,MAX_EN
.e:
        push bc
        ld a,(ix + E_TYPE)
        or a
        jr z,.n
        cp 1
        jr z,.n
        call in_range
        jr nc,.n
        ld (ix + E_SLOW),25
        ld a,(tw_dmg)
        ld c,a
        call hurt
        ld a,1
        ld (any),a
.n:
        ld de,EN_SZ
        add ix,de
        pop bc
        djnz .e
        ld a,(any)
        rrca
        ret

; the baker: half the damage to everyone near the target (C = damage)
splash:
        push ix
        push bc
        ld a,(ix + E_FX)
        add a,6
        ld (sp_x),a
        ld a,(ix + E_FY)
        add a,6
        ld (sp_y),a
        ld a,(tw_range)
        push af
        ld a,14
        ld (tw_range),a
        srl c
        ld a,c
        ld (sp_dmg),a
        pop af
        ld (sp_range),a
        ld (best_ix),ix
        ld ix,enemies
        ld b,MAX_EN
.e:
        push bc
        ld a,(ix + E_TYPE)
        or a
        jr z,.n
        ld hl,(best_ix)             ; not the target itself
        push ix
        pop de
        or a
        sbc hl,de
        jr z,.n
        ld a,(sp_x)
        ld d,a
        ld a,(sp_y)
        ld e,a
        call near
        jr nc,.n
        ld a,(sp_dmg)
        ld c,a
        call hurt
.n:
        ld de,EN_SZ
        add ix,de
        pop bc
        djnz .e
        ld a,(sp_range)
        ld (tw_range),a
        pop bc
        pop ix
        ret

; IX = invader, C = damage (less its armour, unless TF_PIERCE; at least 1)
hurt:
        ld a,(tw_flags)
        and TF_PIERCE
        ld a,c
        jr nz,.hit
        sub (ix + E_ARM)
        jr c,.min
        jr nz,.hit
.min:
        ld a,1
.hit:
        ld c,a
        ld a,(ix + E_HP)
        sub c
        jr c,.dead
        jr z,.dead
        ld (ix + E_HP),a
        ret
.dead:
        ld a,(ix + E_TYPE)
        push af
        call etype_ptr
        ld de,4
        add hl,de
        ld e,(hl)                   ; the reward
        ld d,0
        ld hl,(funds)
        add hl,de
        ld (funds),hl
        call add_score
        ld (ix + E_TYPE),0
        ld hl,en_count
        dec (hl)
        pop af
        cp 3
        ld a,FX_BOOM
        jr z,.fx
        ld a,FX_POOF
.fx:
        ld e,(ix + E_FX)
        ld d,(ix + E_FY)
        call fx_at
        ld a,0
        ld hl,#800C
        ld bc,#060C
        call VOS_SOUND
        ld a,HUD_FUNDS + HUD_CD
        jp hud_set

; A = effect, E, D = fine x, y of a cell-sized thing: the effect there
fx_at:
        push ix
        push af
        ld ix,fxs
        ld b,MAX_FX
.free:
        ld a,(ix + X_SPR)
        inc a
        jr z,.got
        push de
        ld de,X_SZ
        add ix,de
        pop de
        djnz .free
        pop af
        pop ix
        ret
.got:
        pop af
        ld (ix + X_SPR),a
        ld a,e                      ; screen byte: fine x / 3
        call div3
        add a,PF_XB
        ld (ix + X_XB),a
        ld a,d
        add a,PF_Y
        ld (ix + X_Y),a
        call fx_spr                 ; the spark is small: centre it
        ld a,(hl)                   ; bytes
        cp 4
        jr nc,.placed
        inc (ix + X_XB)
        ld a,(ix + X_Y)
        add a,4
        ld (ix + X_Y),a
.placed:
        call fxinfo
        ld a,(hl)
        ld (ix + X_LIFE),a
        pop ix
        ld a,1
        ld (dirty),a
        ret

; IX = effect -> HL -> its lifetime
fxinfo:
        ld a,(ix + X_SPR)
        ld e,a
        ld d,0
        ld hl,fx_life
        add hl,de
        ret

; IX = effect -> HL -> its sprite
fx_spr:
        ld a,(ix + X_SPR)
        add a,a
        ld e,a
        ld d,0
        ld hl,fx_sprites
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; A = 0..239 -> A / 3 (keeps BC, DE)
div3:
        push de
        ld e,a
        ld d,0
        ld hl,div3_tab
        add hl,de
        ld a,(hl)
        pop de
        ret

fx_tick:
        ld ix,fxs
        ld b,MAX_FX
.f:
        ld a,(ix + X_SPR)
        inc a
        jr z,.n
        ld a,(ix + X_LIFE)
        or a
        jr z,.n
        dec (ix + X_LIFE)
        jr nz,.n
        ld a,1
        ld (dirty),a
.n:
        ld de,X_SZ
        add ix,de
        djnz .f
        ret

; ---------------------------------------------------------------------
; the screen
; ---------------------------------------------------------------------

; what moved erased (and drawn again at once), then the invaders,
; effects and cursor drawn
draw_tick:
        ld ix,enemies               ; erase: the dead and the moved
        ld b,MAX_EN
.erase:
        push bc
        ld a,(ix + E_OX)
        inc a
        jr z,.e_next
        ld a,(ix + E_TYPE)
        or a
        jr z,.e_gone
        call en_place               ; D = x byte, E = y, A = frame
        cp (ix + E_OFR)
        jr nz,.e_gone
        ld a,d
        cp (ix + E_OX)
        jr nz,.e_gone
        ld a,e
        cp (ix + E_OY)
        jr z,.e_next
.e_gone:
        ld b,(ix + E_OX)
        ld c,(ix + E_OY)
        ld de,#040C
        call restore
        ld (ix + E_OX),#FF
        ld a,1
        ld (dirty),a
        ld a,(ix + E_TYPE)          ; one that moved is drawn again at once:
        or a                        ; it is never seen away (the flicker)
        call nz,en_draw
.e_next:
        ld de,EN_SZ
        add ix,de
        pop bc
        djnz .erase
        ld ix,fxs                   ; effects whose time is up
        ld b,MAX_FX
.fx_erase:
        push bc
        ld a,(ix + X_SPR)
        inc a
        jr z,.f_next
        ld a,(ix + X_LIFE)
        or a
        jr nz,.f_next
        call fx_spr
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld b,(ix + X_XB)
        ld c,(ix + X_Y)
        call restore
        ld (ix + X_SPR),#FF
.f_next:
        ld de,X_SZ
        add ix,de
        pop bc
        djnz .fx_erase
        ld a,(dirty)                ; draw: all, if anything was erased,
        ld c,a                      ; else the new ones
        xor a
        ld (dirty),a
        ld ix,enemies
        ld b,MAX_EN
.draw:
        push bc
        ld a,(ix + E_TYPE)
        or a
        jr z,.d_next
        ld a,(ix + E_OX)
        inc a
        jr z,.d_draw
        ld a,c
        or a
        jr z,.d_next
.d_draw:
        call en_draw
.d_next:
        ld de,EN_SZ
        add ix,de
        pop bc
        djnz .draw
        ld a,c
        or a
        jr z,.cursor
        ld ix,fxs
        ld b,MAX_FX
.fx_draw:
        push bc
        ld a,(ix + X_SPR)
        inc a
        jr z,.x_next
        call fx_spr
        ld b,(ix + X_XB)
        ld c,(ix + X_Y)
        call draw_spr
.x_next:
        ld de,X_SZ
        add ix,de
        pop bc
        djnz .fx_draw
        ld a,1
        ld (cur_dirty),a
.cursor:
        ld a,(cur_dirty)
        or a
        ret z
        xor a
        ld (cur_dirty),a
; the cursor: green where the chosen defender may stand, else red
draw_cursor:
        call cur_cell
        push hl
        ld de,tmap
        add hl,de
        ld a,(hl)
        pop hl
        ld bc,spr_cursor_bad
        or a
        jr nz,.spr
        ld de,stage + ST_KIND
        add hl,de
        ld a,(hl)
        cp K_GRASS
        jr z,.ok
        cp K_BLOCK
        jr nz,.spr
        ld a,(sel)
        cp 4                        ; Psssst
        jr nz,.spr
.ok:
        ld bc,spr_cursor_ok
.spr:
        push bc
        ld a,(cur_c)
        add a,a
        add a,a
        add a,PF_XB
        ld b,a
        ld a,(cur_r)
        call times12
        add a,PF_Y
        ld c,a
        pop hl
        jp draw_spr

; IX = invader: drawn where it is now, and that kept
en_draw:
        call en_place
        ld (ix + E_OX),d
        ld (ix + E_OY),e
        ld (ix + E_OFR),a
        call en_sprite
        ld b,d
        ld c,e
        jp draw_spr

; IX = invader -> D = screen byte, E = line, A = frame (0 / 1)
en_place:
        ld a,(ix + E_FX)
        call div3
        add a,PF_XB
        ld d,a
        ld a,(ix + E_FY)
        add a,PF_Y
        ld e,a
        ld a,(ix + E_ANIM)
        rrca
        rrca
        rrca
        and 1
        ret

; IX = invader, A = frame -> HL -> its sprite (type, direction, frame)
en_sprite:
        push de
        ld e,a
        ld a,(ix + E_TYPE)
        dec a
        ld c,a
        add a,a
        add a,c                     ; type x 3 + direction
        add a,(ix + E_DIR)
        add a,a                     ; x 2 + frame
        add a,e
        add a,a                     ; words
        ld e,a
        ld d,0
        ld hl,en_sprites
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ret

; forget where things were drawn (all is drawn again)
forget_drawn:
        ld ix,enemies
        ld b,MAX_EN
        ld de,EN_SZ
.e:
        ld (ix + E_OX),#FF
        add ix,de
        djnz .e
        ld a,1
        ld (cur_dirty),a
        ret

; C = column, B = row: the cell, and the defender on it
draw_cell:
        push bc
        ld a,c
        ld c,b
        call cell_num
        ld de,stage
        add hl,de
        ld a,(hl)
        call cell_pairs             ; HL -> its pairs
        pop bc
        push bc
        ld (blt + 6),hl
        ld a,c
        add a,a
        add a,a
        add a,PF_XB
        add a,a
        ld (blt),a
        xor a
        ld (blt + 1),a
        ld a,b
        call times12
        add a,PF_Y
        ld (blt + 2),a
        xor a
        ld (blt + 3),a
        ld a,4
        ld (blt + 4),a
        ld a,12
        ld (blt + 5),a
        ld a,8
        ld (blt + 8),a
        call blit
        pop bc
; C = column, B = row: the defender on that cell, if any
draw_tower:
        push bc
        ld a,c
        ld c,b
        call cell_num
        ld de,tmap
        add hl,de
        ld a,(hl)
        pop bc
        or a
        ret z
        dec a
        add a,a
        ld e,a
        ld d,0
        ld hl,tw_sprites
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        add a,a
        add a,a
        add a,PF_XB
        ld d,a
        ld a,b
        call times12
        add a,PF_Y
        ld c,a
        ld b,d
        jp draw_spr

; B = screen byte, C = line, D = bytes, E = rows: the stage's cells
; there again (and the defenders on them)
restore:
        ld a,b
        sub PF_XB
        ld (rs_x0),a
        add a,d
        ld (rs_x1),a
        ld a,c
        sub PF_Y
        ld (rs_y0),a
        add a,e
        ld (rs_y1),a
        ld a,(rs_y0)                ; the first row of cells
        ld b,0
.r0:
        cp 12
        jr c,.r0d
        sub 12
        inc b
        jr .r0
.r0d:
        ld a,b
        ld (rs_r),a
.row:
        ld a,(rs_r)
        cp MH
        ret nc
        call times12
        ld (rs_ry),a
        ld hl,rs_y1
        cp (hl)
        ret nc                      ; past the bottom
        ld a,(rs_x0)                ; the first column
        rrca
        rrca
        and 63
        ld (rs_c),a
.col:
        ld a,(rs_c)
        cp MW
        jp nc,.row_next
        add a,a
        add a,a
        ld (rs_cx),a
        ld hl,rs_x1
        cp (hl)
        jp nc,.row_next
        ld a,(rs_c)                 ; its pairs
        ld b,a
        ld a,(rs_r)
        ld c,a
        ld a,b
        call cell_num
        ld de,stage
        add hl,de
        ld a,(hl)
        call cell_pairs
        ld a,(rs_cx)                ; x from max(x0, cx) to min(x1, cx + 4)
        ld b,a
        ld a,(rs_x0)
        cp b
        jr nc,.xa
        ld a,b
.xa:
        ld (rs_a),a
        sub b                       ; its column in the cell
        add a,a
        ld e,a
        ld a,(rs_ry)                ; y from max(y0, ry) to min(y1, ry + 12)
        ld c,a
        ld a,(rs_y0)
        cp c
        jr nc,.ya
        ld a,c
.ya:
        ld (rs_b),a
        sub c                       ; its row in the cell
        add a,a
        add a,a
        add a,a
        add a,e
        ld e,a
        ld d,0
        add hl,de
        ld (blt + 6),hl
        ld a,b                      ; width
        add a,4
        ld hl,rs_x1
        cp (hl)
        jr c,.xb
        ld a,(hl)
.xb:
        ld hl,rs_a
        sub (hl)
        ld (blt + 4),a
        ld a,c                      ; rows
        add a,12
        ld hl,rs_y1
        cp (hl)
        jr c,.yb
        ld a,(hl)
.yb:
        ld hl,rs_b
        sub (hl)
        ld (blt + 5),a
        ld a,(rs_a)
        add a,PF_XB
        add a,a
        ld (blt),a
        xor a
        ld (blt + 1),a
        ld (blt + 3),a
        ld a,(rs_b)
        add a,PF_Y
        ld (blt + 2),a
        ld a,8
        ld (blt + 8),a
        call blit
        ld a,(rs_c)
        ld c,a
        ld a,(rs_r)
        ld b,a
        call draw_tower
        ld hl,rs_c
        inc (hl)
        jp .col
.row_next:
        ld hl,rs_r
        inc (hl)
        jp .row

; A = cell -> HL -> its (mask, pixels) pairs, through the cache
cell_pairs:
        ld c,a
        and CACHE_N - 1
        ld (cp_slot),a
        ld e,a
        ld d,0
        ld hl,cache_tag
        add hl,de
        ld a,c
        inc a
        cp (hl)
        jr z,.hit
        ld (hl),a                   ; read it: 48 bytes from the data bank
        ld l,c
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de                   ; x 48
        ld de,CELL_BANK
        add hl,de
        ld de,cell_raw
        ld bc,48
        call VOS_BANK_GET
        call .data
        ex de,hl
        ld hl,cell_raw
        ld b,48
.pair:
        ld a,#FF
        ld (de),a
        inc de
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        djnz .pair
.hit:
.data:                              ; -> HL -> the slot's 96 bytes
        ld a,(cp_slot)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,cache
        add hl,de
        ret

; HL -> sprite (db bytes, rows, pairs), B = screen byte, C = line
draw_spr:
        ld a,(hl)
        ld (blt + 4),a
        add a,a
        ld (blt + 8),a
        inc hl
        ld a,(hl)
        ld (blt + 5),a
        inc hl
        ld (blt + 6),hl
        ld a,b
        add a,a
        ld (blt),a
        ld a,0
        adc a,0
        ld (blt + 1),a
        ld a,c
        ld (blt + 2),a
        xor a
        ld (blt + 3),a
blit:
        push ix
        ld ix,blt
        call VOS_BLIT
        pop ix
        ret

; ---------------------------------------------------------------------
; the HUD: what changed
; ---------------------------------------------------------------------
hud_set:
        ld hl,hud
        or (hl)
        ld (hl),a
        ret

hud_draw:
        ld a,(hud)
        or a
        ret z
        ld b,a
        xor a
        ld (hud),a
        bit 0,b
        call nz,.funds
        bit 1,b
        call nz,.hp
        bit 2,b
        call nz,.wave
        bit 3,b
        call nz,.cd
        bit 5,b
        call nz,.bar
        bit 6,b
        call nz,.score
        bit 4,b
        ret z
        jp .info
; the last row: SCORE nnnn  STAGE n
.score:
        push bc
        ld a,T_SCORE
        ld hl,0
        ld de,HUD_Y + 62
        ld c,6
        call label_w
        ld hl,(score)
        ld de,48
        ld bc,HUD_Y + 62
        call number
        ld a,T_STAGE
        ld hl,96
        ld de,HUD_Y + 62
        ld c,5
        call label_w
        ld a,(stage_no)
        ld l,a
        ld h,0
        ld de,136
        ld bc,HUD_Y + 62
        call number
        pop bc
        ret
; row 1: FUNDS nnnn  WAVE nn; row 2: VROUVES nnn  NEXT IN nn / FOES nn
.funds:
        push bc
        ld a,T_FUNDS
        ld hl,0
        ld de,HUD_Y
        ld c,6
        call label_w
        ld hl,(funds)
        ld de,48
        ld bc,HUD_Y
        call number
        pop bc
        ret
.hp:
        push bc
        ld a,T_GREENS
        ld hl,0
        ld de,HUD_Y + 10
        ld c,7
        call label_w
        ld a,(hp)
        ld l,a
        ld h,0
        ld de,56
        ld bc,HUD_Y + 10
        call number
        pop bc
        ret
.wave:
        push bc
        ld a,T_WAVE
        ld hl,96
        ld de,HUD_Y
        ld c,5
        call label_w
        ld a,(wave)
        ld l,a
        ld h,0
        ld de,136
        ld bc,HUD_Y
        call number
        pop bc
        ret
.cd:
        push bc
        ld a,(state)
        or a
        ld a,T_NEXT_IN
        jr z,.cd_l
        ld a,T_FOES
.cd_l:
        ld hl,96
        ld de,HUD_Y + 10
        ld c,7
        call label_w
        ld a,(state)
        or a
        ld a,(cd_sec)
        jr z,.cd_n
        ld a,(en_count)
.cd_n:
        ld l,a
        ld h,0
        ld de,152
        ld bc,HUD_Y + 10
        call number
        pop bc
        ret
.bar:
        push bc
        ld a,1                      ; the six defenders, the chosen one on
.slot:                              ; yellow, the others on grey,
        push af                     ; those the stage has not on black
        ld c,a
        call has_type
        ld a,0
        jr nc,.frame
        ld a,(sel)
        cp c
        ld a,8                      ; yellow, or grey
        jr z,.frame
        ld a,5
.frame:
        ld (rect + 8),a
        ld a,c
        dec a
        ld b,a                      ; x = 12 + 28 x (n - 1)
        add a,a
        add a,a
        add a,a
        sub b
        add a,a
        add a,a
        add a,12
        ld (rect),a
        xor a
        ld (rect + 1),a
        ld (rect + 3),a
        ld (rect + 5),a
        ld (rect + 7),a
        ld a,HUD_Y + 20
        ld (rect + 2),a
        ld a,16
        ld (rect + 4),a
        ld (rect + 6),a
        push ix
        ld ix,rect
        call VOS_RECT
        pop ix
        pop af
        push af
        call has_type
        jr nc,.next
        pop af
        push af
        dec a
        add a,a
        ld l,a
        ld h,0
        ld bc,tw_sprites
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(rect)
        add a,4
        srl a
        ld b,a
        ld c,HUD_Y + 22
        call draw_spr
.next:
        pop af
        inc a
        cp 7
        jr c,.slot
        pop bc
        ret
; the chosen defender and its cost (or PAUSED), then the keys
.info:
        ld a,(paused)
        or a
        jr z,.chosen
        ld a,T_PAUSED
        ld hl,0
        ld de,HUD_Y + 40
        ld c,18
        call label_w
        jr .hint
.chosen:
        ld a,(sel)
        add a,T_D1 - 1
        ld hl,0
        ld de,HUD_Y + 40
        ld c,12
        call label_w
        ld a,(sel)
        call ttype_ptr
        ld l,(hl)
        ld h,0
        ld de,96
        ld bc,HUD_Y + 40
        call number
.hint:                              ; the stage's name, until its
        ld a,(wave)                 ; first wave; then the keys
        or a
        jr nz,.keys
        ld a,24
        ld (lb_w),a
        ld hl,0
        push hl
        ld hl,HUD_Y + 52
        push hl
        ld a,T_LANG                 ; "E", or "G" in Greek
        call VOS_MSG
        ld a,(hl)
        ld hl,stage + ST_NAME
        cp "E"
        jr z,print_text
        ld hl,stage + ST_NAME_EL
        jr print_text
.keys:
        ld a,T_HINT
        ld hl,0
        ld de,HUD_Y + 52
        ld c,24
; C = width in characters, then as label
label_w:
        push af
        ld a,c
        ld (lb_w),a
        pop af
        ; fall through

; A = text, HL = x, DE = y, (lb_w) = characters: it in white on
; black, then spaces to that width
print_label:
        push hl
        push de
        call VOS_MSG
; HL -> the text; y, x on the stack
print_text:
        ld de,line
        ld a,(lb_w)
        ld b,a
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
        ld a,1
        ld c,0
        call VOS_COLOURS
        pop de
        pop hl
        ld bc,line
        jp VOS_PRINT

; HL = number, DE = x, BC = y: it in yellow, 4 digits and a space
number:
        push de
        push bc
        ld de,line
        ld bc,-1000
        call .digit
        ld bc,-100
        call .digit
        ld bc,-10
        call .digit
        ld c,b
        call .digit
        ld a," "
        ld (de),a
        inc de
        xor a
        ld (de),a
        ld hl,line                  ; leading zeros as spaces
        ld b,3
.zero:
        ld a,(hl)
        cp "0"
        jr nz,.print
        ld (hl)," "
        inc hl
        djnz .zero
.print:
        ld a,8
        ld c,0
        call VOS_COLOURS
        pop de
        pop hl
        ld bc,line
        jp VOS_PRINT
.digit:
        ld a,"0" - 1
.count:
        inc a
        add hl,bc
        jr c,.count
        sbc hl,bc
        ld (de),a
        inc de
        ret

; ---- data -----------------------------------------------------------
        include "art.asm"           ; palette, spr_*, from import_art.py

bar:            db 3
                dw menu, 0, 0
menu:           db T_MENU, 8
                db T_NEW, CMD_NEW, 0, 0
                db T_CONT, CMD_CONT, 0, 0
                db T_NEXT, CMD_NEXT, 0, 0
                db T_PAUSE, CMD_PAUSE, 0, 0
                db T_SCORES, CMD_SCORES, 0, 0
                db T_ABOUT, CMD_ABOUT, 0, 0
                db VOS_SEPARATOR, 0, 0, 0
                db T_BACK, CMD_BACK, "Q", 0
dlg_about:      db T_MENU, T_ABOUT_TEXT, 1, VM_OK
dlg_win:        db T_WIN_T, T_WIN, 1, VM_OK
dlg_final:      db T_WIN_T, T_FINAL, 1, VM_OK
dlg_more:       db T_WIN_T, T_MORE, 1, VM_OK
dlg_lose:       db T_LOSE_T, T_LOSE, 1, VM_OK
stage_name:     db "VROUV1  DAT"      ; the digit is stage_no
save_name:      db "VROUVES SAV"
board_rect:     dw 32, 44, 128, 92  ; the best five: x, y, w, h, pen
                db 0

; invaders: base hp, hp a wave, speed (x 16), armour, reward, damage, -, -
etype_tab:      db 6, 3, 20, 0, 3, 4, 0, 0     ; bio-drone
                db 16, 8, 9, 2, 4, 8, 0, 0     ; compliance guard
                db 50, 19, 7, 4, 10, 20, 0, 0  ; weed destroyer
; defenders: cost, range, cooldown, damage, flags, effect, sell, -
ttype_tab:      db 35, 30, 18, 6, TF_AIR, FX_SPARK, 17, 0                   ; cretan
                db 50, 18, 22, 14, TF_SLOW, FX_BASH, 25, 0                  ; yiayia
                db 70, 28, 6, 4, TF_AIR + TF_CRIT, FX_SPARK, 35, 0          ; bride
                db 80, 36, 10, 5, TF_AIR + TF_PIERCE + TF_HOVER, FX_ZAP, 40, 0 ; psssst
                db 110, 22, 32, 8, TF_AREA + TF_PIERCE, FX_PUFF, 55, 0      ; cauldron
                db 60, 34, 36, 16, TF_AIR + TF_SPLASH, FX_SPARK, 30, 0      ; baker
tw_sprites:     dw spr_cretan, spr_yiayia, spr_bride, spr_psssst, spr_cauldron, spr_baker
; per type, per direction (up / down, left, right), two frames
en_sprites:     dw spr_drone_a, spr_drone_b, spr_drone_a, spr_drone_b, spr_drone_a, spr_drone_b
                dw spr_guard_a, spr_guard_b, spr_guard_la, spr_guard_lb, spr_guard_a, spr_guard_b
                dw spr_tank_va, spr_tank_vb, spr_tank_la, spr_tank_lb, spr_tank_ra, spr_tank_rb
fx_sprites:     dw spr_spark, spr_puff, spr_bash, spr_poof, spr_boom, spr_zap
fx_life:        db 6, 12, 8, 10, 12, 6
div3_tab:
        REPEAT 240, n
                db (n - 1) / 3
        REND
squares:
        REPEAT 64, n
                dw (n - 1) * (n - 1)
        REND

        include "app_texts.asm"     ; T_* and texts:, from texts.txt

; ---- state ----------------------------------------------------------
loaded:         db 0
drive:          db 0                ; the game's drive (VOS_SELF)
stage_no:       db 1                ; 1..STAGES
score:          dw 0                ; this run's
board:          db 0                ; the best five shown
bd_y:           db 0
save_buf:       ds SAVE_SIZE        ; VROUVES.SAV
name_buf:       ds 10               ; VOS_INPUT: 8 + 2
blt:            dw 0, 0             ; VOS_BLIT: x, y, bytes, rows, source,
                db 0, 0             ; stride
                dw 0
                db 0
rect:           dw 0, 0, 0, 0       ; VOS_RECT: x, y, w, h, pen
                db 0
cache_tag:      ds CACHE_N          ; cell + 1 in each slot, 0 none
cache:          ds CACHE_N * 96
cell_raw:       ds 48
cp_slot:        db 0
lb_w:           db 0
line:           ds 25
rs_x0:          db 0                ; restore: the rectangle, in the
rs_x1:          db 0                ; playfield (bytes, lines)
rs_y0:          db 0
rs_y1:          db 0
rs_r:           db 0
rs_c:           db 0
rs_ry:          db 0
rs_cx:          db 0
rs_a:           db 0
rs_b:           db 0
tw:             dw 0                ; the defender firing
tw_type:        db 0
tw_x:           db 0
tw_y:           db 0
tw_range:       db 0
tw_cool:        db 0
tw_dmg:         db 0
tw_flags:       db 0
tw_fx:          db 0
best:           dw 0
best_ix:        dw 0
any:            db 0
sp_x:           db 0
sp_y:           db 0
sp_dmg:         db 0
sp_range:       db 0
stage:          ds ST_HEAD          ; the stage's head (VROUVn.DAT)
game_vars:
funds:          dw 0
hp:             db 0                ; the Kafenio's greens, 100 at first
wave:           db 0                ; waves started
state:          db 0                ; 0 counting down, 1 a wave, 2 won
cd_sec:         db 0
cd_sub:         db 0
groups:         ds 3 * 4
en_count:       db 0
paused:         db 0
ticks:          db 0
crit:           db 0
sel:            db 0                ; the chosen defender, 1..6
cur_c:          db 0
cur_r:          db 0
cur_dirty:      db 0
dirty:          db 0
hud:            db 0
game_end:
tmap:           ds CELLS            ; the defender on each cell, 0 none
towers:         ds MAX_T * T_SZ
enemies:        ds MAX_EN * EN_SZ
fxs:            ds MAX_FX * X_SZ

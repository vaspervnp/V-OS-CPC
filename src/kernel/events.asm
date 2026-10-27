; =====================================================================
; events.asm - input event queue
;
; A ring of EV_COUNT events of EV_SIZE bytes. The interrupt (keyboard
; and pointer drivers) is the only producer; the main program is the
; only consumer, so head and tail need no locking.
;
; Event layout (ev_cur after ev_get):
;   +0 type  EV_*
;   +1 code  key number (key events) or button bits (pointer events)
;   +2 char  ASCII for key down/repeat, else 0
;   +3 mods  MOD_* at the time of the event
;   +4 x     pointer x (word)
;   +6 y     pointer y (word)
; =====================================================================

EV_KEY_DOWN     equ 1
EV_KEY_UP       equ 2
EV_KEY_REPEAT   equ 3
EV_PTR_MOVE     equ 4               ; at most one queued at a time
EV_PTR_DOWN     equ 5               ; code = button that went down
EV_PTR_UP       equ 6
EV_LANG         equ 7               ; code = lang_input after CONTROL+SHIFT

EV_SIZE         equ 8
EV_COUNT        equ 32              ; power of two

; ---------------------------------------------------------------------
; ev_post - A = type, B = code, C = char. Interrupt context only.
; Drops the event (and counts it) when the queue is full.
; Destroys: AF, DE, HL
; ---------------------------------------------------------------------
ev_post:
        ld d,a
        ld a,(ev_head)
        ld e,a
        inc a
        and EV_COUNT - 1
        ld hl,ev_tail
        cp (hl)
        jr nz,.room
        ld hl,ev_dropped
        inc (hl)
        ret
.room:
        push af                     ; new head
        ld a,e
        add a,a
        add a,a
        add a,a
        ld hl,ev_buf
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld (hl),d
        inc hl
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld a,(kbd_mods)
        ld (hl),a
        inc hl
        ld de,(ptr_x)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(ptr_y)
        ld (hl),e
        inc hl
        ld (hl),d
        pop af
        ld (ev_head),a              ; publish last
        ret

; ---------------------------------------------------------------------
; ev_get - Z if the queue is empty, else NZ with the event copied to
; ev_cur and A = its type.
; Destroys: AF, BC, DE, HL
; ---------------------------------------------------------------------
ev_get:
        ld a,(ev_tail)
        ld hl,ev_head
        cp (hl)
        ret z
        ld b,a
        add a,a
        add a,a
        add a,a
        ld hl,ev_buf
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld de,ev_cur
        ld a,b
        ld bc,EV_SIZE
        ldir
        inc a
        and EV_COUNT - 1
        ld (ev_tail),a
        ld a,(ev_cur)
        cp EV_PTR_MOVE
        jr nz,.done
        xor a
        ld (ptr_move_queued),a
        ld a,EV_PTR_MOVE
.done:
        or a
        ret

; ---- state ----------------------------------------------------------
ev_head:    db 0
ev_tail:    db 0
ev_dropped: db 0
ev_cur:     ds EV_SIZE
ev_buf:     ds EV_SIZE * EV_COUNT

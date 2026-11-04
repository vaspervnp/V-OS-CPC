; =====================================================================
; viewt.asm - VIEWT, a test of VX_VIEW (make test-view): a view of
; 160 x 96 at (40, 40), and through it
;   VOS_CLS pen 2          -> that rectangle filled, nothing else
;   VOS_RECT (100, 50, 200, 100) pen 3 -> cut at the view's right and
;                             bottom: screen (140, 90) to (199, 135)
;   VOS_PRINT at (8, 8)    -> "0123456789ABCDEFGHIJ": the characters
;                             whose cell is all inside: 0 to I (19)
;   VOS_PLOT (159, 95) pen 1 -> the view's last pixel; (160, 95) none
;   VOS_BLIT at (0, 72): 4 bytes x 8 rows, in; at (152, 0): out
; then no view, and at (0, 200) "VIEW: OK" (or "NO EXPANSION" when
; VX_VIEW gives carry: 128K). SPACE ends it.
;   rasm apps/viewt/viewt.asm -I src -I build -o build/viewt
; =====================================================================

        include "api/vos_api.inc"

        org VOS_APP_ADDR
        jp init
        jp event
        jp redraw
        db "VA", VOS_API_VERSION

init:
        ld a,1
        call VOS_MODE
redraw:
        xor a
        call VOS_CLS
        ld a,VX_VIEW
        ld hl,view
        call VOS_EXT
        ld bc,no_xb
        jr c,.result
        ld a,2
        call VOS_CLS
        ld ix,rect
        call VOS_RECT
        ld a,1
        ld c,2
        call VOS_COLOURS
        ld hl,8
        ld de,8
        ld bc,digits
        call VOS_PRINT
        ld hl,159
        ld de,95
        ld a,1
        call VOS_PLOT
        ld hl,160
        ld de,95
        ld a,1
        call VOS_PLOT
        ld ix,blit_in
        call VOS_BLIT
        ld ix,blit_out
        call VOS_BLIT
        ld a,VX_VIEW
        ld hl,0
        call VOS_EXT
        ld bc,ok
.result:
        push bc
        ld a,1
        ld c,0
        call VOS_COLOURS
        pop bc
        ld hl,0
        ld de,200
        jp VOS_PRINT

event:
        ld a,(hl)
        cp VE_KEY_DOWN
        ret nz
        inc hl
        ld a,(hl)
        cp VK_SPACE
        ret nz
        jp VOS_EXIT

view:           dw 40, 40, 160, 96
rect:           dw 100, 50, 200, 100
                db 3
digits:         db "0123456789ABCDEFGHIJ", 0
blit_in:        dw 0, 72
                db 4, 8
                dw image
                db 8
blit_out:       dw 152, 0
                db 4, 8
                dw image
                db 8
image:          ds 8 * 8, #FF       ; mask, pixels: pen 3
ok:             db "VIEW: OK", 0
no_xb:          db "NO EXPANSION", 0

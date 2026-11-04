; =====================================================================
; gap.asm - copied to the end of GAP2 (kernel/api.asm) by the loader,
; once it has cleared video RAM; in VOS.BIN with VOS_SPLIT's setting
; (vos.asm: the LOW section). Every bank is mapped there. No jumps
; inside: they run there as they are.
; =====================================================================

; wm_dw_hook: ui_draw_widget calls it once a widget's x, y are read: in
; a view (a program's window), from the view's corner
gap_code:
        ld a,(vw_on)
        or a
        ret z
        ld hl,(dw_x)
        ld de,(vw_ox)
        add hl,de
        ld (dw_x),hl
        ld hl,(dw_y)
        ld de,(vw_oy)
        add hl,de
        ld (dw_y),hl
        ret
        assert $ - gap_code == WM_CALL_GAP - wm_dw_hook

; WM_CALL_GAP: wm_call (kernel/view.asm). HL = a routine of wm_bank,
; with that bank at #4000 -> its A, flags. When the stack is there too
; (a Studio program's scripts have theirs in its memory), it runs on the
; kernel's stack's low end meanwhile (no wm_call comes in it)
gap_call:
        ld (wm_sp),sp
        ld a,(wm_sp + 1)
        and #C0
        cp #40
        ld a,(wm_bank)
        jp nz,bank_call
        ld sp,STACK_TOP - 256
        call bank_call
        ld sp,(wm_sp)
        ret
gap_end:
        assert wm_dw_hook + gap_end - gap_code <= wm_sp

; =====================================================================
; vectors.asm - page zero: restart vectors and IM 1 interrupt entry
; Assembled at KERNEL_BASE (#0000).
; =====================================================================

rst_00: jp kernel_entry             ; reset
        ds #08 - $, 0
rst_08: ret                         ; RST #08..#30 reserved for the API
        ds #10 - $, 0
rst_10: ret
        ds #18 - $, 0
rst_18: ret
        ds #20 - $, 0
rst_20: ret
        ds #28 - $, 0
rst_28: ret
        ds #30 - $, 0
rst_30: ret
        ds #38 - $, 0
rst_38: jp int_handler              ; IM 1: 300 Hz Gate Array interrupt
        ds API_TABLE - $, 0

; ---- API table (filled in from M6) ----------------------------------
api_header:
        db "VOS", 0                 ; signature
        dw VOS_VERSION              ; kernel version, BCD major.minor
        dw VOS_API_VERSION          ; API version

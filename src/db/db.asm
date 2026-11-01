; =====================================================================
; db.asm - the database engine (DB.SYS): files of several tables with
; an index each, for programs through VOS_EXT, VX_DB (API 22).
;
; It runs in base RAM bank 1 at DB_ADDR (include/memmap.inc): the
; kernel loads DB.SYS from drive A: the first time a program uses it
; (db_entry, kernel/ext2.asm). A cache of DB_SLOTS pages follows it,
; from DB_CACHE. Like ext2.asm it calls the kernel with bank 1 as the
; home bank; a program's buffers come and go through bank_copy.
;
; A database is one file, NAME.VDB, of 1K pages: page n is the file's
; block n (no AMSDOS header), so it may fill a disc. Page 0:
;   +0 "VDB1", +4 dw pages, +6 db tables, +7 its alphabet (cs_mark),
;   from +16 a descriptor of
;   DB_DESC bytes for each table (T_*): its name, its fields (up to 10:
;   name, type, length), the key field, its pages and its count.
; Records have a fixed length (the fields one after the other, up to
; 255 bytes) and live in data pages ("D") chained from T_FIRST; a
; record's id (rid) is its page * 256 + its slot. A table with a key
; field has an index, a B+tree: leaves ("L", linked both ways) hold
; entries of key + rid in order, inner pages ("I") separators of key +
; rid + child. Entries compare byte by byte: a number key (2 bytes) is
; kept high byte first, and so is the rid, so equal keys follow each
; other in the order of their rids. A delete only takes an entry out
; (empty leaves stay).
;
; Every call writes its changes to the disc before it returns.
; DB_HARNESS builds it alone for tools/db_check.py (a Z80 emulator):
; the disc is a set of traps there, a program's memory plain RAM.
; =====================================================================

        IFDEF DB_HARNESS
        include "api/vos_api.inc"
DB_ADDR         equ #5100
DB_CACHE        equ #6C00
        IFNDEF DB_SLOTS
DB_SLOTS        equ 4
        ENDIF
TRAP            equ #0040           ; dk_* (tools/db_check.py)
FS_ERR_FULL     equ 8               ; (kernel/fs.asm)
        org DB_ADDR
        ENDIF

DB_PAGE         equ 1024
H_PAGES         equ 4               ; page 0
H_TABLES        equ 6
H_ALPHABET      equ 7               ; 0: ASCII so far, 2 V-OS character
                                    ; set (7 Greek: the same codes; 1
                                    ; Latin-1, of V-OS 0.15)
CS_VOS          equ 2
CS_LATIN1       equ 1
H_DESC          equ 16
DB_DESC         equ 124
T_NAME          equ 0               ; a table: 8 characters
T_FIELDS_N      equ 8               ; 1..10
T_KEY           equ 9               ; the key field, 1..10; 0: none
T_RECLEN        equ 10
T_KEYOFF        equ 11              ; where the key is in a record
T_KEYLEN        equ 12
T_KEYTYPE       equ 13
T_FIRST         equ 14              ; dw: the first data page
T_LAST          equ 16              ; dw: the last one
T_ROOT          equ 18              ; dw: the index's root
T_COUNT         equ 20              ; dw: records
T_HINT          equ 22              ; dw: a data page a delete freed
T_FIELD         equ 24              ; 10 fields of 10 bytes:
F_TYPE          equ 8               ;   name (8), type, length
F_LEN           equ 9
P_KIND          equ 0               ; every page but 0: "D", "L", "I"
P_TABLE         equ 1
D_NEXT          equ 2               ; data pages
D_USED          equ 4
D_SLOTS         equ 8               ; slots: a used byte, the record
P_COUNT         equ 2               ; index pages: dw entries
L_PREV          equ 4
L_NEXT          equ 6
I_CHILD0        equ 4
P_ENTRIES       equ 8
DB_DEPTH        equ 8               ; index levels at most
ENTRY_MAX       equ DB_KEY_MAX + 2

; C = DB_* call, DE, HL as it wants -> A, DE, HL; carry, A = error
db_start:
        jp db_call
        db "DB", 1

db_call:
        push ix
        ld (db_hl),hl
        ld (db_de),de
        ld a,c
        ld (db_fn),a
        cp DB_CALLS
        ld a,DB_ERR_BAD
        jr nc,.err
        ld a,c
        cp DB_CLOSE                 ; CREATE and OPEN: any program
        jr c,.go
        ld a,(db_is_open)
        or a
        ld a,DB_ERR_NONE
        jr z,.err
        call db_who                 ; the program that opened it only
        ld a,DB_ERR_IN_USE
        jr nz,.err
        call dk_begin
        jr c,.out
.go:
        ld a,(db_fn)                ; (dk_begin takes BC)
        ld l,a
        ld h,0
        add hl,hl
        ld de,dc_table
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,.done
        push de
        push hl
        ld de,(db_de)
        ld hl,(db_hl)
        ret                         ; to the call, back to .done
.done:
        jr c,.out
        push af                     ; its changes to the disc
        push de
        push hl
        call pg_flush
        pop hl
        pop de
        jr c,.flush
        pop af
        or a
        jr .out
.flush:
        pop de                      ; (its A)
.err:
        scf
.out:
        pop ix
        ret

dc_table:       dw dc_create, dc_open, dc_close, dc_new_table, dc_use
                dw dc_info, dc_add, dc_get, dc_put, dc_del, dc_find
                dw dc_first, dc_last, dc_next, dc_prev, dc_count
dc_table_end:
DB_CALLS        equ (dc_table_end - dc_table) / 2
        assert DB_CREATE == 0 && DB_OPEN == 1 && DB_CLOSE == 2
        assert DB_COUNT == DB_CALLS - 1

; ---------------------------------------------------------------------
; the calls
; ---------------------------------------------------------------------
; DE -> db drive, 11-byte name: a new database (none there before:
; NAME ALREADY USED), open
dc_create:
        call db_name_in
        xor a
        ld (db_is_open),a
        call dk_create
        ret c
        jr db_opened

; DE -> db drive, 11-byte name: that database open (another one shut)
dc_open:
        call db_name_in
        xor a
        ld (db_is_open),a
        call dk_open
        ret c
db_opened:
        call pg_reset
        ld a,#FF
        ld (cur_t),a
        ld hl,cur_ok
        ld b,DB_TABLES
.cursor:
        ld (hl),0
        inc hl
        djnz .cursor
        ld hl,0                     ; a database?
        call pg_get
        ret c
        ld de,db_magic
        ld b,4
.magic:
        ld a,(de)
        cp (hl)
        jr nz,.not_db
        inc hl
        inc de
        djnz .magic
        ld a,(hl)                   ; its pages
        ld (pg_count),a
        inc hl
        ld a,(hl)
        or a
        jr nz,.not_db
        ld a,1
        ld (db_is_open),a
        call db_who_set
        ld hl,0                     ; its alphabet: Latin-1, from
        call pg_get                 ; V-OS 0.15, is not the V-OS set
        ret c
        ld de,H_ALPHABET
        add hl,de
        ld a,(hl)
        xor CS_LATIN1               ; (no carry)
        ld a,0
        ret nz
        inc a                       ; 1: another alphabet
        ret
.not_db:
        ld a,DB_ERR_NOT_DB
        scf
        ret

; nothing open (everything is on the disc already)
dc_close:
        xor a
        ld (db_is_open),a
        ret

; DE -> drive and name in the program -> db_drive, db_name
db_name_in:
        ex de,hl
        ld de,db_drive
        ld bc,12
        jp db_in

; DE -> a table: name (8), fields (1..10), the key field (0: none,
; 1..10), then each field: name (8), type (DB_TEXT, DB_NUMBER,
; DB_ALPHA: text with an index without case or accents), length
; (a number: 2; a key: up to 64) -> A = its number, the table in use
dc_new_table:
        ex de,hl
        ld de,t_new
        ld bc,10
        call db_in                  ; name, fields, key
        ld hl,(db_de)
        ld de,10
        add hl,de
        ld de,t_new + T_FIELD
        ld bc,DB_FIELDS * 10
        call db_in
        ld hl,0                     ; room for it?
        call pg_get
        ret c
        ld de,H_TABLES
        add hl,de
        ld a,(hl)
        ld (t_num),a
        cp DB_TABLES
        ld a,DB_ERR_TABLES
        ccf
        ret c
        ld a,(t_new + T_FIELDS_N)   ; 1..10 fields, the key one of them
        or a
        jp z,.bad
        cp DB_FIELDS + 1
        jp nc,.bad
        ld b,a
        ld a,(t_new + T_KEY)
        dec a
        cp b
        jr c,.key_ok
        inc a
        jp nz,.bad
.key_ok:
        ld ix,t_new + T_FIELD       ; each field: its type and length
        ld c,1                      ; (B fields, C the one)
        ld e,0                      ; the record's length so far
.field:
        ld a,(ix + F_TYPE)
        cp DB_ALPHA + 1
        jp nc,.bad
        ld d,(ix + F_LEN)
        ld a,d
        or a
        jp z,.bad
        ld a,(ix + F_TYPE)
        cp DB_NUMBER
        jr nz,.length
        ld a,d
        cp 2
        jr nz,.bad
.length:
        ld a,(t_new + T_KEY)        ; the key field?
        cp c
        jr nz,.not_key
        ld a,d
        cp DB_KEY_MAX + 1
        jr nc,.bad
        ld (t_new + T_KEYLEN),a
        ld a,(ix + F_TYPE)
        ld (t_new + T_KEYTYPE),a
        ld a,e
        ld (t_new + T_KEYOFF),a
.not_key:
        ld a,e
        add a,d
        jr c,.bad
        ld e,a
        push de
        ld de,10
        add ix,de
        pop de
        inc c
        djnz .field
        ld a,e
        ld (t_new + T_RECLEN),a
        ld a,(t_new + T_KEY)
        or a
        jr nz,.keyed
        ld (t_new + T_KEYLEN),a
        ld (t_new + T_KEYOFF),a
        ld (t_new + T_KEYTYPE),a
.keyed:
        ld hl,t_new + T_FIRST       ; no pages yet
        ld b,T_FIELD - T_FIRST
.zero:
        ld (hl),0
        inc hl
        djnz .zero
        ld a,(t_new + T_KEY)        ; a key: an empty leaf, the root
        or a
        jr z,.store
        call pg_new
        ret c
        ld (hl),"L"
        inc hl
        ld a,(t_num)
        ld (hl),a
        ld (t_new + T_ROOT),de
.store:
        ld a,(t_num)
        call t_ptr_a                ; (page 0 dirty)
        ret c
        ex de,hl
        ld hl,t_new
        ld bc,DB_DESC
        ldir
        ld hl,0
        call pg_get
        ret c
        ld de,H_TABLES
        add hl,de
        inc (hl)
        ld a,(t_num)
        ld (cur_t),a
        or a
        ret
.bad:
        ld a,DB_ERR_DEF
        scf
        ret

; E = table: the one the calls below use
dc_use:
        ld a,e
        call t_exists
        ret c
        ld (cur_t),a
        or a
        ret

; E = table, HL -> DB_DESC bytes: its descriptor there -> A = tables
dc_info:
        ld a,e
        call t_exists
        ret c
        call t_ptr_a
        ret c
        ld de,(db_hl)
        ld bc,DB_DESC
        call db_out
        ld hl,0
        call pg_get
        ret c
        ld de,H_TABLES
        add hl,de
        ld a,(hl)
        or a
        ret

; A = table -> carry, A = DB_ERR_TABLE if there is none (A kept)
t_exists:
        push af
        ld hl,0
        call pg_get
        pop bc
        ret c
        ld de,H_TABLES
        add hl,de
        ld a,b
        cp (hl)
        jr nc,.none
        or a
        ret
.none:
        ld a,DB_ERR_TABLE
        scf
        ret

; HL -> a record: into the table and its index -> DE = its rid
dc_add:
        call t_load
        ret c
        call room_ok
        ret c
        ld hl,(db_hl)
        ld de,rec
        call rec_in
        call cs_mark
        ret c
        call d_room                 ; -> rid, DE -> its used byte
        ret c
        ld a,1
        ld (de),a
        inc de
        ld hl,rec
        call rec_copy
        ld hl,(tv_count)
        inc hl
        ld (tv_count),hl
        call t_store
        ret c
        ld a,(tv_keyed)
        or a
        jr z,.done
        call e_make
        call bt_insert
        ret c
.done:
        ld de,(rid)
        or a
        ret

; DE = rid, HL -> room for a record: that record there
dc_get:
        ld (rid),de
        call t_load
        ret c
        call r_find                 ; HL -> it
        ret c
        ld de,(db_hl)
        ld a,(tv_reclen)
        ld c,a
        ld b,0
        jp db_out

; DE = rid, HL -> a record: it instead of that one
dc_put:
        ld (rid),de
        call t_load
        ret c
        call r_find
        ret c
        ld a,(tv_keyed)
        or a
        jr z,.write
        ld de,rec                   ; the old entry
        call rec_copy
        call e_make
        call e_keep
        ld hl,(db_hl)               ; the new one
        ld de,rec
        call rec_in
        call e_make
        call e_same
        jr z,.write_rec
        call room_ok
        ret c
        call e_swap                 ; the old entry out, the new in
        call bt_delete
        ret c
        call e_swap
        call bt_insert
        ret c
        jr .write_rec
.write:
        ld hl,(db_hl)
        ld de,rec
        call rec_in
.write_rec:
        call cs_mark
        ret c
        call r_find
        ret c
        call pg_dirty
        ex de,hl
        ld hl,rec
        call rec_copy
        or a
        ret

; DE = rid: out of the table and its index
dc_del:
        ld (rid),de
        call t_load
        ret c
        call r_find
        ret c
        ld a,(tv_keyed)
        or a
        jr z,.free
        ld de,rec
        call rec_copy
        call e_make
        call bt_delete
        ret c
        call r_find
        ret c
.free:
        dec hl                      ; its slot free
        ld (hl),0
        call pg_dirty
        ld a,(rid + 1)              ; its page has room
        ld l,a
        ld h,0
        ld (tv_hint),hl
        call pg_get
        ret c
        call pg_dirty
        ld de,D_USED
        add hl,de
        dec (hl)
        ld hl,(tv_count)
        dec hl
        ld (tv_count),hl
        jp t_store

; HL -> a key (as in a record), E = how many of its bytes count (0:
; all) -> DE = the first record with that key or after it, in key
; order, and the cursor there. Carry: none (DB_ERR_END).
dc_find:
        call t_load
        ret c
        ld a,(tv_keyed)
        or a
        ld a,DB_ERR_NO_KEY
        scf
        ret z
        ld a,(tv_keylen)
        ld c,a
        ld a,(db_de)
        or a
        jr z,.all
        cp c
        jr c,.part
.all:
        ld a,c
.part:
        ld (find_n),a
        ld a,(tv_keyoff)            ; the key into rec, then the entry
        ld e,a
        ld d,0
        ld hl,rec
        add hl,de
        ex de,hl
        ld hl,(db_hl)
        ld b,0
        call db_in
        call e_make
        ld a,(find_n)
        jr seek_first

; -> DE = the first record, in key order (without a key: in the order
; of its pages), the cursor there. Carry: there is none.
dc_first:
        call t_load
        ret c
        ld a,(tv_keyed)
        or a
        jp z,rd_first
        xor a                       ; before every entry
seek_first:
        ld (cmp_n),a
        xor a
        ld (strict),a
        call bt_seek
        ret c
        jp c_found

; -> DE = the last record
dc_last:
        call t_load
        ret c
        ld a,(tv_keyed)
        or a
        jp z,rd_last
        ld hl,entry                 ; after every entry
        ld b,ENTRY_MAX
.ff:
        ld (hl),#FF
        inc hl
        djnz .ff
        jr seek_before

; -> DE = the record after the cursor's (in the same order). Carry:
; none.
dc_next:
        call t_load
        ret c
        call c_get
        ret c
        ld a,(tv_keyed)
        or a
        jp z,rd_next
        ld a,(tv_esz)
        ld (cmp_n),a
        ld a,1
        ld (strict),a
        call bt_seek
        ret c
        jp c_found

; -> DE = the record before the cursor's
dc_prev:
        call t_load
        ret c
        call c_get
        ret c
        ld a,(tv_keyed)
        or a
        jp z,rd_prev
seek_before:
        ld a,(tv_esz)
        ld (cmp_n),a
        call bt_seek_back
        ret c
        jp c_found

; -> HL = the records of the table in use
dc_count:
        call t_load
        ret c
        ld hl,(tv_count)
        or a
        ret

; room for what an ADD may need: a data page, and a page for each
; level of the index and one more (all of them split). Carry: A =
; FS_ERR_FULL (the disc) or DB_ERR_FULL (255 pages), nothing changed.
room_ok:
        ld c,1
        ld a,(tv_keyed)
        or a
        jr z,.count
        ld hl,(tv_root)             ; the index's levels: down child 0
.level:
        inc c
        push bc
        call pg_get
        pop bc
        ret c
        ld a,(hl)
        cp "I"
        jr nz,.count
        ld de,I_CHILD0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .level
.count:
        ld a,(db_room)
        cp c
        ld a,FS_ERR_FULL
        ret c
        ld a,(pg_count)
        add a,c
        ld a,DB_ERR_FULL
        ret c
        or a
        ret

; rec has a character over 127 in a text field, and the database has
; only ASCII so far: it is in the V-OS character set now (H_ALPHABET)
cs_mark:
        ld ix,t_new + T_FIELD
        ld hl,rec
        ld a,(t_new + T_FIELDS_N)
        ld c,a
.field:
        ld b,(ix + F_LEN)
        ld a,(ix + F_TYPE)
        cp DB_NUMBER
        jr z,.skip
.byte:
        bit 7,(hl)
        jr nz,.found
        inc hl
        djnz .byte
        jr .next
.skip:
        ld e,b
        ld d,0
        add hl,de
.next:
        ld de,10
        add ix,de
        dec c
        jr nz,.field
        or a
        ret
.found:
        ld hl,0
        call pg_get
        ret c
        ld de,H_ALPHABET
        add hl,de
        ld a,(hl)
        or a
        ret nz
        ld (hl),CS_VOS
        call pg_dirty
        or a
        ret

; ---------------------------------------------------------------------
; the table in use, and records
; ---------------------------------------------------------------------
; cur_t's descriptor -> t_new (a copy) and tv_*. Carry: none in use.
t_load:
        ld a,(cur_t)
        cp DB_TABLES
        ld a,DB_ERR_TABLE
        ccf
        ret c
        call t_ptr
        ret c
        ld de,t_new
        ld bc,DB_DESC
        ldir
        ld a,(t_new + T_RECLEN)
        ld (tv_reclen),a
        inc a                       ; records in a data page
        ld b,a
        ld hl,DB_PAGE - D_SLOTS
        call div_hl_b
        ld (tv_slots),a
        ld a,(t_new + T_KEY)
        ld (tv_keyed),a
        ld a,(t_new + T_KEYOFF)
        ld (tv_keyoff),a
        ld a,(t_new + T_KEYTYPE)
        ld (tv_keytype),a
        ld a,(t_new + T_KEYLEN)
        ld (tv_keylen),a
        add a,2
        ld (tv_esz),a
        ld b,a
        ld hl,DB_PAGE - P_ENTRIES   ; entries in a leaf
        call div_hl_b
        ld (tv_lcap),a
        ld a,(tv_esz)
        add a,2
        ld (tv_isz),a
        ld b,a
        ld hl,DB_PAGE - P_ENTRIES   ; in an inner page
        call div_hl_b
        ld (tv_icap),a
        ld hl,t_new + T_FIRST
        ld de,tv_first
        ld bc,10
        ldir
        or a
        ret

; tv_first ... tv_hint back into the descriptor
t_store:
        call t_ptr
        ret c
        ld de,T_FIRST
        add hl,de
        ex de,hl
        ld hl,tv_first
        ld bc,10
        ldir
        or a
        ret

; -> HL -> the descriptor of cur_t (t_ptr_a: of table A), in page 0,
; which is dirty then
t_ptr:
        ld a,(cur_t)
t_ptr_a:
        push af
        ld hl,0
        call pg_get
        pop bc
        ret c
        call pg_dirty
        ld de,H_DESC
        add hl,de
        ld de,DB_DESC
        inc b
.table:
        dec b
        ret z
        add hl,de
        jr .table

; HL / B -> A, at most 255
div_hl_b:
        ld e,b
        ld d,0
        xor a
.sub:
        or a
        sbc hl,de
        ret c
        inc a
        jr nz,.sub
        dec a
        ret

; HL -> a record in the program -> DE (here)
rec_in:
        ld a,(tv_reclen)
        ld c,a
        ld b,0
        jp db_in
; HL -> DE, a record's bytes
rec_copy:
        ld a,(tv_reclen)
        ld c,a
        ld b,0
        ldir
        ret

; rid -> HL -> its record, checked. Carry: DB_ERR_RID.
r_find:
        ld a,(rid + 1)              ; its page
        or a
        jr z,.bad
        ld hl,pg_count
        cp (hl)
        jr nc,.bad
        ld l,a
        ld h,0
        call pg_get
        ret c
        ld a,(hl)
        cp "D"
        jr nz,.bad
        inc hl
        ld a,(cur_t)
        cp (hl)
        jr nz,.bad
        dec hl
        ld a,(rid)                  ; its slot
        ld c,a
        ld a,(tv_slots)
        dec a
        cp c
        jr c,.bad
        call d_slot
        ld a,(hl)
        dec a
        jr nz,.bad
        inc hl
        ret
.bad:
        ld a,DB_ERR_RID
        scf
        ret

; HL -> a data page, C = slot -> HL -> its used byte (BC, DE kept)
d_slot:
        push de
        push bc
        ld de,D_SLOTS
        add hl,de
        ld a,(tv_reclen)
        inc a
        ld e,a
        ld d,0
        inc c
.slot:
        dec c
        jr z,.done
        add hl,de
        jr .slot
.done:
        pop bc
        pop de
        ret

; a free slot for a new record -> rid, DE -> its used byte (its page
; counted and dirty)
d_room:
        ld hl,(tv_hint)             ; where a delete left room
        call d_try
        ret nc
        ld hl,(tv_last)
        call d_try
        ret nc
        call pg_new                 ; a new page after the last
        ret c
        ld (hl),"D"
        inc hl
        ld a,(cur_t)
        ld (hl),a
        ld (d_page),de
        ld hl,(tv_last)
        ld a,h
        or l
        jr z,.first
        call pg_get                 ; the last one points to it
        ret c
        call pg_dirty
        ld de,D_NEXT
        add hl,de
        ld de,(d_page)
        ld (hl),e
        inc hl
        ld (hl),d
        jr .linked
.first:
        ld hl,(d_page)
        ld (tv_first),hl
.linked:
        ld hl,(d_page)
        ld (tv_last),hl
        call d_try
        ret nc
        ld a,DB_ERR_FULL
        ret
; HL = page (0: none) -> its first free slot: rid, DE -> its used
; byte. Carry: none there.
d_try:
        ld a,h
        or l
        scf
        ret z
        ld (d_page),hl
        call pg_get
        ret c
        push hl
        ld de,D_USED
        add hl,de
        ld a,(tv_slots)
        cp (hl)
        pop hl
        scf
        ret z
        call pg_dirty
        push hl
        ld de,D_USED
        add hl,de
        inc (hl)
        pop hl
        ld c,0
.slot:
        push hl
        call d_slot
        ld a,(hl)
        or a
        ex de,hl
        pop hl
        jr z,.free
        inc c
        jr .slot
.free:
        ld a,(d_page)
        ld (rid + 1),a
        ld a,c
        ld (rid),a
        or a
        ret

; the first record of a table without a key (in the order of its
; pages) -> the cursor
rd_first:
        ld hl,(tv_first)
        ld c,0
        call d_scan
        ret c
        jp c_rid

; after the cursor's
rd_next:
        ld a,(cursor + 1)
        ld l,a
        ld h,0
        ld a,(cursor)
        inc a
        ld c,a
        jr nz,.scan
        scf                         ; (slot 255 was the last)
        ld a,DB_ERR_END
        ret
.scan:
        call d_scan
        ret c
        jp c_rid

; HL = page (0: none), C = slot: the first record there or after it,
; in the chain -> rid. Carry: DB_ERR_END.
d_scan:
        ld a,h
        or l
        ld a,DB_ERR_END
        scf
        ret z
        ld (d_page),hl
        push bc
        call pg_get
        pop bc
        ret c
.slot:
        ld a,(tv_slots)
        dec a
        cp c
        jr c,.next_page
        push hl
        call d_slot
        ld a,(hl)
        pop hl
        or a
        jr nz,.found
        inc c
        jr .slot
.next_page:
        ld de,D_NEXT
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,0
        jr d_scan
.found:
        ld a,(d_page)
        ld (rid + 1),a
        ld a,c
        ld (rid),a
        or a
        ret

; the last record: the one before none
rd_last:
        ld hl,#FFFF
        ld (cursor),hl
        ; fall through
; the record before the cursor's: a walk from the first, the last one
; met before it
rd_prev:
        ld hl,0
        ld (d_before),hl
        ld hl,(tv_first)
        ld c,0
.walk:
        call d_scan
        jr c,.end
        ld hl,(rid)
        ld de,(cursor)
        or a
        sbc hl,de
        jr z,.end
        ld hl,(rid)
        ld (d_before),hl
        ld a,(rid + 1)
        ld l,a
        ld h,0
        ld a,(rid)
        inc a
        ld c,a
        jr nz,.walk
        ld de,D_NEXT                ; (after slot 255: the next page)
        push hl
        call pg_get
        pop de
        ret c
        ld de,D_NEXT
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,0
        jr .walk
.end:
        ld hl,(d_before)
        ld a,h
        or l
        ld a,DB_ERR_END
        scf
        ret z
        ld (rid),hl
        jp c_rid

; ---------------------------------------------------------------------
; cursors: for each table its last entry (key + rid), or rid
; ---------------------------------------------------------------------
; HL -> an entry in a leaf: the cursor -> rid, and the record to the
; program (db_hl, if not 0) -> DE = rid
c_found:
        ld de,entry
        ld a,(tv_esz)
        ld c,a
        ld b,0
        ldir
        dec hl                      ; its rid: high byte first
        ld a,(hl)
        ld (rid),a
        dec hl
        ld a,(hl)
        ld (rid + 1),a
        ; fall through
; rid (and entry) -> the cursor; the record to the program
c_rid:
        call c_ptr
        ld a,1
        ld (de),a
        ld de,(c_at)
        ld hl,entry
        ld a,(tv_keyed)
        or a
        jr nz,.copy
        ld hl,rid
.copy:
        ld bc,ENTRY_MAX
        ldir
        ld hl,(db_hl)
        ld a,h
        or l
        jr z,.rid
        call r_find
        ret c
        ld de,(db_hl)
        ld a,(tv_reclen)
        ld c,a
        ld b,0
        call db_out
.rid:
        ld de,(rid)
        or a
        ret

; -> DE -> cur_ok of cur_t, c_at -> its cursor
c_ptr:
        ld a,(cur_t)
        ld e,a
        ld d,0
        ld hl,cur_ok
        add hl,de
        push hl
        ld hl,cursors
        ld de,ENTRY_MAX
        inc a
.t:
        dec a
        jr z,.at
        add hl,de
        jr .t
.at:
        ld (c_at),hl
        pop de
        ret

; the cursor -> entry (with a key) or cursor (its rid). Carry: none.
c_get:
        call c_ptr
        ld a,(de)
        or a
        ld a,DB_ERR_END
        scf
        ret z
        ld hl,(c_at)
        ld de,entry
        ld a,(tv_keyed)
        or a
        jr nz,.copy
        ld de,cursor
.copy:
        ld bc,ENTRY_MAX
        ldir
        or a
        ret

; ---------------------------------------------------------------------
; the index
; ---------------------------------------------------------------------
; rec, rid -> entry: the key (a number high byte first), the rid (high
; byte first)
e_make:
        ld a,(tv_keyoff)
        ld e,a
        ld d,0
        ld hl,rec
        add hl,de
        ld de,entry
        ld a,(tv_keytype)
        cp DB_NUMBER
        jr nz,.text
        inc hl                      ; high byte, then low
        ld a,(hl)
        ld (de),a
        inc de
        dec hl
        ld a,(hl)
        ld (de),a
        inc de
        jr .rid
.text:
        ld a,(tv_keylen)
        ld b,a
        ld a,(tv_keytype)
        cp DB_ALPHA
        jr z,.fold
        ld c,b
        ld b,0
        ldir
        jr .rid
.fold:                              ; without case or accents
        ld a,(hl)
        call fold_a
        ld (de),a
        inc hl
        inc de
        djnz .fold
.rid:
        ld a,(rid + 1)
        ld (de),a
        inc de
        ld a,(rid)
        ld (de),a
        ret

; A = a V-OS character -> A = its letter without case or accent
; (fold.inc, from tools/voscs.py); others as they are
fold_a:
        cp 128
        jr nc,.high
        cp "a"
        ret c
        cp "z" + 1
        ret nc
        sub "a" - "A"
        ret
.high:
        push hl
        push de
        ld e,a
        ld d,0
        ld hl,fold_tab - 128
        add hl,de
        ld a,(hl)
        pop de
        pop hl
        ret
        include "fold.inc"

; entry -> e_old; e_swap: the two change places
e_keep:
        ld hl,entry
        ld de,e_old
        ld bc,ENTRY_MAX
        ldir
        ret
e_swap:
        ld hl,entry
        ld de,e_old
        ld b,ENTRY_MAX
.byte:
        ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        inc hl
        inc de
        djnz .byte
        ret
; -> Z: entry and e_old are the same
e_same:
        ld hl,entry
        ld de,e_old
        ld a,(tv_esz)
        ld b,a
.byte:
        ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .byte
        ret

; the first cmp_n bytes of entry against the entry at HL -> carry:
; entry comes before it; Z: the same. When cmp_n is less than a whole
; entry, the same bytes mean before it. HL, DE, BC kept.
e_cmp:
        push hl
        push de
        push bc
        ld de,entry
        ld a,(cmp_n)
        or a
        jr z,.before
        ld b,a
.byte:
        ld a,(de)
        cp (hl)
        jr nz,.done
        inc hl
        inc de
        djnz .byte
        ld a,(tv_esz)
        ld b,a
        ld a,(cmp_n)
        cp b
        jr z,.done
.before:
        scf
.done:
        pop bc
        pop de
        pop hl
        ret

; HL -> an index page, A = entry -> HL -> it (B = size: tv_esz in a
; leaf, tv_isz in an inner page; DE kept)
e_at:
        push de
        ld de,P_ENTRIES
        add hl,de
        ld e,b
        ld d,0
        inc a
.e:
        dec a
        jr z,.done
        add hl,de
        jr .e
.done:
        pop de
        ret

; down the index to the leaf where entry belongs -> bt_leaf, and the
; way: bt_path (the pages), bt_at (the child taken: 0 = child 0, i =
; the one after separator i - 1), bt_depth inner pages
bt_descend:
        xor a
        ld (bt_depth),a
        ld hl,(tv_root)
.page:
        ld (bt_leaf),hl
        call pg_get
        ret c
        ld a,(hl)
        cp "L"
        ret z
        cp "I"
        jr nz,.broken
        ld (bt_pg),hl
        ld a,(bt_depth)             ; on the way
        cp DB_DEPTH
        jr nc,.broken
        ld e,a
        ld d,0
        ld hl,bt_path
        add hl,de
        add hl,de
        ld bc,(bt_leaf)
        ld (hl),c
        inc hl
        ld (hl),b
        ld hl,(bt_pg)
        inc hl
        inc hl
        ld c,(hl)                   ; its separators (fewer than 256)
        ld b,0                      ; the child: separators <= entry
.sep:
        ld a,b
        cp c
        jr z,.child
        push bc
        ld e,b
        ld a,(tv_isz)
        ld b,a
        ld a,e
        ld hl,(bt_pg)
        call e_at
        call e_cmp
        pop bc
        jr c,.child
        inc b
        jr .sep
.child:
        ld a,(bt_depth)
        ld e,a
        ld d,0
        ld hl,bt_at
        add hl,de
        ld (hl),b
        ld hl,(bt_pg)
        ld a,b
        or a
        jr nz,.after
        ld de,I_CHILD0
        add hl,de
        jr .go
.after:
        dec a                       ; the one after separator A - 1
        ld e,a
        ld a,(tv_isz)
        ld b,a
        ld a,e
        call e_at
        ld a,(tv_esz)
        ld e,a
        ld d,0
        add hl,de
.go:
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(bt_depth)
        inc a
        ld (bt_depth),a
        jr .page
.broken:
        ld a,DB_ERR_BROKEN
        scf
        ret

; the leaf page bt_leaf -> HL -> it, BC = its entries
bt_leaf_get:
        ld hl,(bt_leaf)
        call pg_get
        ret c
        push hl
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        pop hl
        or a
        ret

; in leaf HL (C entries): the first entry that entry comes before
; (strict: before; else before or the same) -> A = its number (C:
; none). HL, C kept.
bt_scan:
        ld (bt_pg),hl
        ld b,0
.e:
        ld a,b
        cp c
        jr z,.here
        push bc
        ld e,b
        ld a,(tv_esz)
        ld b,a
        ld a,e
        ld hl,(bt_pg)
        call e_at
        call e_cmp
        pop bc
        jr c,.here
        jr nz,.on
        ld a,(strict)
        or a
        jr z,.here
.on:
        inc b
        jr .e
.here:
        ld hl,(bt_pg)
        ld a,b
        ret

; the first entry at or after entry (strict: after it), cmp_n bytes ->
; HL -> it, in its leaf. Carry: none (DB_ERR_END).
bt_seek:
        call bt_descend
        ret c
        call bt_leaf_get
        ret c
        call bt_scan
.leaf:
        cp c                        ; past this leaf's end: the next
        jr c,.found
        ld de,L_NEXT
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h
        ld a,DB_ERR_END
        scf
        ret z
        ld (bt_leaf),hl
        call bt_leaf_get
        ret c
        xor a
        jr .leaf
.found:
        push af
        ld a,(tv_esz)
        ld b,a
        pop af
        jp e_at

; the last entry before entry (cmp_n bytes) -> HL -> it. Carry: none.
bt_seek_back:
        xor a
        ld (strict),a
        call bt_descend
        ret c
        call bt_leaf_get
        ret c
        call bt_scan                ; the first one not before it
.leaf:
        or a
        jr nz,.found
        ld de,L_PREV                ; none here: the leaf before
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or h
        ld a,DB_ERR_END
        scf
        ret z
        ld (bt_leaf),hl
        call bt_leaf_get
        ret c
        ld a,c
        jr .leaf
.found:
        dec a
        push af
        ld a,(tv_esz)
        ld b,a
        pop af
        jp e_at

; ---------------------------------------------------------------------
; insert and delete: entry into the index of the table in use
; ---------------------------------------------------------------------
bt_insert:
        ld a,(tv_esz)
        ld (cmp_n),a
        xor a
        ld (strict),a
        call bt_descend
        ret c
        call bt_leaf_get
        ret c
        call bt_scan                ; its place: A
        ld (ins_at),a
        ld a,(tv_esz)
        ld (ins_sz),a
        ld a,(tv_lcap)
        ld (ins_cap),a
        ld hl,entry                 ; what goes in
        ld (ins_from),hl
        ld hl,(bt_leaf)
        ld (ins_page),hl
        call ins_page_in            ; Z: it fitted
        ret c
        ret z
        ; the leaf split: the left half stays (ibuf), the right half goes
        ; to a new leaf, linked between it and the next
        call pg_new
        ret c
        ld (ins_right),de
        ld (hl),"L"
        inc hl
        ld a,(cur_t)
        ld (hl),a
        call ins_halves             ; both pages from ibuf
        ret c
        ld hl,(ins_page)            ; links: left <-> right <-> next
        call pg_get
        ret c
        call pg_dirty
        ld de,L_NEXT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (ins_next),de
        ld de,(ins_right)
        ld (hl),d
        dec hl
        ld (hl),e
        ld hl,(ins_right)
        call pg_get
        ret c
        ld de,L_PREV
        add hl,de
        ld de,(ins_page)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(ins_next)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(ins_next)
        ld a,h
        or l
        jr z,.up
        call pg_get
        ret c
        call pg_dirty
        ld de,L_PREV
        add hl,de
        ld de,(ins_right)
        ld (hl),e
        inc hl
        ld (hl),d
.up:
        ld hl,(ins_right)           ; up: its first entry, and it
        call pg_get
        ret c
        ld de,P_ENTRIES
        add hl,de
        ld de,ins_sep
        ld a,(tv_esz)
        ld c,a
        ld b,0
        ldir
        ; fall through
; ins_sep + ins_right go into the inner page above (bt_depth levels
; left), which may split again; at the top a new root
bt_up:
        ld a,(bt_depth)
        or a
        jr z,.root
        dec a
        ld (bt_depth),a
        ld e,a                      ; the page above, and the child
        ld d,0                      ; taken there
        ld hl,bt_at
        add hl,de
        ld a,(hl)
        ld (ins_at),a
        ld hl,bt_path
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (ins_page),hl
        ld hl,(ins_right)           ; separator + child, after it
        ld (ins_child),hl
        call ins_entry
        ld a,(tv_isz)
        ld (ins_sz),a
        ld a,(tv_icap)
        ld (ins_cap),a
        call ins_page_in
        ret c
        ret z
        call pg_new                 ; split: a new inner page
        ret c
        ld (ins_right),de
        ld (hl),"I"
        inc hl
        ld a,(cur_t)
        ld (hl),a
        call ins_halves             ; the middle one goes up
        ret c
        jr bt_up
.root:
        call pg_new                 ; a new root: old root, ins_sep,
        ret c                       ; ins_right
        ld (tv_root_new),de
        ld (hl),"I"
        inc hl
        ld a,(cur_t)
        ld (hl),a
        inc hl
        ld (hl),1
        inc hl
        inc hl
        ld de,(tv_root)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc hl
        inc hl
        ex de,hl
        ld hl,ins_sep
        ld a,(tv_esz)
        ld c,a
        ld b,0
        ldir
        ld hl,(ins_right)
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(tv_root_new)
        ld (tv_root),hl
        jp t_store

; ins_sep + ins_child -> ins_buf (an inner page's entry)
ins_entry:
        ld hl,ins_sep
        ld de,ins_buf
        ld a,(tv_esz)
        ld c,a
        ld b,0
        ldir
        ld hl,(ins_child)
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,ins_buf
        ld (ins_from),hl
        ret

; ins_from (ins_sz bytes) into page ins_page as entry ins_at. Room:
; there, Z. Else the page's entries with it in ibuf (ins_n of them),
; NZ.
ins_page_in:
        ld hl,(ins_page)
        call pg_get
        ret c
        call pg_dirty
        push hl
        inc hl
        inc hl
        ld a,(hl)                   ; entries
        ld (ins_n),a
        pop hl
        ld de,ibuf                  ; all of them to ibuf, with it
        push hl
        ld a,(ins_sz)
        ld b,a
        xor a
        call e_at                   ; HL -> the first
        ld a,(ins_at)
        call .copy_n                ; those before it
        push hl
        ld hl,(ins_from)
        ld a,(ins_sz)
        ld c,a
        ld b,0
        ldir
        pop hl
        ld a,(ins_at)
        ld b,a
        ld a,(ins_n)
        sub b
        call .copy_n                ; those after it
        pop hl
        ld a,(ins_n)
        inc a
        ld (ins_n),a
        ld b,a
        ld a,(ins_cap)
        cp b
        jr c,.full
        ld a,(ins_n)                ; room: all back
        call ins_write
        xor a
        ret
.full:
        or 1
        ret
; A entries of ins_sz bytes: HL -> DE
.copy_n:
        or a
        ret z
        ld b,a
.entry:
        push bc
        ld a,(ins_sz)
        ld c,a
        ld b,0
        ldir
        pop bc
        djnz .entry
        ret

; HL -> an index page: A entries from ibuf into it, its count
ins_write:
        push hl
        inc hl
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        pop hl
        ld de,P_ENTRIES
        add hl,de
        ex de,hl
        ld hl,ibuf
        or a
        ret z
        ld b,a
.entry:
        push bc
        ld a,(ins_sz)
        ld c,a
        ld b,0
        ldir
        pop bc
        djnz .entry
        ret

; ibuf (ins_n entries) into page ins_page and the new page ins_right:
; the first half stays. Leaves: the right half from the middle on, and
; ins_sep the right's first entry (bt_insert takes it). Inner pages:
; the middle entry goes up as ins_sep, its child the right's child 0.
ins_halves:
        ld a,(ins_n)
        srl a
        ld (ins_m),a
        ld hl,(ins_page)            ; the left: the first half
        call pg_get
        ret c
        call pg_dirty
        ld a,(ins_m)
        call ins_write
        ld a,(ins_m)                ; HL -> ibuf entry ins_m
        ld b,a
        ld a,(ins_sz)
        ld e,a
        ld d,0
        ld hl,ibuf
        inc b
.skip:
        dec b
        jr z,.at_m
        add hl,de
        jr .skip
.at_m:
        ld a,(ins_sz)
        ld b,a
        ld a,(tv_esz)
        cp b
        ld a,(ins_n)                ; leaves: from the middle on
        jr z,.right
        ld de,ins_sep               ; inner: the middle one up
        ld a,(tv_esz)
        ld c,a
        ld b,0
        ldir
        ld e,(hl)                   ; its child: the right's child 0
        inc hl
        ld d,(hl)
        inc hl
        ld (ins_child),de
        ld a,(ins_n)
        dec a
.right:
        ld b,a
        ld a,(ins_m)
        neg
        add a,b                     ; entries on the right
        push af
        push hl
        ld hl,(ins_right)
        call pg_get
        pop de
        pop bc
        ret c
        ld a,(ins_sz)               ; inner: child 0
        ld c,a
        ld a,(tv_esz)
        cp c
        jr z,.leaf
        push hl
        push de
        ld de,I_CHILD0
        add hl,de
        ld de,(ins_child)
        ld (hl),e
        inc hl
        ld (hl),d
        pop de
        pop hl
.leaf:
        push hl                     ; the entries: from DE (in ibuf)
        inc hl
        inc hl
        ld (hl),b
        inc hl
        ld (hl),0
        pop hl
        ld a,b
        or a
        ret z
        push bc
        ld bc,P_ENTRIES
        add hl,bc
        ex de,hl
        pop bc
.entry:
        push bc
        ld a,(ins_sz)
        ld c,a
        ld b,0
        ldir
        pop bc
        djnz .entry
        or a
        ret

; entry out of the index: its leaf, the entry taken out (no merging).
; Carry: it was not there (DB_ERR_BROKEN).
bt_delete:
        ld a,(tv_esz)
        ld (cmp_n),a
        xor a
        ld (strict),a
        call bt_descend
        ret c
        call bt_leaf_get
        ret c
        call bt_scan
        cp c
        jr nc,.broken
        ld b,a                      ; the entries after it
        ld a,c
        sub b
        dec a
        ld (del_after),a
        push hl
        ld a,(tv_esz)
        ld e,a
        ld a,b
        ld b,e
        call e_at
        call e_cmp
        pop bc                      ; BC -> the leaf
        jr nz,.broken
        push bc
        ld d,h                      ; the rest one entry back
        ld e,l
        ld a,(tv_esz)
        ld c,a
        ld b,0
        add hl,bc
        ld a,(del_after)
        or a
        jr z,.moved
.entry:
        push af
        ld a,(tv_esz)
        ld c,a
        ld b,0
        ldir
        pop af
        dec a
        jr nz,.entry
.moved:
        pop hl
        call pg_dirty
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec de
        ld (hl),d
        dec hl
        ld (hl),e
        or a
        ret
.broken:
        ld a,DB_ERR_BROKEN
        scf
        ret

; ---------------------------------------------------------------------
; the page cache: DB_SLOTS pages at DB_CACHE; a page stays while the
; DB_SLOTS - 1 other pages used last stay
; ---------------------------------------------------------------------
pg_reset:
        ld hl,pg_of
        ld b,DB_SLOTS * 3
.clear:
        ld (hl),0
        inc hl
        djnz .clear
        ld hl,pg_lru
        xor a
.lru:
        ld (hl),a
        inc hl
        inc a
        cp DB_SLOTS
        jr c,.lru
        ret

; HL = page -> HL -> it in the cache. Carry: A = error.
pg_get:
        inc hl                      ; pg_of: page + 1 (0: empty)
        ld (pg_want),hl
        ld de,pg_of
        ld b,0
.find:
        ld a,(de)
        cp l
        jr nz,.no
        inc de
        ld a,(de)
        dec de
        cp h
        jr z,.found
.no:
        inc de
        inc de
        inc b
        ld a,b
        cp DB_SLOTS
        jr c,.find
        call pg_evict               ; B = the slot, empty now
        ret c
        push bc
        ld hl,(pg_want)             ; read it
        dec hl
        ex de,hl
        ld a,b
        call pg_addr
        call dk_read
        pop bc
        ret c
        ld a,b
        call pg_of_at
        ld de,(pg_want)
        ld (hl),e
        inc hl
        ld (hl),d
.found:
        ld a,b
        call pg_touch
        ld a,b
        jp pg_addr

; -> B = the slot used least lately, its page written if dirty, empty
pg_evict:
        ld a,(pg_lru + DB_SLOTS - 1)
        ld b,a
        ld hl,pg_dirt
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr z,.clean
        ld (hl),0
        push bc
        ld a,b
        call pg_of_at
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec de
        ld a,b
        call pg_addr
        call dk_write
        pop bc
        ret c
.clean:
        ld a,b
        call pg_of_at
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        ret

; A = slot: first in pg_lru (BC kept)
pg_touch:
        push bc
        ld hl,pg_lru
        ld b,DB_SLOTS
.find:
        cp (hl)
        jr z,.found
        inc hl
        djnz .find
.found:
        ld c,a                      ; those before it one on
.move:
        dec hl
        ld de,pg_lru
        or a
        push hl
        inc hl
        sbc hl,de
        pop hl
        jr z,.first
        ld a,(hl)
        inc hl
        ld (hl),a
        dec hl
        jr .move
.first:
        ld a,c
        ld (pg_lru),a
        pop bc
        ret

; A = slot -> HL -> its page in the cache (BC, DE kept)
pg_addr:
        add a,a
        add a,a
        add a,DB_CACHE >> 8
        ld h,a
        ld l,0
        ret

; A = slot -> HL -> its pg_of word
pg_of_at:
        add a,a
        add a,pg_of & #FF
        ld l,a
        adc a,pg_of >> 8
        sub l
        ld h,a
        ret

; HL -> in a cached page: that page is dirty (all registers kept)
pg_dirty:
        push af
        push hl
        push de
        ld a,h
        sub DB_CACHE >> 8
        rrca
        rrca
        and #3F
        ld e,a
        ld d,0
        ld hl,pg_dirt
        add hl,de
        ld (hl),1
        pop de
        pop hl
        pop af
        ret

; a new page at the end of the file -> DE = its number, HL -> it in
; the cache, empty and dirty. Carry: the file or the disc is full.
pg_new:
        ld a,(pg_count)
        cp 255
        ld a,DB_ERR_FULL
        ccf
        ret c
        ld a,(db_room)
        sub 1
        ld a,FS_ERR_FULL
        ret c
        call dk_append              ; a block for it on the disc
        ret c
        ld hl,db_room
        dec (hl)
        ld hl,0                     ; one page more
        call pg_get
        ret c
        call pg_dirty
        ld de,H_PAGES
        add hl,de
        ld a,(pg_count)
        ld (pg_new_n),a
        inc a
        ld (pg_count),a
        ld (hl),a
        call pg_evict               ; a slot for it
        ret c
        ld a,b
        call pg_of_at
        ld a,(pg_new_n)
        inc a
        ld (hl),a
        inc hl
        ld (hl),0
        ld hl,pg_dirt
        ld e,b
        ld d,0
        add hl,de
        ld (hl),1
        ld a,b
        call pg_touch
        ld a,b
        call pg_addr
        push hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,DB_PAGE - 1
        ldir
        pop hl
        ld a,(pg_new_n)
        ld e,a
        ld d,0
        or a
        ret

; every dirty page to the disc
pg_flush:
        ld b,0
.slot:
        ld hl,pg_dirt
        ld e,b
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        jr z,.next
        ld (hl),0
        push bc
        ld a,b
        call pg_of_at
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec de
        ld a,b
        call pg_addr
        call dk_write
        pop bc
        ret c
.next:
        inc b
        ld a,b
        cp DB_SLOTS
        jr c,.slot
        or a
        ret

; ---------------------------------------------------------------------
; the disc, and a program's memory
; ---------------------------------------------------------------------
        IFDEF DB_HARNESS
; traps for tools/db_check.py: it does the work and returns
dk_begin:       jp TRAP + 0         ; -> carry, A
dk_create:      jp TRAP + 3         ; db_drive, db_name
dk_open:        jp TRAP + 6
dk_read:        jp TRAP + 9         ; DE = page, HL -> 1K
dk_write:       jp TRAP + 12
dk_append:      jp TRAP + 15        ; one block more
db_who:         xor a               ; Z: the program that opened it
                ret
db_who_set:     ret
db_in:                              ; HL (program) -> DE, BC bytes
db_out:                             ; HL -> DE (program)
        ld a,b
        or c
        ret z
        ldir
        ret
        ELSE
; before each call with a database open: its drive, its format
dk_begin:
        ld a,(db_drive)
        call fdc_select
        ld hl,db_fmt
        ld de,fs_first_id
        ld bc,3
        ldir
        or a
        ret

; a new file of one page, page 0 empty but for "VDB1" and 1 page
dk_create:
        ld a,(db_drive)
        call fdc_select
        ld hl,db_name
        call fs_exists
        ld a,FS_ERR_EXISTS
        ccf
        ret c
        ld hl,DB_CACHE              ; (the cache is empty then)
        ld de,DB_CACHE + 1
        ld bc,DB_PAGE - 1
        ld (hl),0
        ldir
        ld hl,db_magic
        ld de,DB_CACHE
        ld bc,4
        ldir
        ld a,1
        ld (de),a
        ld a,#FF                    ; no AMSDOS header
        ld (fs_hdr_type),a
        ld hl,db_name
        ld de,DB_CACHE
        ld bc,DB_PAGE
        ld a,EXT2_CFG
        call fs_save
        ret c
        ; fall through
; the file's blocks -> db_blocks, db_nblocks; its format -> db_fmt
dk_open:
        ld a,(db_drive)
        call fdc_select
        ld hl,db_name
        call fs_set_name
        call fs_mount
        ret c
        call fs_collect
        ret c
        ld hl,fs_first_id
        ld de,db_fmt
        ld bc,3
        ldir
        call fs_free_k              ; the room on the disc
        ld (db_room),a
dk_blocks:
        ld hl,fs_blist
        ld de,db_blocks
        ld bc,180
        ldir
        ld a,(fs_nblocks)
        ld (db_nblocks),a
        or a
        ret

; DE = page -> HL -> 1K: from its block (dk_write: to it)
dk_read:
        call dk_sector
        ret c
        ld b,2
.half:
        push bc
        push hl
        push de
        ex de,hl
        call fs_read_ls
        pop de
        pop hl
        pop bc
        ret c
        push bc
        ex de,hl
        push hl
        ld hl,fs_buf
        ld bc,512
        ldir
        pop hl
        ex de,hl
        inc de
        pop bc
        djnz .half
        or a
        ret
dk_write:
        call dk_sector
        ret c
        ld b,2
.half:
        push bc
        push de
        ld de,fs_buf
        ld bc,512
        ldir
        pop de
        push hl
        push de
        ex de,hl
        call fs_write_ls
        pop de
        pop hl
        pop bc
        ret c
        inc de
        djnz .half
        or a
        ret
; DE = page -> DE = its first sector in the data area (HL kept)
dk_sector:
        ld a,(db_nblocks)
        dec a
        cp e
        ld a,FS_ERR_NOT_FOUND
        ret c
        push hl
        ld hl,db_blocks
        add hl,de
        ld e,(hl)
        ld d,0
        ex de,hl
        add hl,hl
        ex de,hl
        pop hl
        or a
        ret

; one block more for the file: the directory read again (the file as
; it was?), a free block, the entries written again
dk_append:
        ld hl,db_name
        call fs_set_name
        call fs_mount
        ret c
        call fs_collect
        ret c
        ld a,(fs_nblocks)
        ld hl,db_nblocks
        cp (hl)
        ld a,FS_ERR_NOT_FOUND       ; another disc?
        scf
        ret nz
        ld a,2                      ; a free block
.block:
        ld hl,fs_blocks
        cp (hl)
        jr nc,.full
        push af
        call fs_used
        jr z,.free
        pop af
        inc a
        jr .block
.full:
        ld a,FS_ERR_FULL
        scf
        ret
.free:
        pop af
        push af
        call fs_mark
        ld a,(fs_nblocks)
        ld e,a
        ld d,0
        ld hl,fs_blist
        add hl,de
        pop af
        ld (hl),a
        ld hl,fs_nblocks
        inc (hl)
        ld a,(hl)
        add a,15                    ; entries = (blocks + 15) / 16
        rrca
        rrca
        rrca
        rrca
        and #0F
        ld (fs_extents),a
        ld a,(hl)                   ; records = blocks * 8
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld (fs_records),hl
        call fs_unlink
        call fs_free_entries
        ld hl,fs_extents
        cp (hl)
        ld a,FS_ERR_DIR_FULL
        ret c
        call fs_write_entries
        ret c
        jp dk_blocks

; the program that called (app_slot) opened the database? -> Z
db_who:
        ld a,(app_slot)
        ld hl,db_owner
        cp (hl)
        ret
db_who_set:
        ld a,(app_slot)
        ld (db_owner),a
        ret

; BC bytes from HL in the program's bank to DE here (db_out: from HL
; here to DE there)
db_in:
        ld a,(vw_cfg)
        ld (ab_from),a
        ld a,EXT2_CFG
        ld (ab_to),a
        jp bank_copy
db_out:
        ld a,EXT2_CFG
        ld (ab_from),a
        ld a,(vw_cfg)
        ld (ab_to),a
        jp bank_copy
        ENDIF

; ---- data ------------------------------------------------------------
db_magic:       db "VDB1"
db_is_open:     db 0
db_owner:       db 0
db_drive:       db 0                ; with db_name: as a program gives
db_name:        ds 11
db_fmt:         ds 3                ; fs_first_id, fs_reserved, fs_blocks
db_nblocks:     db 0
db_room:        db 0                ; free blocks on the disc (at OPEN)
db_blocks:      ds 180
db_hl:          dw 0
db_fn:          db 0
db_de:          dw 0
pg_count:       dw 0                ; pages in the file (< 256)
pg_want:        dw 0
pg_new_n:       db 0
pg_of:          ds DB_SLOTS * 2     ; each slot: its page + 1
pg_dirt:        ds DB_SLOTS
pg_lru:         ds DB_SLOTS         ; slots, the one used last first
cur_t:          db #FF              ; the table in use
cur_ok:         ds DB_TABLES        ; its cursor set?
cursors:        ds DB_TABLES * ENTRY_MAX
cursor:         dw 0                ; a cursor's rid (no key)
c_at:           dw 0
t_num:          db 0
t_new:          ds DB_DESC          ; the descriptor of the table in use
tv_reclen:      db 0
tv_slots:       db 0
tv_keyed:       db 0
tv_keyoff:      db 0
tv_keytype:     db 0
tv_keylen:      db 0
tv_esz:         db 0                ; a leaf's entry: key + rid
tv_isz:         db 0                ; an inner page's: + child
tv_lcap:        db 0
tv_icap:        db 0
tv_first:       dw 0                ; as T_FIRST ... T_HINT
tv_last:        dw 0
tv_root:        dw 0
tv_count:       dw 0
tv_hint:        dw 0
tv_root_new:    dw 0
rid:            dw 0                ; low byte the slot, high the page
d_page:         dw 0
d_before:       dw 0
rec:            ds 256
entry:          ds ENTRY_MAX
e_old:          ds ENTRY_MAX
find_n:         db 0
cmp_n:          db 0
strict:         db 0
bt_depth:       db 0
bt_leaf:        dw 0
bt_pg:          dw 0
del_after:      db 0
bt_path:        ds DB_DEPTH * 2
bt_at:          ds DB_DEPTH
ins_at:         db 0
ins_n:          db 0
ins_m:          db 0
ins_sz:         db 0
ins_cap:        db 0
ins_from:       dw 0
ins_page:       dw 0
ins_right:      dw 0
ins_next:       dw 0
ins_child:      dw 0
ins_sep:        ds ENTRY_MAX
ins_buf:        ds ENTRY_MAX + 2
ibuf:           ds DB_PAGE + ENTRY_MAX + 2
db_stop:
        assert db_stop <= DB_CACHE

VBUFMAX equ 4096
VBUF    equ 0xE000

cmd_vi:
    mov si, [argp]
    cmp byte [si], 0
    je .usage
    mov di, vname
    mov cx, 15
.cpname:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jz .named
    dec cx
    jnz .cpname
    mov byte [di], 0
.named:
    mov word [argp], vname
    mov byte [vmode], 0
    mov byte [vmod], 0
    mov byte [vquit], 0
    mov word [vmsgp], 0
    mov word [vtop], 0
    mov word [vpos], 0
    mov word [vcmdlen], 0
    mov byte [vcmd], 0
    call vi_load
    mov ax, 0x0003
    int 0x10
.loop:
    call vi_draw
    call vi_getkey
    mov word [vmsgp], 0
    cmp byte [vch], 27
    je .esc
    cmp byte [vch], 0
    je .special
    cmp byte [vmode], 1
    je .insert
    cmp byte [vmode], 2
    je .command
    jmp .normal
.esc:
    mov byte [vmode], 0
    jmp .next
.special:
    cmp byte [vscan], 0x48
    je .up
    cmp byte [vscan], 0x50
    je .down
    cmp byte [vscan], 0x4B
    je .left
    cmp byte [vscan], 0x4D
    je .right
    jmp .next
.up:
    call vi_up
    jmp .next
.down:
    call vi_down
    jmp .next
.left:
    call vi_left
    jmp .next
.right:
    call vi_right
    jmp .next
.insert:
    mov al, [vch]
    cmp al, 13
    je .ins_nl
    cmp al, 8
    je .ins_bs
    cmp al, 32
    jb .next
    cmp al, 126
    ja .next
    call vi_insert_char
    jmp .next
.ins_nl:
    mov al, 10
    call vi_insert_char
    jmp .next
.ins_bs:
    call vi_backspace
    jmp .next
.command:
    mov al, [vch]
    cmp al, 13
    je .cmd_enter
    cmp al, 8
    je .cmd_bs
    cmp al, 32
    jb .next
    cmp al, 126
    ja .next
    cmp word [vcmdlen], 30
    jae .next
    mov bx, [vcmdlen]
    mov [vcmd + bx], al
    inc word [vcmdlen]
    mov byte [vcmd + bx + 1], 0
    jmp .next
.cmd_bs:
    cmp word [vcmdlen], 0
    je .cmd_cancel
    dec word [vcmdlen]
    mov bx, [vcmdlen]
    mov byte [vcmd + bx], 0
    jmp .next
.cmd_cancel:
    mov byte [vmode], 0
    jmp .next
.cmd_enter:
    call vi_cmd_exec
    jmp .next
.normal:
    mov al, [vch]
    cmp al, 'h'
    je .left
    cmp al, 'l'
    je .right
    cmp al, 'j'
    je .down
    cmp al, 'k'
    je .up
    cmp al, '0'
    je .home
    cmp al, '$'
    je .end
    cmp al, 'i'
    je .ins
    cmp al, 'a'
    je .app
    cmp al, 'o'
    je .open
    cmp al, 'x'
    je .xdel
    cmp al, ':'
    je .colon
    jmp .next
.home:
    mov ax, [vpos]
    call vi_linestart
    mov [vpos], ax
    jmp .next
.end:
    mov ax, [vpos]
    call vi_lineend
    mov [vpos], ax
    jmp .next
.ins:
    mov byte [vmode], 1
    jmp .next
.app:
    call vi_right
    mov byte [vmode], 1
    jmp .next
.open:
    mov ax, [vpos]
    call vi_lineend
    mov [vpos], ax
    mov al, 10
    call vi_insert_char
    mov byte [vmode], 1
    jmp .next
.xdel:
    mov ax, [vpos]
    cmp ax, [vlen]
    jae .next
    mov bx, ax
    cmp byte [VBUF + bx], 10
    je .next
    mov cx, ax
    call vi_delete_at
    jmp .next
.colon:
    mov byte [vmode], 2
    mov word [vcmdlen], 0
    mov byte [vcmd], 0
    jmp .next
.next:
    cmp byte [vquit], 0
    jne .exit
    jmp .loop
.exit:
    mov ax, 0x0003
    int 0x10
    ret
.usage:
    mov si, s_vi_usage
    call puts
    ret

vi_getkey:
    xor ah, ah
    int 0x16
    mov [vch], al
    mov [vscan], ah
    ret

vi_linestart:
    test ax, ax
    jz .r
    dec ax
    mov bx, ax
    cmp byte [VBUF + bx], 10
    jne vi_linestart
    inc ax
.r:
    ret

vi_lineend:
    cmp ax, [vlen]
    jae .r
    mov bx, ax
    cmp byte [VBUF + bx], 10
    je .r
    inc ax
    jmp vi_lineend
.r:
    ret

vi_left:
    cmp word [vpos], 0
    je .r
    dec word [vpos]
.r:
    ret

vi_right:
    mov ax, [vpos]
    cmp ax, [vlen]
    jae .r
    mov bx, ax
    cmp byte [VBUF + bx], 10
    je .r
    inc word [vpos]
.r:
    ret

vi_down:
    mov ax, [vpos]
    call vi_linestart
    mov cx, [vpos]
    sub cx, ax
    mov ax, [vpos]
    call vi_lineend
    cmp ax, [vlen]
    jae .done
    inc ax
    mov [vnext], ax
    call vi_lineend
    mov dx, ax
    mov ax, [vnext]
    add ax, cx
    cmp ax, dx
    jbe .set
    mov ax, dx
.set:
    mov [vpos], ax
.done:
    ret

vi_up:
    mov ax, [vpos]
    call vi_linestart
    test ax, ax
    jz .done
    mov [vnext], ax
    mov cx, [vpos]
    sub cx, ax
    dec ax
    call vi_linestart
    mov dx, [vnext]
    dec dx
    add ax, cx
    cmp ax, dx
    jbe .set
    mov ax, dx
.set:
    mov [vpos], ax
.done:
    ret

vi_insert_char:
    cmp word [vlen], VBUFMAX - 1
    jae .r
    mov bl, al
    mov si, [vlen]
.mv:                            ; gfdesbjdbshbhbhj
    cmp si, [vpos]
    jbe .place
    mov al, [VBUF + si - 1]
    mov [VBUF + si], al
    dec si
    jmp .mv
.place:
    mov si, [vpos]
    mov [VBUF + si], bl
    inc word [vlen]
    inc word [vpos]
    mov byte [vmod], 1
.r:
    ret

vi_delete_at:
    mov si, cx
.m:
    mov ax, si
    inc ax
    cmp ax, [vlen]
    jae .d
    mov al, [VBUF + si + 1]
    mov [VBUF + si], al
    inc si
    jmp .m
.d:
    dec word [vlen]
    mov byte [vmod], 1
    ret

vi_backspace:
    cmp word [vpos], 0
    je .r
    dec word [vpos]
    mov cx, [vpos]
    call vi_delete_at
.r:
    ret

vi_cursor_line:
    xor cx, cx
    xor si, si
.l:
    cmp si, [vpos]
    jae .done
    cmp byte [VBUF + si], 10
    jne .n
    inc cx
.n:
    inc si
    jmp .l
.done:
    mov [vcurline], cx
    mov si, [vpos]
.w:
    test si, si
    jz .col
    dec si
    cmp byte [VBUF + si], 10
    jne .w
    inc si
.col:
    mov ax, [vpos]
    sub ax, si
    mov [vcurcol], ax
    ret

vi_line_index:
    mov si, 0
    mov cx, ax
    test cx, cx
    jz .found
.l:
    cmp si, [vlen]
    jae .none
    cmp byte [VBUF + si], 10
    je .nl
    inc si
    jmp .l
.nl:
    inc si
    dec cx
    jnz .l
.found:
    mov ax, si
    ret
.none:
    mov ax, 0xFFFF
    ret

vi_put_row:
    push ax
    push bx
    push cx
    push di
    push es
    push si
    mov ax, 0xB800
    mov es, ax
    mov di, bx
    mov ax, 160
    imul di, ax
    mov cx, 80
.l:
    mov al, [si]
    mov ah, 0x07
    mov [es:di], ax
    inc si
    add di, 2
    dec cx
    jnz .l
    pop si
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

vi_cpz:
    push ax
    push cx
    xor cx, cx
.l:
    mov al, [si]
    test al, al
    jz .d
    cmp cx, 79
    jae .d
    mov [di], al
    inc di
    inc si
    inc cx
    jmp .l
.d:
    pop cx
    pop ax
    ret

vi_draw:
    call vi_cursor_line
    mov ax, [vcurline]
    cmp ax, [vtop]
    jae .below
    mov [vtop], ax
    jmp .render
.below:
    mov dx, ax
    sub dx, [vtop]
    cmp dx, 23
    jb .render
    mov dx, ax
    sub dx, 23
    mov [vtop], dx
.render:
    xor bx, bx
.rl:
    cmp bx, 24
    jae .status
    mov ax, [vtop]
    add ax, bx
    call vi_line_index
    cmp ax, 0xFFFF
    je .blank
    mov si, ax
    mov di, vrow2
    xor cx, cx
.cp:
    cmp cx, 80
    jae .put
    cmp si, [vlen]
    jae .pad
    mov al, [VBUF + si]
    cmp al, 10
    je .pad
    mov [di], al
    inc di
    inc si
    inc cx
    jmp .cp
.pad:
    cmp cx, 80
    jae .put
    mov byte [di], 32
    inc di
    inc cx
    jmp .pad
.blank:
    mov di, vrow2
    mov cx, 80
    mov al, 32
.fill:
    mov [di], al
    inc di
    dec cx
    jnz .fill
.put:
    mov si, vrow2
    call vi_put_row
    inc bx
    jmp .rl
.status:
    mov di, vrow2
    cmp byte [vmode], 2
    jne .st_norm
    mov byte [di], ':'
    inc di
    mov si, vcmd
    call vi_cpz
    jmp .st_pad
.st_norm:
    mov si, [vmsgp]
    test si, si
    jnz .st_copy
    mov si, s_vi_normal
    cmp byte [vmode], 1
    jne .st_copy
    mov si, s_vi_insert
.st_copy:
    call vi_cpz
.st_pad:
    mov ax, di
    sub ax, vrow2
    mov cx, 80
    sub cx, ax
.pad2:
    test cx, cx
    jz .st_put
    mov byte [di], 32
    inc di
    dec cx
    jmp .pad2
.st_put:
    mov bx, 24
    mov si, vrow2
    call vi_put_row
    cmp byte [vmode], 2
    jne .cur_text
    mov ax, [vcmdlen]
    inc ax
    cmp ax, 79
    jb .cmd_col
    mov ax, 79
.cmd_col:
    mov dl, al
    mov dh, 24
    jmp .set_cur
.cur_text:
    mov ax, [vcurcol]
    cmp ax, 79
    jb .col_ok
    mov ax, 79
.col_ok:
    mov dl, al
    mov ax, [vcurline]
    sub ax, [vtop]
    mov dh, al
.set_cur:
    xor bh, bh
    mov ah, 2
    int 0x10
    ret

vi_streq:
.l:
    mov al, [si]
    cmp al, [di]
    jne .n
    test al, al
    jz .y
    inc si
    inc di
    jmp .l
.y:
    mov al, 1
    ret
.n:
    xor al, al
    ret

vi_cmd_exec:
    mov byte [vmode], 0
    mov si, vcmd
    mov di, s_cw
    call vi_streq
    test al, al
    jnz .save
    mov si, vcmd
    mov di, s_cwq
    call vi_streq
    test al, al
    jnz .savequit
    mov si, vcmd
    mov di, s_cq
    call vi_streq
    test al, al
    jnz .quit
    mov si, vcmd
    mov di, s_cqb
    call vi_streq
    test al, al
    jnz .force
    mov word [vmsgp], s_badcmd
    ret
.save:
    call vi_save
    ret
.savequit:
    call vi_save
    mov byte [vquit], 1
    ret
.quit:
    cmp byte [vmod], 0
    jne .warn
.force:
    mov byte [vquit], 1
    ret
.warn:
    mov word [vmsgp], s_modwarn
    ret

fat_next:
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov di, ax
    mov dx, ax
    shr ax, 1
    add ax, dx
    xor dx, dx
    mov cx, 512
    div cx
    mov [vi_fat_off], dx
    inc ax
    mov bx, SCR_OFF
    mov dx, KSEG
    mov es, dx
    call read_sector
    inc ax
    add bx, 512
    call read_sector
    mov si, [vi_fat_off]
    add si, SCR_OFF
    mov ax, [si]
    test di, 1
    jz .even
    shr ax, 4
    jmp .out
.even:
    and ax, 0x0FFF
.out:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

fat_set:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov [vi_fat_cl], ax
    mov [vi_fat_val], bx
    mov dx, ax
    shr ax, 1
    add ax, dx
    xor dx, dx
    mov cx, 512
    div cx
    mov [vi_fat_off], dx
    inc ax
    mov [vi_lba], ax
    mov bx, SCR_OFF
    mov dx, KSEG
    mov es, dx
    call read_sector
    mov si, [vi_fat_off]
    add si, SCR_OFF
    mov ax, [si]
    mov dx, [vi_fat_cl]
    test dx, 1
    jz .even
    and ax, 0x000F              ; mreow
    mov dx, [vi_fat_val]
    shl dx, 4
    or ax, dx
    jmp .store
.even:
    and ax, 0xF000
    mov dx, [vi_fat_val]
    and dx, 0x0FFF
    or ax, dx
.store:
    mov [si], ax
    mov ax, [vi_lba]
    mov bx, SCR_OFF
    mov dx, KSEG
    mov es, dx
    call write_sector
    mov ax, [vi_lba]
    add ax, 9
    call write_sector
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

vi_alloc:
    mov cx, 2
.loop:
    mov ax, cx
    push cx
    call fat_next
    pop cx
    test ax, ax
    jz .found
    inc cx
    cmp cx, 2848
    jb .loop
    xor ax, ax
    ret
.found:
    mov ax, cx
    mov bx, 0x0FFF
    push cx
    call fat_set
    pop ax
    ret

vi_free_chain:
    cmp ax, 2
    jb .done
    cmp ax, 0xFF8
    jae .done
    mov [vi_cur], ax
    call fat_next
    mov [vi_tmp], ax
    mov ax, [vi_cur]
    xor bx, bx
    call fat_set
    mov ax, [vi_tmp]
    jmp vi_free_chain
.done:
    ret

vi_find:
    mov byte [vi_found], 0
    call build_name
    call load_root
    mov si, SCR_OFF
    mov cx, ROOT_ENT
.scan:
    mov al, [si]
    test al, al
    jz .nf
    xor bx, bx
.cmp:
    mov al, [si + bx]
    cmp al, [name83 + bx]
    jne .next
    inc bx
    cmp bx, 11
    jne .cmp
    jmp .found
.next:
    add si, 32
    dec cx
    jnz .scan
.nf:
    ret
.found:
    mov ax, si
    sub ax, SCR_OFF
    mov [vi_entry_off], ax
    mov ax, [si + 26]
    mov [vi_first], ax
    mov ax, [si + 28]
    mov [vi_size], ax
    mov di, ventry
    mov cx, 32
.cp:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    dec cx
    jnz .cp
    mov byte [vi_found], 1
    ret

vi_find_free:
    call load_root
    mov si, SCR_OFF
    mov cx, ROOT_ENT
.scan:
    mov al, [si]
    test al, al
    jz .found
    cmp al, 0xE5
    je .found
    add si, 32
    dec cx
    jnz .scan
    xor ax, ax
    ret
.found:
    mov ax, si
    sub ax, SCR_OFF
    mov [vi_entry_off], ax
    mov di, ventry
    mov cx, 32
    xor al, al
.fill:
    mov [di], al
    inc di
    dec cx
    jnz .fill
    mov si, name83
    mov di, ventry
    mov cx, 11
.cp:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    dec cx
    jnz .cp
    mov byte [ventry + 11], 0x20
    mov ax, 1
    ret

vi_write_entry:
    mov ax, [vi_entry_off]
    xor dx, dx
    mov cx, 512
    div cx
    mov [vi_within], dx
    add ax, ROOT_LBA
    mov [vi_lba], ax
    mov bx, SCR_OFF
    mov dx, KSEG
    mov es, dx
    call read_sector
    mov si, ventry
    mov di, SCR_OFF
    add di, [vi_within]
    mov cx, 16
    cld
    rep movsw
    mov ax, [vi_lba]
    mov bx, SCR_OFF
    mov dx, KSEG
    mov es, dx
    call write_sector
    ret

vi_load:
    mov word [vlen], 0
    call vi_find
    cmp byte [vi_found], 0
    je .done
    mov word [vi_off], 0
    mov ax, [vi_first]
.rd:
    cmp ax, 2
    jb .fin
    cmp ax, 0xFF8
    jae .fin
    mov [vi_cur], ax
    add ax, 31
    mov bx, SCR_OFF
    mov dx, KSEG
    mov es, dx
    call read_sector
    mov ax, [vi_size]
    sub ax, [vi_off]
    jbe .fin
    cmp ax, 512
    jbe .n1
    mov ax, 512
.n1:
    mov cx, VBUFMAX
    sub cx, [vi_off]
    cmp ax, cx
    jbe .n2
    mov ax, cx
.n2:
    mov bx, ax
    mov cx, bx
    mov si, SCR_OFF
    mov di, [vi_off]
    add di, VBUF
    cld
    rep movsb
    add [vi_off], bx
    mov ax, [vi_cur]
    call fat_next
    jmp .rd
.fin:
    mov ax, [vi_off]
    mov [vlen], ax
.done:
    ret

vi_save:
    call vi_find
    cmp byte [vi_found], 0
    jne .have
    call vi_find_free
    test ax, ax
    jz .fail
.have:
    cmp byte [vi_found], 0
    je .noold
    mov ax, [vi_first]
    call vi_free_chain
.noold:
    mov word [vi_newfirst], 0
    mov word [vi_prev], 0
    mov word [vi_off], 0
.wloop:
    mov ax, [vi_off]
    cmp ax, [vlen]
    jae .wdone
    call vi_alloc
    test ax, ax
    jz .fail
    mov [vi_cur], ax
    cmp word [vi_newfirst], 0
    jne .link
    mov [vi_newfirst], ax
    jmp .wr
.link:
    mov ax, [vi_prev]
    mov bx, [vi_cur]
    call fat_set
.wr:
    mov di, SCR_OFF
    mov cx, 512
    xor al, al
    mov dx, KSEG
    mov es, dx
    cld
    rep stosb
    mov si, [vi_off]
    add si, VBUF
    mov ax, [vlen]
    sub ax, [vi_off]
    cmp ax, 512
    jbe .n
    mov ax, 512
.n:
    mov bx, ax
    mov cx, bx
    mov di, SCR_OFF
    rep movsb
    mov ax, [vi_cur]
    add ax, 31
    mov bx, SCR_OFF
    mov dx, KSEG
    mov es, dx
    call write_sector
    mov ax, [vi_cur]
    mov [vi_prev], ax
    add word [vi_off], 512
    jmp .wloop
.wdone:
    mov ax, [vi_newfirst]
    mov [ventry + 26], ax
    mov ax, [vlen]
    mov [ventry + 28], ax
    mov word [ventry + 30], 0
    call vi_write_entry
    mov byte [vmod], 0
    mov word [vmsgp], s_saved
    ret
.fail:
    mov word [vmsgp], s_savefail
    ret

s_vi_usage  db 'usage: vi FILE',13,10,0
s_vi_normal db '-- NORMAL --  :w save  :q quit  :wq save+quit',0
s_vi_insert db '-- INSERT --  esc to leave',0
s_saved     db 'written',0
s_savefail  db 'write failed',0
s_modwarn   db 'unsaved changes (:q! to discard)',0
s_badcmd    db 'not an editor command',0
s_cw        db 'w',0
s_cwq       db 'wq',0
s_cq        db 'q',0
s_cqb       db 'q!',0

vmode        db 0
vmod         db 0
vquit        db 0
vlen         dw 0
vpos         dw 0
vtop         dw 0
vmsgp        dw 0
vcmd         times 32 db 0
vcmdlen      dw 0
vname        times 16 db 0
vcurline     dw 0
vcurcol      dw 0
vr           dw 0
vnext        dw 0
vch          db 0
vscan        db 0
vrow2        times 80 db 32
vi_found     db 0
vi_entry_off dw 0
vi_first     dw 0
vi_size      dw 0
vi_off       dw 0
vi_cur       dw 0
vi_prev      dw 0
vi_newfirst  dw 0
vi_within    dw 0
vi_lba       dw 0
vi_fat_off   dw 0
vi_fat_cl    dw 0
vi_fat_val   dw 0
vi_tmp       dw 0
ventry       times 32 db 0

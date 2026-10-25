bits 16
org 0

KSEG        equ 0x1000
SELF_SEG    equ KSEG
%include "bios/defs.inc"

start:
    cli
    mov ax, KSEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    mov [drive], dl

    mov ax, 0x0003
    int 0x10

    mov si, s_banner
    call puts
    call init_cwd

.main:
    mov si, s_prompt
    call puts
    mov si, cwd_path
    call puts
    mov si, s_prompt2
    call puts
    call readline
    call dispatch
    jmp .main

readline:
    mov ax, KSEG
    mov es, ax
    mov di, linebuf
    xor cx, cx
.loop:
    xor ah, ah
    int 0x16
    cmp al, 13
    je .enter
    cmp al, 8
    je .bs
    cmp al, 32
    jb .loop
    cmp cx, MAXLINE - 1
    jae .loop
    stosb
    inc cx
    call putc
    jmp .loop
.bs:
    test cx, cx
    jz .loop
    dec cx
    dec di
    mov al, 8
    call putc
    mov al, ' '
    call putc
    mov al, 8
    call putc
    jmp .loop
.enter:
    mov al, 0
    stosb
    call newline
    ret

dispatch:
    cmp byte [linebuf], 0
    je .ret
.restart:
    mov word [argp], 0
    mov si, linebuf
.find:
    mov al, [si]
    test al, al
    jz .go
    cmp al, ' '
    je .space
    inc si
    jmp .find
.space:
    mov byte [si], 0
    inc si
    mov [argp], si
.go:
    mov si, linebuf
    mov di, s_rodo_name
    call strcmp
    test al, al
    jz .external
    cmp byte [root_mode], 0
    jne .rodo_root
    mov si, [argp]
    test si, si
    jz .rodo_use
    mov di, linebuf
.mv:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .mv
    mov byte [root_mode], 1
    jmp .restart
.rodo_root:
    mov si, s_rodo_root
    call puts
    ret
.rodo_use:
    mov si, s_rodo_use
    call puts
    ret
.external:
    call run_external
    test ax, ax
    jnz .out
    mov si, s_unknown
    call puts
.out:
    mov byte [root_mode], 0
.ret:
    ret

run_external:
    mov di, extpath
    mov si, s_bin_a
.cpbin:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .cpbin
    dec di

    mov si, linebuf
    xor cx, cx
.cpname:
    mov al, [si]
    test al, al
    jz .ext
    cmp al, ' '
    je .ext
    cmp al, 'a'
    jb .up
    cmp al, 'z'
    ja .up
    sub al, 32
.up:
    cmp cx, 8
    jae .skip
    mov [di], al
    inc di
    inc cx
.skip:
    inc si
    jmp .cpname
.ext:
    mov si, s_bin_ext
.cpext:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .cpext

    mov si, extpath
    call resolve
    cmp byte [res_err], 0
    jne .notfound
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .notfound
    test byte [res_attr], 0x10
    jnz .notfound
    mov eax, [res_size]
    test eax, eax
    jz .bad
    cmp eax, 0xE000
    jae .bad
    cmp eax, 16
    jb .bad

    mov ax, PROG_SEG
    mov es, ax

    xor di, di
    xor ax, ax
    mov cx, 0x7F00
    rep stosw
    xor bx, bx
    mov ax, [res_first]
    mov [load_cl], ax
.rd:
    mov ax, [load_cl]
    cmp ax, 2
    jb .loaded
    cmp ax, 0xFF8
    jae .loaded
    add ax, DATA_LBA - 2
    call read_sector
    add bx, 512
    mov ax, [load_cl]
    call fat_next
    mov [load_cl], ax
    jmp .rd

.loaded:
    mov ax, PROG_SEG
    mov es, ax
    mov al, [drive]
    mov [es:STATE_DRIVE], al
    mov al, [root_mode]
    mov [es:STATE_ROOT], al
    mov ax, [cwd_cluster]
    mov [es:STATE_CWDC], ax

    mov si, cwd_path
    mov di, STATE_CWDP
    mov cx, 64
.cpcwd:
    mov al, [si]
    mov [es:di], al
    inc si
    inc di
    test al, al
    jz .args
    dec cx
    jnz .cpcwd
    mov byte [es:di-1], 0

.args:
    mov si, [argp]
    test si, si
    jnz .haveargs
    mov si, empty
.haveargs:
    mov di, STATE_ARGS
    mov cx, STATE_ARGS_MAX
.cpargs:
    mov al, [si]
    mov [es:di], al
    inc si
    inc di
    test al, al
    jz .run
    dec cx
    jnz .cpargs
    mov byte [es:di-1], 0

.run:
    mov [k_ss], ss
    mov [k_sp], sp
    mov [k_ds], ds
    mov [k_es], es
    cli
    mov ax, PROG_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFF00
    cld
    sti
    call 0x2000:0x0000
    cli
    mov ax, cs
    mov ds, ax
    mov ss, [k_ss]
    mov sp, [k_sp]
    mov ax, [k_es]
    mov es, ax
    sti

    mov ax, PROG_SEG
    mov es, ax
    mov al, [es:STATE_DRIVE]
    mov [drive], al
    mov al, [es:STATE_ROOT]
    mov [root_mode], al
    mov ax, [es:STATE_CWDC]
    mov [cwd_cluster], ax

    mov si, STATE_CWDP
    mov di, cwd_path
    mov cx, 64
.cpcwd2:
    mov al, [es:si]
    mov [di], al
    inc si
    inc di
    test al, al
    jz .sync
    dec cx
    jnz .cpcwd2
    mov byte [di-1], 0
.sync:
    mov ax, [cwd_cluster]
    call dir_load
    mov ax, 1
    ret

.bad:
    mov si, s_badexec
    call puts
    mov ax, 1
    ret
.notfound:
    xor ax, ax
    ret

strcmp:
.l:
    mov al, [si]
    test al, al
    jz .end
    mov ah, [di]
    cmp al, ah
    jne .no
    inc si
    inc di
    jmp .l
.end:
    cmp byte [di], 0
    jne .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

putc:
    push ax
    push bx
    push cx
    push dx
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret

puts:
    push ax
    push si
.l:
    lodsb
    test al, al
    jz .d
    call putc
    jmp .l
.d:
    pop si
    pop ax
    ret

print_dec:
    pusha
    xor cx, cx
    mov bx, 10
.d:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .d
.p:
    pop ax
    add al, '0'
    call putc
    loop .p
    popa
    ret

newline:
    mov al, 13
    call putc
    mov al, 10
    call putc
    ret

read_sector:
    push ax
    push bx
    push cx
    push dx
    push di
    mov di, ax
    xor dx, dx
    mov cx, 36
    div cx
    mov ch, al
    mov ax, dx
    xor dx, dx
    mov cl, 18
    div cl
    mov dh, al
    mov cl, ah
    inc cl
    mov dl, [drive]
    mov ax, 0x0201
    int 0x13
    jc disk_error
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

write_sector:
    push ax
    push bx
    push cx
    push dx
    push di
    mov di, ax
    xor dx, dx
    mov cx, 36
    div cx
    mov ch, al
    mov ax, dx
    xor dx, dx
    mov cl, 18
    div cl
    mov dh, al
    mov cl, ah
    inc cl
    mov dl, [drive]
    mov ax, 0x0301
    int 0x13
    jc disk_error
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

disk_error:
    mov si, s_disk
    call puts
.h:
    cli
    hlt
    jmp .h

set_es_k:
    push ax
    mov ax, KSEG
    mov es, ax
    pop ax
    ret

name_blank:
    mov di, name83
    mov cx, 11
    mov al, ' '
.fill:
    mov [di], al
    inc di
    dec cx
    jnz .fill
    ret

name_is_blank:
    mov si, name83
    mov cx, 11
.l:
    cmp byte [si], ' '
    jne .no
    inc si
    dec cx
    jnz .l
    mov al, 1
    ret
.no:
    xor al, al
    ret

build_name:
    push es
    push si
    call set_es_k
    mov di, name83
    mov cx, 11
    mov al, ' '
    rep stosb
    pop si
    mov di, name83
    xor bx, bx
.base:
    mov al, [si]
    test al, al
    jz .done
    cmp al, '.'
    je .ext
    cmp al, 'a'
    jb .store
    cmp al, 'z'
    ja .store
    sub al, 32
.store:
    cmp bx, 8
    jae .bskip
    mov [di + bx], al
    inc bx
.bskip:
    inc si
    jmp .base
.ext:
    inc si
    xor bx, bx
.extloop:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 'a'
    jb .estore
    cmp al, 'z'
    ja .estore
    sub al, 32
.estore:
    cmp bx, 3
    jae .eskip
    mov [di + 8 + bx], al
    inc bx
.eskip:
    inc si
    jmp .extloop
.done:
    pop es
    ret

entry_init:
    push es
    call set_es_k
    mov di, ventry
    mov cx, 32
    xor al, al
.z:
    mov [di], al
    inc di
    dec cx
    jnz .z
    mov si, name83
    mov di, ventry
    mov cx, 11
    rep movsb
    mov byte [ventry + 11], 0x20
    pop es
    ret

is_dot:
    cmp byte [si], '.'
    jne .no
    cmp byte [si + 1], ' '
    je .yes
    cmp byte [si + 1], '.'
    jne .no
    cmp byte [si + 2], ' '
    jne .no
.yes:
    mov al, 1
    ret
.no:
    xor al, al
    ret

strcpy:
.l:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .l
    ret

resolve:
    mov [path_in], si
    mov byte [res_err], 0
    mov byte [pathbuf], 0
    mov word [pb_end], pathbuf
    mov al, [si]
    cmp al, '/'
    je .abs
    cmp al, '\'
    je .abs
    mov ax, [cwd_cluster]
    mov [cur_cl], ax
    mov si, cwd_path
    mov di, pathbuf
.cp_cwd:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .cp_cwd
    dec di
    mov [pb_end], di
    jmp .next
.abs:
    mov word [cur_cl], 0
    mov byte [pathbuf], '\'
    mov byte [pathbuf + 1], 0
    mov word [pb_end], pathbuf + 1

.next:
    mov si, [path_in]
.sk:
    mov al, [si]
    test al, al
    jz .endpath
    cmp al, '/'
    je .sk2
    cmp al, '\'
    jne .start
.sk2:
    inc si
    jmp .sk
.start:
    mov [comp_ptr], si
    mov di, si
.ce:
    mov al, [di]
    test al, al
    jz .ce_done
    cmp al, '/'
    je .ce_done
    cmp al, '\'
    je .ce_done
    inc di
    jmp .ce
.ce_done:
    mov [next_ptr], di
    mov bx, di
    sub bx, si
    mov cx, bx
    cmp cx, 15
    jbe .lenok
    mov cx, 15
.lenok:
    mov bx, si
    mov di, compbuf
.cpcomp:
    test cx, cx
    jz .cpdone
    mov al, [bx]
    mov [di], al
    inc bx
    inc di
    dec cx
    jmp .cpcomp
.cpdone:
    mov byte [di], 0
    mov bx, [next_ptr]
    cmp byte [bx], '/'
    je .advance
    cmp byte [bx], '\'
    jne .noadv
.advance:
    inc word [next_ptr]
.noadv:
    mov word [comp_ptr], compbuf
    jmp .checklast

.endpath:
    mov ax, [cur_cl]
    mov [res_dir], ax
    call name_blank
    ret

.checklast:
    mov bx, [next_ptr]
.look:
    mov al, [bx]
    cmp al, '/'
    je .lookskip
    cmp al, '\'
    jne .lookdone
.lookskip:
    inc bx
    jmp .look
.lookdone:
    cmp byte [bx], 0
    je .is_last
    jmp .not_last

.is_last:
    mov si, [comp_ptr]
    cmp byte [si], '.'
    jne .last_norm
    cmp byte [si + 1], 0
    jne .last_dotdot
    mov ax, [cur_cl]
    mov [res_dir], ax
    call name_blank
    ret
.last_dotdot:
    cmp byte [si + 1], '.'
    jne .last_norm
    cmp byte [si + 2], 0
    jne .last_norm
    mov ax, [cur_cl]
    call dir_up
    mov [res_dir], ax
    call pb_up
    call name_blank
    ret
.last_norm:
    mov ax, [cur_cl]
    mov [res_dir], ax
    mov si, [comp_ptr]
    call append_comp
    mov si, [comp_ptr]
    call build_name
    ret

.not_last:
    mov si, [comp_ptr]
    cmp byte [si], '.'
    jne .nl_norm
    cmp byte [si + 1], 0
    jne .nl_dotdot
    mov si, [next_ptr]
    mov [path_in], si
    jmp .next
.nl_dotdot:
    cmp byte [si + 1], '.'
    jne .nl_norm
    cmp byte [si + 2], 0
    jne .nl_norm
    mov ax, [cur_cl]
    call dir_up
    mov [cur_cl], ax
    call pb_up
    mov si, [next_ptr]
    mov [path_in], si
    jmp .next
.nl_norm:
    mov ax, [cur_cl]
    call dir_load
    mov si, [comp_ptr]
    call build_name
    call dir_find
    test al, al
    jz .err_nf
    test byte [res_attr], 0x10
    jz .err_nd
    mov ax, [res_first]
    mov [cur_cl], ax
    mov si, [comp_ptr]
    call append_comp
    mov si, [next_ptr]
    mov [path_in], si
    jmp .next
.err_nf:
    mov byte [res_err], 1
    mov ax, [cur_cl]
    mov [res_dir], ax
    call name_blank
    ret
.err_nd:
    mov byte [res_err], 2
    mov ax, [cur_cl]
    mov [res_dir], ax
    call name_blank
    ret

append_comp:
    mov di, [pb_end]
    cmp di, pathbuf
    je .n
    cmp byte [di - 1], '\'
    je .n
    mov byte [di], '\'
    inc di
.n:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 'A'
    jb .put
    cmp al, 'Z'
    ja .put
    add al, 32
.put:
    cmp di, pathbuf + 60
    jae .skip
    mov [di], al
    inc di
.skip:
    inc si
    jmp .n
.done:
    mov byte [di], 0
    mov [pb_end], di
    ret

pb_up:
    mov di, [pb_end]
    cmp di, pathbuf + 1
    jbe .root
    dec di
.scan:
    cmp di, pathbuf
    jbe .root
    cmp byte [di], '\'
    je .cut
    dec di
    jmp .scan
.cut:
    mov byte [di], 0
    mov [pb_end], di
    ret
.root:
    mov byte [pathbuf], '\'
    mov byte [pathbuf + 1], 0
    mov word [pb_end], pathbuf + 1
    ret

dir_load:
    mov [dir_cluster], ax
    cmp ax, 0
    jne .sub
    mov word [dir_ns], ROOT_SECT
    xor di, di
    xor si, si
    mov cx, ROOT_SECT
    mov ax, ROOT_LBA
.rl:
    mov [dir_lba + si], ax
    mov bx, di
    add bx, dirbuf
    mov dx, KSEG
    mov es, dx
    call read_sector
    inc ax
    add di, 512
    add si, 2
    loop .rl
    ret
.sub:
    xor di, di
    xor si, si
    mov cx, DIRMAX
.cl:
    cmp ax, 2
    jb .done
    cmp ax, 0xFF8
    jae .done
    mov [tmp_cl], ax
    add ax, 31
    mov [dir_lba + si], ax
    mov bx, di
    add bx, dirbuf
    mov dx, KSEG
    mov es, dx
    call read_sector
    mov ax, [tmp_cl]
    call fat_next
    add di, 512
    add si, 2
    dec cx
    jnz .cl
.done:
    shr si, 1
    mov [dir_ns], si
    ret

dir_find:
    mov si, dirbuf
    mov cx, [dir_ns]
    shl cx, 4
.scan:
    mov al, [si]
    test al, al
    jz .nf
    cmp al, 0xE5
    je .next
    cmp byte [si + 11], 0x0F
    je .next
    test byte [si + 11], 0x08
    jnz .next
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
    xor al, al
    ret
.found:
    mov ax, si
    sub ax, dirbuf
    mov [res_off], ax
    mov ax, [si + 26]
    mov [res_first], ax
    mov ax, [si + 28]
    mov [res_size], ax
    mov ax, [si + 30]
    mov [res_size + 2], ax
    mov al, [si + 11]
    mov [res_attr], al
    mov al, 1
    ret

dir_up:
    cmp ax, 0
    jne .sub
    xor ax, ax
    ret
.sub:
    add ax, 31
    xor bx, bx
    mov dx, SCR_SEG
    mov es, dx
    call read_sector
    mov bx, SCR_OFF + 32 + 26
    mov ax, [es:bx]
    cmp ax, 2
    jae .ok
    xor ax, ax
.ok:
    ret

init_cwd:
    mov si, s_home_a
    call resolve
    cmp byte [res_err], 0
    jne .done
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .done
    test byte [res_attr], 0x10
    jz .done
    mov ax, [res_first]
    mov [cwd_cluster], ax
    mov si, pathbuf
    mov di, cwd_path
    call strcpy
    call dir_load
.done:
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
    mov dx, SCR_SEG
    mov es, dx
    call read_sector
    inc ax
    add bx, 512
    call read_sector
    mov dx, SCR_SEG
    mov es, dx
    mov si, [vi_fat_off]
    add si, SCR_OFF
    mov ax, [es:si]
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

section .data

s_banner    db `\r\n  adachiOS 0.5 - a tiny os :3 (bios build)\r\n  type 'help' if you are lost\r\n\r\n`,0
s_prompt    db `:3 adachiOS:`,0
s_prompt2   db `> `,0
s_unknown   db `adachiOS: command not found (rude)\r\n`,0
s_rodo_name db `rodo`,0
s_rodo_use  db `usage: rodo CMD   (you start with only /home, rodo is root)\r\n`,0
s_rodo_root db `rodo: you are already root for this command\r\n`,0
s_bin_a     db '\bin\',0
s_bin_ext   db `.BIN`,0
s_badexec   db `adachiOS: /bin program is not a valid binary\r\n`,0
s_home_a    db 0x5C,'home',0
s_disk      db `adachiOS: disk read error\r\n`,0
empty       db 0

drive       db 0
argp        dw 0
root_mode   db 0
cwd_path    times 64 db 0
cwd_cluster dw 0

pathbuf     times 64 db 0
path_in     dw 0
pb_end      dw 0
cur_cl      dw 0
res_dir     dw 0
res_off     dw 0
res_first   dw 0
res_size    dd 0
res_attr    db 0
res_err     db 0
comp_ptr    dw 0
next_ptr    dw 0
compbuf     times 16 db 0
name83      times 11 db ' '
ventry      times 32 db 0
dir_cluster dw 0
dir_ns      dw 0
dir_lba     times DIRMAX dw 0
dirbuf      times (ROOT_SECT * 512) db 0
tmp_cl      dw 0
vi_fat_off  dw 0
vi_lba      dw 0
load_cl     dw 0
k_ss        dw 0
k_sp        dw 0
k_ds        dw 0
k_es        dw 0
extpath     times 80 db 0
linebuf     times MAXLINE db 0

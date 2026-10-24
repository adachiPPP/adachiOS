bits 16
org 0x0000

KSEG        equ 0x1000
SCR_SEG     equ 0x1C00
SCR_OFF     equ 0xC000
ROOT_LBA    equ 19
ROOT_SECT   equ 14
ROOT_ENT    equ 224
DATA_LBA    equ 33
MAXLINE     equ 96
DIRMAX      equ 14

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
    mov di, s_sudo_name
    call strcmp
    test al, al
    jz .lookup
    cmp byte [root_mode], 0
    jne .sudo_root
    mov si, [argp]
    test si, si
    jz .sudo_use
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
.sudo_root:
    mov si, s_sudo_root
    call puts
    ret
.sudo_use:
    mov si, s_sudo_use
    call puts
    ret
.lookup:
    mov bx, cmdtab
.try:
    mov si, [bx]
    test si, si
    jz .unknown
    mov di, linebuf
    call strcmp
    test al, al
    jnz .found
    add bx, 4
    jmp .try
.found:
    call word [bx + 2]
    mov byte [root_mode], 0
.ret:
    ret
.unknown:
    mov si, s_unknown
    call puts
    mov byte [root_mode], 0
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





cmd_help:
    mov si, s_help
    call puts
    ret

cmd_echo:
    mov si, [argp]
    test si, si
    jz .nl
    call puts
.nl:
    call newline
    ret

cmd_clear:
    mov ax, 0x0003
    int 0x10
    ret

cmd_fetch:
    call cpu_probe
    mov si, s_f_head
    call puts
    mov si, s_f_cpu
    call puts
    mov si, cpu_name
    call puts
    call newline
    mov si, s_f_cores
    call puts
    mov ax, [cpu_cores]
    call print_dec
    call newline
    mov si, s_f_threads
    call puts
    mov ax, [cpu_threads]
    call print_dec
    call newline
    mov si, s_f_arch
    call puts
    call mem_probe
    mov si, s_f_mem
    call puts
    mov ax, [mem_mib]
    call print_dec
    mov si, s_f_mib
    call puts
    mov si, s_f_low
    call puts
    mov ax, [mem_lo]
    call print_dec
    mov si, s_f_kib
    call puts
    mov si, s_f_boot
    call puts
    mov al, [drive]
    add al, '0'
    call putc
    call newline
    ret

mem_probe:
    int 0x12
    mov [mem_lo], ax
    mov word [mem_kb], ax
    mov word [mem_kb + 2], 0
    mov ax, 0xE801
    int 0x15
    jc .fallback
    add word [mem_kb], ax
    adc word [mem_kb + 2], 0
    mov ax, bx
    xor dx, dx
    mov cx, 6
.shift:                         ; this KILLED me
    shl ax, 1
    rcl dx, 1
    loop .shift
    add word [mem_kb], ax
    adc word [mem_kb + 2], dx
    jmp .calc
.fallback:
    mov ax, 0x88
    int 0x15
    jc .calc
    add word [mem_kb], ax
    adc word [mem_kb + 2], 0
.calc:
    mov ax, [mem_kb]
    mov dx, [mem_kb + 2]
    mov cx, 10
.shr:
    shr dx, 1
    rcr ax, 1
    loop .shr
    mov [mem_mib], ax
    ret

cmd_uname:
    mov si, s_uname
    call puts
    ret

cmd_meow:
    mov si, s_meow
    call puts
    ret

cmd_reboot:
    mov al, 0xFE
    out 0x64, al
    jmp 0xFFFF:0x0000

; ---- network support (BIOS) ----

section .data

s_net_head      db `  adachiOS net`,13,10,0
s_net_no_dev    db `net: no network device attached`,13,10,0
s_nl            db 13,10,0

section .bss

np_dev           resw 1
net_mac          resb 6
ping_host         resb 16
stdout           resw 1

section .text

cmd_poweroff:
    mov ax, 0x5301
    xor bx, bx
    int 0x15
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    mov ax, 0x2000
    mov dx, 0x0604
    out dx, ax
    mov dx, 0xB004
    out dx, ax
    mov si, s_off
    call puts
.h:
    cli
    hlt
    jmp .h

; ---------------------------------------------------------------------------
; tiny FAT12 layer: every path resolves against [cwd_cluster]
; ---------------------------------------------------------------------------

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

; --- path resolution -------------------------------------------------------

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

; --- directory buffers -----------------------------------------------------

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

dir_find_free:
    mov si, dirbuf
    mov cx, [dir_ns]
    shl cx, 4
.scan:
    mov al, [si]
    test al, al
    jz .found
    cmp al, 0xE5
    je .found
    add si, 32
    dec cx
    jnz .scan
    call dir_grow
    test ax, ax
    jz .fail
    mov si, [dir_new_off]
.found:
    mov ax, si
    sub ax, dirbuf
    mov [res_off], ax
    mov al, 1
    ret
.fail:
    xor al, al
    ret

dir_grow:
    mov ax, [dir_cluster]
    test ax, ax
    jz .fail
    mov cx, 40
.last:
    mov [tmp_cl], ax
    call fat_next
    cmp ax, 2
    jb .fail
    cmp ax, 0xFF8
    jae .append
    dec cx
    jnz .last
    jmp .fail
.append:
    call vi_alloc
    test ax, ax
    jz .fail
    mov [tmp_new], ax
    mov bx, ax
    mov ax, [tmp_cl]
    call fat_set
    mov ax, [dir_ns]
    cmp ax, DIRMAX
    jae .fail
    mov bx, ax
    shl bx, 9
    add bx, dirbuf
    mov di, bx
    mov cx, 512
    xor al, al
.zero:
    mov [di], al
    inc di
    dec cx
    jnz .zero
    mov bx, [dir_ns]
    shl bx, 1
    mov ax, [tmp_new]
    add ax, 31
    mov [dir_lba + bx], ax
    mov [tmp_lba], ax
    mov bx, [dir_ns]
    shl bx, 9
    add bx, dirbuf
    mov dx, KSEG
    mov es, dx
    mov ax, [tmp_lba]
    call write_sector
    inc word [dir_ns]
    mov ax, [dir_ns]
    dec ax
    shl ax, 9
    add ax, dirbuf
    mov [dir_new_off], ax
    mov ax, 1
    ret
.fail:
    xor ax, ax
    ret

dir_write_entry:
    mov di, [res_off]
    add di, dirbuf
    mov si, ventry
    mov cx, 32
.mem:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    dec cx
    jnz .mem
    mov ax, [res_off]
    mov bx, ax
    shr bx, 9
    shl bx, 1
    mov ax, [dir_lba + bx]
    mov [tmp_lba], ax
    mov bx, SCR_OFF
    mov dx, SCR_SEG
    mov es, dx
    call read_sector
    mov di, [res_off]
    and di, 0x1FF
    add di, SCR_OFF
    mov si, ventry
    mov cx, 16
    rep movsw
    mov ax, [tmp_lba]
    mov bx, SCR_OFF
    mov dx, SCR_SEG
    mov es, dx
    call write_sector
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
    mov ax, [SCR_OFF + 32 + 26]
    cmp ax, 2
    jae .ok
    xor ax, ax
.ok:
    ret

dir_empty:
    mov ax, [res_first]
.next:
    cmp ax, 2
    jb .yes
    cmp ax, 0xFF8
    jae .yes
    mov [tmp_cl], ax
    add ax, 31
    xor bx, bx
    mov dx, SCR_SEG
    mov es, dx
    call read_sector
    mov si, SCR_OFF
    mov cx, 16
.scan:
    mov al, [si]
    test al, al
    jz .yes
    cmp al, 0xE5
    je .nextent
    cmp byte [si + 11], 0x0F
    je .nextent
    call is_dot
    test al, al
    jnz .nextent
    xor al, al
    ret
.nextent:
    add si, 32
    dec cx
    jnz .scan
    mov ax, [tmp_cl]
    call fat_next
    jmp .next
.yes:
    mov al, 1
    ret

; --- permissions -----------------------------------------------------------

path_can_write:
    cmp byte [root_mode], 0
    jne .yes
    mov si, pathbuf
    mov di, s_home_a
.l:
    mov al, [di]
    test al, al
    jz .pref
    cmp al, [si]
    jne .no
    inc di
    inc si
    jmp .l
.pref:
    mov al, [si]
    test al, al
    jz .yes
    cmp al, '\'
    je .yes
.no:
    xor al, al
    ret
.yes:
    mov al, 1
    ret

need_write:
    call path_can_write
    test al, al
    jnz .ok
    mov si, s_denied
    call puts
    xor al, al
    ret
.ok:
    mov al, 1
    ret


split_args:
    mov word [arg1], 0
    mov word [arg2], 0
    mov si, [argp]
    test si, si
    jz .ret
    cmp byte [si], 0
    je .ret
    mov [arg1], si
.findsp:
    mov al, [si]
    test al, al
    jz .ret
    cmp al, ' '
    je .sp
    inc si
    jmp .findsp
.sp:
    mov byte [si], 0
    inc si
.skip:
    mov al, [si]
    cmp al, ' '
    jne .set
    inc si
    jmp .skip
.set:
    test al, al
    jz .ret
    mov [arg2], si
.ret:
    ret

args_same:
    mov si, [arg1]
    mov di, [arg2]
.l:
    mov al, [si]
    cmp al, [di]
    jne .no
    test al, al
    jz .yes
    inc si
    inc di
    jmp .l
.yes:
    mov al, 1
    ret
.no:
    xor al, al
    ret

; --- commands --------------------------------------------------------------

print_name:
    push si
    push cx
    xor bx, bx
    mov cx, 8
.n:
    mov al, [si + bx]
    cmp al, ' '
    je .skip
    call putc
.skip:
    inc bx
    loop .n
    mov al, [si + 8]
    cmp al, ' '
    je .done
    mov al, '.'
    call putc
    xor bx, bx
    mov cx, 3
.e:
    mov al, [si + 8 + bx]
    cmp al, ' '
    je .eskip
    call putc
.eskip:
    inc bx
    loop .e
.done:
    pop cx
    pop si
    ret

cmd_ls:
    mov si, [argp]
    test si, si
    jz .cwd
    cmp byte [si], 0
    je .cwd
    call resolve
    cmp byte [res_err], 0
    jne .err
    call name_is_blank
    test al, al
    jnz .loaddir
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .err
    test byte [res_attr], 0x10
    jz .err
    mov ax, [res_first]
    jmp .load
.loaddir:
    mov ax, [res_dir]
.load:
    call dir_load
    jmp .list
.cwd:
    mov ax, [cwd_cluster]
    call dir_load
.list:
    mov si, dirbuf
    mov cx, [dir_ns]
    shl cx, 4
.ent:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 0xE5
    je .next
    cmp byte [si + 11], 0x0F
    je .next
    test byte [si + 11], 0x08
    jnz .next
    call is_dot
    test al, al
    jnz .next
    call print_name
    test byte [si + 11], 0x10
    jz .nl
    mov al, '/'
    call putc
.nl:
    call newline
.next:
    add si, 32
    dec cx
    jnz .ent
.done:
    ret
.err:
    mov si, s_ls_err
    call puts
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
    call dir_load
.done:
    ret

cmd_pwd:
    mov si, cwd_path
    call puts
    call newline
    ret

cmd_cd:
    mov si, [argp]
    test si, si
    jz .home
    cmp byte [si], 0
    je .home
    call resolve
    cmp byte [res_err], 0
    jne .nf
    call name_is_blank
    test al, al
    jz .lookup
    mov ax, [res_dir]
    jmp .have
.lookup:
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .nf
    test byte [res_attr], 0x10
    jz .nd
    mov ax, [res_first]
    jmp .have
.home:
    mov si, s_home_a
    call resolve
    cmp byte [res_err], 0
    jne .nf
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .nf
    test byte [res_attr], 0x10
    jz .nd
    mov ax, [res_first]
.have:
    mov [cwd_cluster], ax
    mov si, pathbuf
    mov di, cwd_path
    call set_es_k
.cp:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .cp
    mov ax, [cwd_cluster]
    call dir_load
    ret
.nf:
    mov si, s_cd_nf
    call puts
    ret
.nd:
    mov si, s_cd_nd
    call puts
    ret

cmd_cat:
    mov si, [argp]
    test si, si
    jz .usage
    cmp byte [si], 0
    je .usage
    call resolve
    cmp byte [res_err], 0
    jne .nf
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .nf
    test byte [res_attr], 0x10
    jnz .isdir
    mov ax, [res_first]
    mov [cluster], ax
    mov ax, [res_size]
    mov [fsize], ax
    mov ax, [res_size + 2]
    mov [fsize + 2], ax
.rd:
    mov ax, [fsize]
    or ax, [fsize + 2]
    jz .ok
    mov ax, [cluster]
    cmp ax, 2
    jb .ok
    cmp ax, 0xFF8
    jae .ok
    add ax, DATA_LBA - 2
    mov [tmp_lba], ax
    mov bx, 0
    mov dx, SCR_SEG
    mov es, dx
    call read_sector
    mov bp, [fsize]
    cmp bp, 512
    jbe .sz
    mov bp, 512
.sz:
    mov si, SCR_OFF
    mov cx, bp
.pr:
    mov al, [si]
    inc si
    cmp al, 10
    jne .raw
    mov al, 13
    call putc
    mov al, 10
.raw:
    call putc
    loop .pr
    mov ax, [fsize]
    sub ax, bp
    mov [fsize], ax
    mov ax, [fsize + 2]
    sbb ax, 0
    mov [fsize + 2], ax
    mov ax, [cluster]
    call fat_next
    mov [cluster], ax
    jmp .rd
.ok:
    ret
.nf:
    mov si, s_cat_nf
    call puts
    ret
.isdir:
    mov si, s_is_dir
    call puts
    ret
.usage:
    mov si, s_cat_use
    call puts
    ret

cmd_rm:
    call split_args
    mov si, [arg1]
    test si, si
    jz .usage
    call resolve
    cmp byte [res_err], 0
    jne .nodir
    call need_write
    test al, al
    jz .done
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .nf
    test byte [res_attr], 0x10
    jz .free
    call dir_empty
    test al, al
    jz .busy
.free:
    mov ax, [res_first]
    call vi_free_chain
    mov si, dirbuf
    add si, [res_off]
    mov di, ventry
    call set_es_k
    mov cx, 32
    rep movsb
    mov byte [ventry], 0xE5
    call dir_write_entry
.done:
    ret
.nodir:
    mov si, s_no_dir
    call puts
    ret
.busy:
    mov si, s_rm_busy
    call puts
    ret
.nf:
    mov si, s_rm_nf
    call puts
    ret
.usage:
    mov si, s_rm_use
    call puts
    ret

cmd_touch:
    call split_args
    mov si, [arg1]
    test si, si
    jz .usage
    call resolve
    cmp byte [res_err], 0
    jne .nodir
    call need_write
    test al, al
    jz .done
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jnz .done
    call dir_find_free
    test al, al
    jz .full
    call entry_init
    mov word [ventry + 26], 0
    mov word [ventry + 28], 0
    mov word [ventry + 30], 0
    call dir_write_entry
.done:
    ret
.nodir:
    mov si, s_no_dir
    call puts
    ret
.full:
    mov si, s_no_space
    call puts
    ret
.usage:
    mov si, s_touch_use
    call puts
    ret

cmd_mkdir:
    call split_args
    mov si, [arg1]
    test si, si
    jz .usage
    call resolve
    cmp byte [res_err], 0
    jne .nodir
    call need_write
    test al, al
    jz .done
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jnz .exists
    call dir_find_free
    test al, al
    jz .full
    call vi_alloc
    test ax, ax
    jz .full
    mov [mk_cl], ax
    call entry_init
    mov dx, SCR_SEG
    mov es, dx
    mov di, SCR_OFF
    xor ax, ax
    mov cx, 256
    rep stosw
    mov di, SCR_OFF
    mov al, ' '
    mov cx, 11
.fill:
    stosb
    loop .fill
    mov di, SCR_OFF
    mov al, '.'
    stosb
    mov di, SCR_OFF + 11
    mov al, 0x10
    stosb
    mov di, SCR_OFF + 26
    mov ax, [mk_cl]
    stosw
    mov di, SCR_OFF + 32
    mov al, ' '
    mov cx, 11
.fill2:
    stosb
    loop .fill2
    mov di, SCR_OFF + 32
    mov al, '.'
    stosb
    stosb
    mov di, SCR_OFF + 32 + 11
    mov al, 0x10
    stosb
    mov di, SCR_OFF + 32 + 26
    mov ax, [res_dir]
    stosw
    mov ax, [mk_cl]
    add ax, 31
    mov bx, SCR_OFF
    mov dx, SCR_SEG
    mov es, dx
    call write_sector
    mov byte [ventry + 11], 0x10
    mov ax, [mk_cl]
    mov [ventry + 26], ax
    mov word [ventry + 28], 0
    mov word [ventry + 30], 0
    call dir_write_entry
.done:
    ret
.nodir:
    mov si, s_no_dir
    call puts
    ret
.exists:
    mov si, s_mk_ex
    call puts
    ret
.full:
    mov si, s_no_space
    call puts
    ret
.usage:
    mov si, s_mk_use
    call puts
    ret

cp_prepare_src:
    mov si, [arg1]
    call resolve
    cmp byte [res_err], 0
    jne .nf
    mov ax, [res_dir]
    mov [cp_srcdir], ax
    mov si, name83
    mov di, cp_name
    call set_es_k
    mov cx, 11
    rep movsb
    mov ax, [cp_srcdir]
    call dir_load
    mov si, cp_name
    mov di, name83
    call set_es_k
    mov cx, 11
    rep movsb
    call dir_find
    test al, al
    jz .nf
    test byte [res_attr], 0x10
    jnz .isdir
    mov ax, [res_first]
    mov [cp_src], ax
    mov ax, [res_size]
    mov [cp_size], ax
    mov ax, [res_size + 2]
    mov [cp_size + 2], ax
    mov al, 1
    ret
.nf:
    mov si, s_cp_nf
    call puts
    xor al, al
    ret
.isdir:
    mov si, s_is_dir
    call puts
    xor al, al
    ret

cp_prepare_dst:
    mov si, [arg2]
    call resolve
    cmp byte [res_err], 0
    jne .nodir
    call need_write
    test al, al
    jz .no
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .newdst
    test byte [res_attr], 0x10
    jnz .isdir
    mov byte [cp_have], 1
    mov ax, [res_first]
    call vi_free_chain
    mov al, 1
    ret
.newdst:
    call dir_find_free
    test al, al
    jz .full
    mov byte [cp_have], 1
    mov al, 1
    ret
.nodir:
    mov si, s_no_dir
    call puts
    jmp .no
.isdir:
    mov si, s_is_dir
    call puts
    jmp .no
.full:
    mov si, s_no_space
    call puts
.no:
    mov byte [cp_have], 0
    xor al, al
    ret

cp_copy:
    mov word [cp_new], 0
    mov word [cp_prev], 0
    mov ax, [cp_src]
    cmp ax, 2
    jb .fin
    cmp ax, 0xFF8
    jae .fin
.cl:
    mov [tmp_cl], ax
    add ax, 31
    mov bx, cpbuf
    mov dx, KSEG
    mov es, dx
    call read_sector
    call vi_alloc
    test ax, ax
    jz .full
    mov [cp_dst], ax
    cmp word [cp_new], 0
    jne .link
    mov [cp_new], ax
    jmp .write
.link:
    mov bx, ax
    mov ax, [cp_prev]
    call fat_set
.write:
    mov ax, [cp_dst]
    add ax, 31
    mov bx, cpbuf
    mov dx, KSEG
    mov es, dx
    call write_sector
    mov ax, [cp_dst]
    mov [cp_prev], ax
    mov ax, [tmp_cl]
    call fat_next
    cmp ax, 2
    jb .fin
    cmp ax, 0xFF8
    jae .fin
    jmp .cl
.fin:
    call entry_init
    mov ax, [cp_new]
    mov [ventry + 26], ax
    mov ax, [cp_size]
    mov [ventry + 28], ax
    mov ax, [cp_size + 2]
    mov [ventry + 30], ax
    call dir_write_entry
    mov al, 1
    ret
.full:
    cmp byte [cp_have], 0
    je .msg
    mov ax, [cp_new]
    test ax, ax
    jz .blank
    call vi_free_chain
.blank:
    call entry_init
    mov word [ventry + 26], 0
    mov word [ventry + 28], 0
    mov word [ventry + 30], 0
    call dir_write_entry
.msg:
    mov si, s_no_space
    call puts
    xor al, al
    ret

del_src:
    mov ax, [mv_srcdir]
    call dir_load
    mov si, mv_name
    mov di, name83
    call set_es_k
    mov cx, 11
    rep movsb
    call dir_find
    test al, al
    jz .done
    mov ax, [res_first]
    call vi_free_chain
    mov si, dirbuf
    add si, [res_off]
    mov di, ventry
    call set_es_k
    mov cx, 32
    rep movsb
    mov byte [ventry], 0xE5
    call dir_write_entry
.done:
    ret

cmd_cp:
    call split_args
    mov si, [arg1]
    test si, si
    jz .usage
    cmp word [arg2], 0
    je .usage
    mov si, [arg1]
    mov di, [arg2]
    call args_same
    test al, al
    jnz .same
    call cp_prepare_src
    test al, al
    jz .done
    call cp_prepare_dst
    test al, al
    jz .done
    call cp_copy
.done:
    ret
.same:
    mov si, s_cp_same
    call puts
    ret
.usage:
    mov si, s_cp_use
    call puts
    ret

cmd_mv:
    call split_args
    mov si, [arg1]
    test si, si
    jz .usage
    cmp word [arg2], 0
    je .usage
    mov si, [arg1]
    mov di, [arg2]
    call args_same
    test al, al
    jnz .same

    mov si, [arg1]
    call resolve
    cmp byte [res_err], 0
    jne .nf
    call need_write
    test al, al
    jz .done
    mov ax, [res_dir]
    mov [mv_srcdir], ax
    mov si, name83
    mov di, mv_name
    call set_es_k
    mov cx, 11
    rep movsb
    mov ax, [mv_srcdir]
    call dir_load
    mov si, mv_name
    mov di, name83
    call set_es_k
    mov cx, 11
    rep movsb
    call dir_find
    test al, al
    jz .nf
    mov al, [res_attr]
    mov [mv_attr], al

    mov si, [arg2]
    call resolve
    cmp byte [res_err], 0
    jne .nf
    call need_write
    test al, al
    jz .done
    mov ax, [res_dir]
    mov [mv_dstdir], ax
    mov si, name83
    mov di, mv_newname
    call set_es_k
    mov cx, 11
    rep movsb
    mov ax, [mv_dstdir]
    call dir_load
    call dir_find
    test al, al
    jnz .exists

    mov ax, [mv_srcdir]
    cmp ax, [mv_dstdir]
    jne .cross

    mov ax, [mv_srcdir]
    call dir_load
    mov si, mv_name
    mov di, name83
    call set_es_k
    mov cx, 11
    rep movsb
    call dir_find
    test al, al
    jz .nf
    mov si, dirbuf
    add si, [res_off]
    mov di, ventry
    call set_es_k
    mov cx, 32
    rep movsb
    mov si, mv_newname
    mov di, ventry
    call set_es_k
    mov cx, 11
    rep movsb
    call dir_write_entry
    ret
.cross:
    test byte [mv_attr], 0x10
    jnz .mvdir
    call cp_prepare_src
    test al, al
    jz .done
    call cp_prepare_dst
    test al, al
    jz .done
    call cp_copy
    test al, al
    jz .done
    call del_src
.done:
    ret
.exists:
    mov si, s_mv_ex
    call puts
    ret
.mvdir:
    mov si, s_mv_dir
    call puts
    ret
.nf:
    mov si, s_mv_nf
    call puts
    ret
.same:
    mov si, s_mv_same
    call puts
    ret
.usage:
    mov si, s_mv_use
    call puts
    ret

; fills cpu_name with the brand string (or the vendor id), plus core counts
cpu_probe:
    mov word [cpu_cores], 1
    mov word [cpu_threads], 1
    mov si, s_cpu_unknown
    mov di, cpu_name
    call strcpy

    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    cmp eax, ecx
    je .done

    xor eax, eax
    cpuid
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0
    mov [cpu_max], eax

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .vendor

    mov di, cpu_brand
    mov eax, 0x80000002
    cpuid
    mov [di], eax
    mov [di + 4], ebx
    mov [di + 8], ecx
    mov [di + 12], edx
    mov eax, 0x80000003
    cpuid
    mov [di + 16], eax
    mov [di + 20], ebx
    mov [di + 24], ecx
    mov [di + 28], edx
    mov eax, 0x80000004
    cpuid
    mov [di + 32], eax
    mov [di + 36], ebx
    mov [di + 40], ecx
    mov [di + 44], edx
    mov byte [cpu_brand + 48], 0

    mov si, cpu_brand
.lead:
    cmp byte [si], ' '
    jne .start
    inc si
    jmp .lead
.start:
    mov di, si
.scan:
    cmp byte [di], 0
    je .trim
    inc di
    jmp .scan
.trim:
    cmp di, si
    jbe .cut
    cmp byte [di - 1], ' '
    jne .cut
    dec di
    jmp .trim
.cut:
    mov byte [di], 0
    cmp byte [si], 0
    je .vendor
    mov di, cpu_name
.copy:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .copy
    jmp .count

.vendor:
    mov si, cpu_vendor
    mov di, cpu_name
.cpv:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jnz .cpv

.count:
    cmp word [cpu_max], 4
    jb .leafb
    mov eax, 4
    xor ecx, ecx
    cpuid
    shr eax, 26
    inc eax
    mov [cpu_cores], ax
.leafb:
    cmp word [cpu_max], 0xB
    jb .leaf1
    mov eax, 0xB
    xor ecx, ecx
    cpuid
    test bx, bx
    jz .leaf1
    mov [cpu_threads], bx
    jmp .done
.leaf1:
    mov eax, 1
    cpuid
    mov eax, ebx
    shr eax, 16
    and eax, 0xFF
    test ax, ax
    jz .done
    mov [cpu_threads], ax
.done:
    ret


s_banner    db `\r\n  adachiOS 0.3 - a tiny os :3 (bios build)\r\n  type 'help' if you are lost\r\n\r\n`,0
s_prompt    db `:3 adachiOS:`,0
s_prompt2   db `> `,0
s_help      db `commands:\r\n  help      show this list\r\n  echo      echo your words back\r\n  clear     clear the screen\r\n  fetch     system, cpu and memory info\r\n  pwd       print the current directory\r\n  cd        change directory (cd DIR, cd to go home)\r\n  ls        list a directory (ls [DIR])\r\n  cat       print a file (cat FILE)\r\n  vi        edit a file (vi FILE, needs sudo outside /home)\r\n  touch     create an empty file (touch FILE)\r\n  mkdir     create a directory (mkdir DIR)\r\n  rm        delete a file (rm FILE)\r\n  cp        copy a file (cp SRC DST)\r\n  mv        rename a file (mv SRC DST)\r\n  flappy    play flappy bird (space/w flap, q quit)\r\n  net       show network status\r\n  ping HOST  send ICMP echo requests to HOST\r\n  uname     kernel info\r\n  meow      :3\r\n  sudo      run one command as root (sudo CMD)\r\n  reboot    reboot\r\n  poweroff  power off\r\n`,0
s_unknown   db `adachiOS: command not found (rude)\r\n`,0
s_uname     db `adachiOS 0.3 i386 BIOS (16-bit real mode)\r\n`,0
s_meow      db `meow :3\r\n`,0
s_sudo_name db `sudo`,0
s_sudo_use  db `usage: sudo CMD   (you start with only /home, sudo is root)\r\n`,0
s_sudo_root db `sudo: you are already root for this command\r\n`,0
s_home_a    db 0x5C,'home',0
s_no_dir    db `no such directory\r\n`,0
s_ls_err    db `ls: could not read that directory\r\n`,0
s_cd_nf     db `cd: no such directory\r\n`,0
s_cd_nd     db `cd: not a directory\r\n`,0
s_denied    db `adachiOS: permission denied (that is outside /home, try sudo)\r\n`,0
s_disk      db `adachiOS: disk read error\r\n`,0
s_cat_use   db `usage: cat FILE\r\n`,0
s_cat_nf    db `cat: no such file\r\n`,0
s_off       db `poweroff failed, halting.\r\n`,0
s_rm_use    db `usage: rm FILE\r\n`,0
s_rm_nf     db `rm: no such file\r\n`,0
s_rm_busy   db `rm: directory not empty\r\n`,0
s_touch_use db `usage: touch FILE\r\n`,0
s_mk_use    db `usage: mkdir DIR\r\n`,0
s_mk_ex     db `mkdir: already exists\r\n`,0
s_cp_use    db `usage: cp SRC DST\r\n`,0
s_cp_nf     db `cp: no such file\r\n`,0
s_cp_same   db `cp: source and destination are the same\r\n`,0
s_mv_use    db `usage: mv SRC DST\r\n`,0
s_mv_nf     db `mv: no such file\r\n`,0
s_mv_ex     db `mv: destination exists\r\n`,0
s_mv_same   db `mv: source and destination are the same\r\n`,0
s_mv_dir    db `mv: cannot move a directory to another directory\r\n`,0
s_is_dir    db `that is a directory\r\n`,0
s_no_space  db `no space left on the floppy\r\n`,0
s_cpu_unknown db `unknown`,0
s_f_head    db `\r\n  adachiOS fetch\r\n  --------------\r\n`,0
s_f_cpu     db `  cpu:      `,0
s_f_cores   db `  cores:    `,0
s_f_threads db `  threads:  `,0
s_f_arch    db `  arch:     i386 (16-bit real mode)\r\n`,0
s_f_mem     db `  memory:   `,0
s_f_mib     db ` MiB total\r\n`,0
s_f_low     db `  low:      `,0
s_f_kib     db ` KiB\r\n`,0
s_f_boot    db `  boot:     drive 0x`,0

n_help      db `help`,0
n_cd        db `cd`,0
n_pwd       db `pwd`,0
n_echo      db `echo`,0
n_clear     db `clear`,0
n_fetch     db `fetch`,0
n_ls        db `ls`,0
n_cat       db `cat`,0
n_vi        db `vi`,0
n_touch     db `touch`,0
n_mkdir     db `mkdir`,0
n_rm        db `rm`,0
n_cp        db `cp`,0
n_mv        db `mv`,0
n_flappy    db `flappy`,0
n_uname     db `uname`,0
n_meow      db `meow`,0
n_net       db `net`,0
n_ping      db `ping`,0
n_sudo      db `sudo`,0
n_reboot    db `reboot`,0
n_poweroff  db `poweroff`,0

cmdtab:
    dw n_help,     cmd_help
    dw n_cd,       cmd_cd
    dw n_pwd,      cmd_pwd
    dw n_echo,     cmd_echo
    dw n_clear,    cmd_clear
    dw n_fetch,    cmd_fetch
    dw n_ls,       cmd_ls
    dw n_cat,      cmd_cat
    dw n_vi,       cmd_vi
    dw n_touch,    cmd_touch
    dw n_mkdir,    cmd_mkdir
    dw n_rm,       cmd_rm
    dw n_cp,       cmd_cp
    dw n_mv,       cmd_mv
    dw n_flappy,   cmd_flappy
    dw n_uname,    cmd_uname
    dw n_meow,     cmd_meow
    dw n_net,      cmd_net
    dw n_ping,     cmd_ping
    dw n_reboot,   cmd_reboot
    dw n_poweroff, cmd_poweroff
    dw 0, 0

drive    db 0
argp     dw 0
arg1     dw 0
arg2     dw 0
root_mode db 0
cwd_path db '\home',0
times 58 db 0
cwd_cluster dw 0
pathbuf  times 64 db 0
path_in  dw 0
pb_end   dw 0
cur_cl   dw 0
res_dir  dw 0
res_off  dw 0
res_first dw 0
res_size dd 0
res_attr db 0
res_err  db 0
comp_ptr dw 0
next_ptr dw 0
compbuf  times 16 db 0
dir_cluster dw 0
dir_ns   dw 0
dir_lba  times DIRMAX dw 0
dir_new_off dw 0
dirbuf   times 7168 db 0
tmp_cl   dw 0
tmp_new  dw 0
tmp_lba  dw 0
cp_srcdir dw 0
cp_name  times 11 db ' '
mv_srcdir dw 0
mv_dstdir dw 0
mv_name  times 11 db ' '
mv_newname times 11 db ' '
mv_attr  db 0
mem_kb   dd 0
mem_mib  dw 0
mem_lo   dw 0
cluster  dw 0
fat_off  dw 0
fsize    dd 0
mk_cl    dw 0
cp_src   dw 0
cp_dst   dw 0
cp_new   dw 0
cp_prev  dw 0
cp_size  dd 0
cp_have  db 0
cpbuf    times 512 db 0
cpu_max  dd 0
cpu_cores   dw 0
cpu_threads dw 0
cpu_vendor  times 13 db 0
cpu_brand   times 49 db 0
cpu_name    times 64 db 0
name83   times 11 db ' '
linebuf  times MAXLINE db 0

%include "ethernet_bios.inc"

%include "bios/flappy.asm"
%include "bios/vi.asm"

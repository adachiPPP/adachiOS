
bits 16
%include "bios/defs.inc"
%ifndef SELF_SEG
%define SELF_SEG PROG_SEG
%endif
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

set_es_self:
    push ax
    mov ax, SELF_SEG
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
    call set_es_self
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
    call set_es_self
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
    mov dx, SELF_SEG
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
    mov dx, SELF_SEG
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
    call fat_alloc
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
    mov dx, SELF_SEG
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
    mov bx, SCR_OFF + 32 + 26
    mov ax, [es:bx]
    cmp ax, 2
    jae .ok
    xor ax, ax
.ok:
    ret

dir_empty:
    mov bp, [res_first]
.next:
    cmp bp, 2
    jb .yes
    cmp bp, 0xFF8
    jae .yes
    mov ax, bp
    add ax, 31
    xor bx, bx
    mov dx, SCR_SEG
    mov es, dx
    call read_sector
    mov si, SCR_OFF
    push ds
    mov ds, dx
    mov cx, 16
.scan:
    mov al, [si]
    test al, al
    jz .empty
    cmp al, 0xE5
    je .nextent
    cmp byte [si + 11], 0x0F
    je .nextent
    call is_dot
    test al, al
    jnz .nextent
    pop ds
    xor al, al
    ret
.nextent:
    add si, 32
    dec cx
    jnz .scan
    pop ds
    mov ax, bp
    call fat_next
    mov bp, ax
    jmp .next
.empty:
    pop ds
.yes:
    mov al, 1
    ret

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

cp_prepare_src:
    mov si, [arg1]
    call resolve
    cmp byte [res_err], 0
    jne .nf
    mov ax, [res_dir]
    mov [cp_srcdir], ax
    mov si, name83
    mov di, cp_name
    call set_es_self
    mov cx, 11
    rep movsb
    mov ax, [cp_srcdir]
    call dir_load
    mov si, cp_name
    mov di, name83
    call set_es_self
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
    call fat_free_chain
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
    mov dx, SELF_SEG
    mov es, dx
    call read_sector
    call fat_alloc
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
    mov dx, SELF_SEG
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
    call fat_free_chain
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
    call set_es_self
    mov cx, 11
    rep movsb
    call dir_find
    test al, al
    jz .done
    mov ax, [res_first]
    call fat_free_chain
    mov si, dirbuf
    add si, [res_off]
    mov di, ventry
    call set_es_self
    mov cx, 32
    rep movsb
    mov byte [ventry], 0xE5
    call dir_write_entry
.done:
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
.shift:
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
    mov dx, SCR_SEG
    mov es, dx
    call read_sector
    mov dx, SCR_SEG
    mov es, dx
    mov si, [vi_fat_off]
    add si, SCR_OFF
    mov ax, [es:si]
    mov dx, [vi_fat_cl]
    test dx, 1
    jz .even
    and ax, 0x000F
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
    mov [es:si], ax
    mov ax, [vi_lba]
    mov bx, SCR_OFF
    mov dx, SCR_SEG
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

fat_alloc:
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

fat_free_chain:
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
    jmp fat_free_chain
.done:
    ret

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

lib_read_file:
    push bx
    push dx
    push si
    push di
    push bp
    mov [rf_dest], di
    mov [rf_max], cx

    call resolve
    cmp byte [res_err], 0
    jne .err
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .err
    test byte [res_attr], 0x10
    jnz .err

    mov word [rf_total], 0
    mov ax, [res_size]
    mov [rf_left], ax
    mov ax, [res_size + 2]
    mov [rf_left + 2], ax
    mov ax, [res_first]
    mov [rf_cl], ax

.rd:
    mov ax, [rf_left]
    or ax, [rf_left + 2]
    jz .ok
    mov ax, [rf_cl]
    cmp ax, 2
    jb .ok
    cmp ax, 0xFF8
    jae .ok
    add ax, DATA_LBA - 2
    mov bx, SCR_OFF
    mov dx, SCR_SEG
    mov es, dx
    call read_sector

    mov cx, [rf_left]
    cmp cx, 512
    jbe .n1
    mov cx, 512
.n1:
    mov ax, [rf_max]
    sub ax, [rf_total]
    jbe .ok
    cmp cx, ax
    jbe .n2
    mov cx, ax
.n2:
    mov [rf_n], cx
    push ds
    mov ax, SCR_SEG
    mov ds, ax
    mov ax, SELF_SEG
    mov es, ax
    mov si, SCR_OFF
    mov di, [rf_dest]
    add di, [rf_total]
    cld
    rep movsb
    pop ds

    mov ax, [rf_n]
    add [rf_total], ax
    sub [rf_left], ax
    sbb word [rf_left + 2], 0
    mov ax, [rf_cl]
    call fat_next
    mov [rf_cl], ax
    jmp .rd

.ok:
    mov ax, [rf_total]
    clc
    jmp .out
.err:
    xor ax, ax
    stc
.out:
    pop bp
    pop di
    pop si
    pop dx
    pop bx
    ret

lib_write_file:
    push bx
    push dx
    push si
    push di
    push bp
    mov [wf_src], di
    mov [wf_len], cx

    call resolve
    cmp byte [res_err], 0
    jne .err
    call need_write
    test al, al
    jz .err

    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .new
    test byte [res_attr], 0x10
    jnz .err
    mov ax, [res_first]
    call fat_free_chain
    mov ax, [res_off]
    mov [wf_entry], ax
    jmp .write

.new:
    call dir_find_free
    test al, al
    jz .err
    call entry_init
    mov byte [ventry + 11], 0x20
    mov word [ventry + 26], 0
    mov word [ventry + 28], 0
    mov word [ventry + 30], 0
    call dir_write_entry
    mov ax, [res_off]
    mov [wf_entry], ax

.write:
    mov word [wf_first], 0
    mov word [wf_prev], 0
    mov word [wf_off], 0
    cmp word [wf_len], 0
    je .finish

.wloop:
    call fat_alloc
    test ax, ax
    jz .err
    mov [wf_cl], ax
    cmp word [wf_first], 0
    jne .link
    mov [wf_first], ax
    jmp .wr
.link:
    mov ax, [wf_prev]
    mov bx, [wf_cl]
    call fat_set

.wr:
    mov di, SCR_OFF
    mov cx, 512
    xor al, al
    mov dx, SCR_SEG
    mov es, dx
    cld
    rep stosb

    mov cx, [wf_len]
    sub cx, [wf_off]
    cmp cx, 512
    jbe .n
    mov cx, 512
.n:
    mov [wf_n], cx
    push ds
    mov ax, SELF_SEG
    mov ds, ax
    mov ax, SCR_SEG
    mov es, ax
    mov si, [wf_src]
    add si, [wf_off]
    mov di, SCR_OFF
    cld
    rep movsb
    pop ds

    mov ax, [wf_cl]
    add ax, DATA_LBA - 2
    mov bx, SCR_OFF
    mov dx, SCR_SEG
    mov es, dx
    call write_sector

    mov ax, [wf_cl]
    mov [wf_prev], ax
    mov ax, [wf_n]
    add [wf_off], ax
    mov ax, [wf_off]
    cmp ax, [wf_len]
    jb .wloop

.finish:
    mov ax, [wf_entry]
    mov [res_off], ax
    call entry_init
    mov byte [ventry + 11], 0x20
    mov ax, [wf_first]
    mov [ventry + 26], ax
    mov ax, [wf_len]
    mov [ventry + 28], ax
    mov word [ventry + 30], 0
    call dir_write_entry
    xor ax, ax
    clc
    jmp .out

.err:
    mov ax, 1
    stc
.out:
    pop bp
    pop di
    pop si
    pop dx
    pop bx
    ret

s_disk      db 'adachiOS: disk read error',13,10,0
s_home_a    db 0x5C,'home',0
s_denied    db 'adachiOS: permission denied (that is outside /home, try rodo)',13,10,0
s_cpu_unknown db 'unknown',0

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
dir_new_off dw 0
tmp_cl      dw 0
tmp_new     dw 0
tmp_lba     dw 0

arg1        dw 0
arg2        dw 0

cp_srcdir   dw 0
cp_name     times 11 db ' '
cp_src      dw 0
cp_dst      dw 0
cp_new      dw 0
cp_prev     dw 0
cp_size     dd 0
cp_have     db 0
cpbuf       times 512 db 0

mv_srcdir   dw 0
mv_dstdir   dw 0
mv_name     times 11 db ' '
mv_newname  times 11 db ' '
mv_attr     db 0

mem_kb      dd 0
mem_mib     dw 0
mem_lo      dw 0

cpu_max     dd 0
cpu_cores   dw 0
cpu_threads dw 0
cpu_vendor  times 13 db 0
cpu_brand   times 49 db 0
cpu_name    times 64 db 0

vi_fat_off  dw 0
vi_fat_cl   dw 0
vi_fat_val  dw 0
vi_lba      dw 0
vi_cur      dw 0
vi_tmp      dw 0

rf_dest     dw 0
rf_max      dw 0
rf_total    dw 0
rf_left     dd 0
rf_cl       dw 0
rf_n        dw 0

wf_src      dw 0
wf_len      dw 0
wf_off      dw 0
wf_entry    dw 0
wf_first    dw 0
wf_prev     dw 0
wf_cl       dw 0
wf_n        dw 0

cluster     dw 0
fsize       dd 0
mk_cl       dw 0

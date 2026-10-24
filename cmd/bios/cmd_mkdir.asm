%include "bios/prog.inc"

cmd_main:
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
    call fat_alloc
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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

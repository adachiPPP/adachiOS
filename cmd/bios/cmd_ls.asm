%include "bios/prog.inc"

cmd_main:
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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

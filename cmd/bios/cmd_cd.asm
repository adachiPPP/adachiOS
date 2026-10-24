%include "bios/prog.inc"

cmd_main:
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
    call set_es_self
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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

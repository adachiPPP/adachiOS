%include "bios/prog.inc"

cmd_main:
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
    call set_es_self
    mov cx, 11
    rep movsb
    mov ax, [mv_srcdir]
    call dir_load
    mov si, mv_name
    mov di, name83
    call set_es_self
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
    call set_es_self
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
    call set_es_self
    mov cx, 11
    rep movsb
    call dir_find
    test al, al
    jz .nf
    mov si, dirbuf
    add si, [res_off]
    mov di, ventry
    call set_es_self
    mov cx, 32
    rep movsb
    mov si, mv_newname
    mov di, ventry
    call set_es_self
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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

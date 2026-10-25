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
    jz .nf
    test byte [res_attr], 0x10
    jz .free
    call dir_empty
    test al, al
    jz .busy
.free:
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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

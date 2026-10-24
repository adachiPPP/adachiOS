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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

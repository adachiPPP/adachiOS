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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

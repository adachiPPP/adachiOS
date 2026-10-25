%include "bios/prog.inc"

cmd_main:
    push si
    push bx
    mov si, [argp]
    test si, si
    jz .done
    mov bx, si
.L_find:
    cmp byte [bx], 0
    je .print
    inc bx
    jmp .L_find
.print:
    dec bx
    cmp bx, si
    jb .done
    mov al, [bx]
    call putc
    dec bx
    cmp bx, si
    jae .print
.done:
    mov al, 13
    call putc
    mov al, 10
    call putc
    pop bx
    pop si
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

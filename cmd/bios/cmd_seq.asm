%include "bios/prog.inc"

cmd_main:
    push bx
    push cx
    push dx
    push si
    mov si, [argp]
    test si, si
    jz .done
    xor cx, cx
    xor ax, ax
.L_parse:
    mov al, [si]
    test al, al
    jz .print
    cmp al, '0'
    jb .print
    cmp al, '9'
    ja .print
    sub al, '0'
    xchg ax, cx
    mov bx, 10
    mul bx
    add cx, ax
    inc si
    jmp .L_parse
.print:
    test cx, cx
    jle .done
    mov bx, 1
.L_loop:
    cmp bx, cx
    jg .done
    mov ax, bx
    call print_dec
    call newline
    mov ah, 1
    int 0x16
    jz .L_seq_nokey
    mov ah, 0
    int 0x16
    cmp al, 3
    je .done
.L_seq_nokey:
    inc bx
    jmp .L_loop
.done:
    pop si
    pop dx
    pop cx
    pop bx
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

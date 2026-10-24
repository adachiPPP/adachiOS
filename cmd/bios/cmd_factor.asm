%include "bios/prog.inc"

cmd_main:
    push bx
    push cx
    push dx
    mov si, [argp]
    test si, si
    jz .done
    xor cx, cx
    xor ax, ax
.L_pf:
    mov al, [si]
    test al, al
    jz .have
    cmp al, '0'
    jb .have
    cmp al, '9'
    ja .have
    sub al, '0'
    xchg ax, cx
    mov bx, 10
    mul bx
    add cx, ax
    inc si
    jmp .L_pf
.have:
    cmp cx, 2
    jl .done
    mov bx, 2
.L_loopf:
    cmp bx, cx
    jg .done
    mov ax, cx
    xor dx, dx
    div bx
    test dx, dx
    jnz .nextf
    mov ax, bx
    call print_dec
    call newline
    mov ax, cx
    xor dx, dx
    div bx
    mov cx, ax
    jmp .L_loopf
.nextf:
    mov ah, 1
    int 0x16
    jz .L_factor_nokey
    mov ah, 0
    int 0x16
    cmp al, 3
    je .done
.L_factor_nokey:
    inc bx
    jmp .L_loopf
.done:
    cmp cx, 1
    jle .finish
    mov ax, cx
    call print_dec
    call newline
.finish:
    pop dx
    pop cx
    pop bx
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

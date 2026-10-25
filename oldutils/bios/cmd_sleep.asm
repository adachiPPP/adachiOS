%include "bios/prog.inc"

cmd_main:
    push cx
    push dx
    mov si, [argp]
    test si, si
    jz .done
    xor cx, cx
    xor ax, ax
.L_parse2:
    mov al, [si]
    test al, al
    jz .wait
    cmp al, '0'
    jb .wait
    cmp al, '9'
    ja .wait
    sub al, '0'
    xchg ax, cx
    mov bx, 10
    mul bx
    add cx, ax
    inc si
    jmp .L_parse2
.wait:
    test cx, cx
    jz .done2
    mov ah, 0x86
    mov cx, 0x000F
    mov dx, 0x4240
    int 0x15
    dec cx

.done2:
.done:
    pop dx
    pop cx
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

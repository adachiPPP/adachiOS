%include "bios/prog.inc"

cmd_main:
    push cx
    mov cx, 10
.L_yes:
    mov si, s_byes
    call puts
    mov ah, 1
    int 0x16
    jz .L_yes_nokey
    mov ah, 0
    int 0x16
    cmp al, 3
    je .L_yes_done
.L_yes_nokey:
    dec cx
    jnz .L_yes
.L_yes_done:
    pop cx
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

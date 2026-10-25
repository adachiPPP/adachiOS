%include "uefi.inc"

bits 64
default rel

global cmd_sleep

extern argp
extern bs

section .text

cmd_sleep:
    sub rsp, 40
    push r12
    mov rsi, [argp]
    xor r12, r12
.parse:
    movzx eax, word [rsi]
    test ax, ax
    jz .wait
    cmp ax, '0'
    jb .wait
    cmp ax, '9'
    ja .wait
    sub ax, '0'
    imul r12, r12, 10
    add r12, rax
    add rsi, 2
    jmp .parse
.wait:
    test r12, r12
    jz .done
    mov rax, [bs]
    mov ecx, 1000000
    mov edx, 0
    call [rax + BS_STALL]
    dec r12
    jnz .wait
.done:
    pop r12
    add rsp, 40
    ret

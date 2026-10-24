%include "uefi.inc"

bits 64
default rel

global cmd_rev

extern argp
extern puts
extern s_nl
extern numbuf

section .text

cmd_rev:
    sub rsp, 40
    push r12
    push r13
    mov r12, [argp]
    test r12, r12
    jz .out
    xor r13, r13
.len:
    movzx eax, word [r12 + r13*2]
    test ax, ax
    jz .print
    inc r13
    jmp .len
.print:
    test r13, r13
    jz .nl
.ch:
    dec r13
    movzx eax, word [r12 + r13*2]
    mov [numbuf], al
    mov byte [numbuf + 1], 0
    lea rsi, [numbuf]
    call puts
    test r13, r13
    jnz .ch
.nl:
    lea rsi, [s_nl]
    call puts
.out:
    pop r13
    pop r12
    add rsp, 40
    ret

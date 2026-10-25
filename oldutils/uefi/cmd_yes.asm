%include "uefi.inc"

bits 64
default rel

global cmd_yes

extern conin
extern puts
extern s_nl
extern numbuf

section .text

cmd_yes:
    sub rsp, 40
    push r12
    mov r12d, 10
.loop:
    mov rax, [conin]
    mov rcx, rax
    lea rdx, [numbuf]
    sub rsp, 40
    call [rax + IN_READKEYSTROKE]
    add rsp, 40
    test rax, rax
    jnz .print
    movzx eax, word [numbuf + 2]
    cmp ax, 3
    je .done
    cmp ax, 0x001B
    je .done
    cmp ax, 'q'
    je .done
    cmp ax, 'Q'
    je .done
.print:
    lea rsi, [s_yes_word]
    call puts
    dec r12d
    jnz .loop
.done:
    pop r12
    add rsp, 40
    ret

section .data

s_yes_word db `y\r\n`,0

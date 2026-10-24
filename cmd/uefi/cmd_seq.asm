%include "uefi.inc"

bits 64
default rel

global cmd_seq

extern argp
extern conin
extern puts
extern print_dec
extern s_nl
extern numbuf

section .text

cmd_seq:
    sub rsp, 40
    push r12
    push r13
    mov rsi, [argp]
    xor r13, r13
.parse:
    movzx eax, word [rsi]
    test ax, ax
    jz .have
    cmp ax, '0'
    jb .have
    cmp ax, '9'
    ja .have
    sub ax, '0'
    imul r13, r13, 10
    add r13, rax
    add rsi, 2
    jmp .parse
.have:
    mov r12, 1
.loop:
    cmp r12, r13
    jg .done
    mov rax, r12
    call print_dec
    lea rsi, [s_nl]
    call puts
    mov rax, [conin]
    mov rcx, rax
    lea rdx, [numbuf]
    sub rsp, 40
    call [rax + IN_READKEYSTROKE]
    add rsp, 40
    test rax, rax
    jnz .next
    movzx eax, word [numbuf + 2]
    cmp ax, 3
    je .done
    cmp ax, 0x001B
    je .done
    cmp ax, 'q'
    je .done
    cmp ax, 'Q'
    je .done
.next:
    inc r12
    jmp .loop
.done:
    pop r13
    pop r12
    add rsp, 40
    ret

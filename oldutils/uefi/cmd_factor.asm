%include "uefi.inc"

bits 64
default rel

global cmd_factor

extern argp
extern puts
extern print_dec
extern s_nl

section .text

cmd_factor:
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
    cmp r13, 2
    jl .done
    mov r12, 2
.loop:
    cmp r12, r13
    jg .done
    mov rax, r13
    xor rdx, rdx
    div r12
    test rdx, rdx
    jnz .next
    push rax
    mov rax, r12
    call print_dec
    lea rsi, [s_nl]
    call puts
    pop r13
    jmp .loop
.next:
    inc r12
    jmp .loop
.done:
    cmp r13, 1
    jle .out
    mov rax, r13
    call print_dec
    lea rsi, [s_nl]
    call puts
.out:
    pop r13
    pop r12
    add rsp, 40
    ret

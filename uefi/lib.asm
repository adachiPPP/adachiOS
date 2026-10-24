%include "uefi.inc"

bits 64
default rel

global puts
global puts_w
global print_dec
global s_nl
global wbuf
global numbuf

extern conout

section .text

puts_w:
    sub rsp, 40
    mov rcx, [conout]
    mov rdx, rsi
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    add rsp, 40
    ret

puts:
    sub rsp, 40
    lea rdi, [wbuf]
.c:
    mov al, [rsi]
    test al, al
    jz .done
    movzx eax, al
    mov [rdi], ax
    inc rsi
    add rdi, 2
    jmp .c
.done:
    mov word [rdi], 0
    mov rcx, [conout]
    lea rdx, [wbuf]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    add rsp, 40
    ret

print_dec:
    sub rsp, 40
    lea rdi, [numbuf + 31]
    mov byte [rdi], 0
    mov rcx, 10
.d:
    xor edx, edx
    div rcx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .d
    mov rsi, rdi
    call puts
    add rsp, 40
    ret

section .data

s_nl      db `\r\n`,0

section .bss

wbuf         resb 1024
numbuf       resb 32

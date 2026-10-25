%include "uefi.inc"

bits 64
default rel

global cmd_adinit

extern fs_open
extern print_bytes
extern puts

section .text

cmd_adinit:
    sub rsp, 40

    lea rcx, [s_path]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nofile
    mov [adinit_h], rax

.rd:
    mov qword [adinit_sz], 4096
    mov rax, [adinit_h]
    mov rcx, rax
    lea rdx, [adinit_sz]
    lea r8, [adinit_buf]
    call [rax + FILE_READ]
    test rax, rax
    jnz .close
    mov rcx, [adinit_sz]
    test rcx, rcx
    jz .close
    lea rsi, [adinit_buf]
    call print_bytes
    jmp .rd

.close:
    mov rax, [adinit_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    add rsp, 40
    ret

.nofile:
    lea rsi, [s_fallback]
    call puts
    add rsp, 40
    ret

section .data

s_path  dw 92, 'e', 't', 'c', 92, 'm', 'o', 't', 'd', 0
s_fallback db `welcome to adachiOS 0.6 :3\r\ntype 'help' for commands\r\n`,0

section .bss

adinit_h  resq 1
adinit_sz resq 1
adinit_buf resb 4096
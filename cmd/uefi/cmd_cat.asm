%include "uefi.inc"

bits 64
default rel

global cmd_cat

extern argp
extern fs_open
extern resolve_path
extern pathbuf
extern print_bytes
extern puts
extern s_nl
extern conout

section .text

cmd_cat:
    sub rsp, 40
    mov rax, [argp]
    cmp word [rax], 0
    je .usage

    mov rsi, [argp]
    call resolve_path
    lea rcx, [pathbuf]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nofile
    mov [cat_h], rax

.rd:
    mov qword [cat_sz], 4096
    mov rax, [cat_h]
    mov rcx, rax
    lea rdx, [cat_sz]
    lea r8, [catbuf]
    call [rax + FILE_READ]
    test rax, rax
    jnz .close
    mov rcx, [cat_sz]
    test rcx, rcx
    jz .close
    lea rsi, [catbuf]
    call print_bytes
    jmp .rd

.close:
    mov rax, [cat_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    add rsp, 40
    ret

.nofile:
    lea rsi, [s_cat_nf]
    call puts
    add rsp, 40
    ret

.usage:
    lea rsi, [s_cat_use]
    call puts
    add rsp, 40
    ret

section .data

s_cat_use  db `usage: cat FILE\r\n`,0
s_cat_nf   db `cat: no such file\r\n`,0

section .bss

cat_h        resq 1
cat_sz       resq 1
catbuf       resb 4096

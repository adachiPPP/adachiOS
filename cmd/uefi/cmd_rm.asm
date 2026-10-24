%include "uefi.inc"

bits 64
default rel

global cmd_rm

extern argp
extern split_args
extern a1
extern resolve_path
extern pathbuf
extern need_write
extern fs_open
extern puts

section .text

cmd_rm:
    sub rsp, 40
    call split_args
    mov rcx, [a1]
    test rcx, rcx
    jz .usage
    cmp word [rcx], 0
    je .usage

    mov rsi, [a1]
    call resolve_path
    lea rsi, [pathbuf]
    mov [a1], rsi
    call need_write
    test eax, eax
    jz .out

    mov rcx, [a1]
    mov rdx, 3
    call fs_open
    test rax, rax
    jnz .have
    mov rcx, [a1]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nofile
.have:
    mov [rm_h], rax
    mov rcx, rax
    call [rax + FILE_DELETE]
    test rax, rax
    jz .done
    mov rax, [rm_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    lea rsi, [s_rm_busy]
    call puts
    add rsp, 40
    ret
.done:
    add rsp, 40
    ret
.nofile:
    lea rsi, [s_rm_nf]
    call puts
    add rsp, 40
    ret
.out:
    add rsp, 40
    ret
.usage:
    lea rsi, [s_rm_use]
    call puts
    add rsp, 40
    ret

section .data

s_rm_use    db `usage: rm PATH\r\n`,0
s_rm_nf     db `rm: no such file or directory\r\n`,0
s_rm_busy   db `rm: could not remove it (directory not empty?)\r\n`,0

section .bss

rm_h         resq 1

%include "uefi.inc"

bits 64
default rel

global cmd_cd

extern argp
extern fs_open
extern resolve_path
extern pathbuf
extern cwd_w
extern guid_fileinfo
extern puts
extern s_home_w

section .text

cmd_cd:
    sub rsp, 40
    mov rsi, [argp]
    cmp word [rsi], 0
    jne .resolve
    lea rsi, [s_home_w]
    mov [cd_path], rsi
    jmp .open
.resolve:
    call resolve_path
    lea rsi, [pathbuf]
    mov [cd_path], rsi
.open:
    mov rcx, [cd_path]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nf
    mov [cd_h], rax

    mov qword [infosz], 512
    mov rcx, [cd_h]
    lea rdx, [guid_fileinfo]
    lea r8, [infosz]
    lea r9, [infobuf]
    mov rax, [cd_h]
    call [rax + FILE_GETINFO]
    mov [cd_st], rax

    mov rax, [cd_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]

    cmp qword [cd_st], 0
    jne .nf
    test byte [infobuf + 72], 0x10
    jz .notdir

    mov rsi, [cd_path]
    lea rdi, [cwd_w]
.cp:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .cp
    add rsp, 40
    ret
.nf:
    lea rsi, [s_cd_nf]
    call puts
    add rsp, 40
    ret
.notdir:
    lea rsi, [s_cd_nd]
    call puts
    add rsp, 40
    ret

section .data

s_cd_nf    db `cd: no such directory\r\n`,0
s_cd_nd    db `cd: not a directory\r\n`,0

section .bss

cd_path      resq 1
cd_h         resq 1
cd_st        resq 1
infosz       resq 1
infobuf      resb 512

%include "uefi.inc"

bits 64
default rel

global cmd_ls

extern conout
extern bs
extern puts
extern argp
extern cwd_w
extern fs_open
extern resolve_path
extern pathbuf
extern s_nl

section .text

cmd_ls:
    sub rsp, 40

    mov rsi, [argp]
    cmp word [rsi], 0
    jne .path
    lea rsi, [cwd_w]
    jmp .open
.path:
    call resolve_path
    lea rsi, [pathbuf]
.open:
    mov rcx, rsi
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .err
    mov [root_ptr], rax

    mov rax, [bs]
    mov ecx, 2
    mov edx, 4096
    lea r8, [dirbuf_ptr]
    call [rax + BS_ALLOCATEPOOL]
    test rax, rax
    jnz .close_err

.rd:
    mov qword [dirsz], 4096
    mov rcx, [root_ptr]
    lea rdx, [dirsz]
    mov r8, [dirbuf_ptr]
    mov rax, [root_ptr]
    call [rax + FILE_READ]
    test rax, rax
    jnz .err
    cmp qword [dirsz], 0
    je .close

    mov rax, [dirbuf_ptr]
    mov [lscur], rax
    add rax, [dirsz]
    mov [lsend], rax

.ent:
    mov r8, [lscur]
    cmp r8, [lsend]
    jae .rd

    mov ax, [r8 + 80]
    cmp ax, '.'
    jne .show
    mov ax, [r8 + 82]
    test ax, ax
    jz .skipent
    cmp ax, '.'
    jne .show
    mov ax, [r8 + 84]
    test ax, ax
    jz .skipent
.show:
    mov rcx, [conout]
    lea rdx, [r8 + 80]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]

    mov r8, [lscur]
    test qword [r8 + 72], 0x10
    jz .file
    lea rsi, [s_slash]
    call puts
.file:
    lea rsi, [s_nl]
    call puts

.skipent:
    mov r8, [lscur]
    add r8, [r8]
    mov [lscur], r8
    jmp .ent

.close:
    mov rcx, [root_ptr]
    mov rax, [root_ptr]
    call [rax + FILE_CLOSE]
    mov rcx, [dirbuf_ptr]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    add rsp, 40
    ret

.close_err:
    mov rcx, [root_ptr]
    mov rax, [root_ptr]
    call [rax + FILE_CLOSE]
.err:
    lea rsi, [s_ls_err]
    call puts
    add rsp, 40
    ret

section .data

s_slash    db `/`,0
s_ls_err   db `ls: could not read the boot volume\r\n`,0

section .bss

root_ptr     resq 1
dirbuf_ptr   resq 1
dirsz        resq 1
lscur        resq 1
lsend        resq 1

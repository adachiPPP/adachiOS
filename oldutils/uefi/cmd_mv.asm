%include "uefi.inc"

bits 64
default rel

global cmd_mv

extern argp
extern split_args
extern a1
extern a2
extern prepare_two
extern args_equal
extern copy_file
extern need_write
extern fs_open
extern pathbuf2
extern puts
extern copy_nf
extern copy_err

section .text

cmd_mv:
    sub rsp, 40
    lea rax, [s_mv_nf]
    mov [copy_nf], rax
    lea rax, [s_mv_wfail]
    mov [copy_err], rax
    call split_args
    mov rax, [a1]
    test rax, rax
    jz .usage
    cmp word [rax], 0
    je .usage
    cmp qword [a2], 0
    je .usage

    call prepare_two
    test eax, eax
    jz .out
    lea rsi, [pathbuf2]
    call need_write
    test eax, eax
    jz .out
    call args_equal
    test eax, eax
    jnz .same
    call copy_file
    test rax, rax
    jnz .out

    mov rcx, [a1]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .out
    mov rcx, rax
    call [rax + FILE_DELETE]
    test rax, rax
    jz .out
    lea rsi, [s_mv_rm]
    call puts
.out:
    add rsp, 40
    ret
.same:
    lea rsi, [s_mv_same]
    call puts
    add rsp, 40
    ret
.usage:
    lea rsi, [s_mv_use]
    call puts
    add rsp, 40
    ret

section .data

s_mv_use    db `usage: mv SRC DST\r\n`,0
s_mv_same   db `mv: source and destination are the same\r\n`,0
s_mv_nf     db `mv: no such file\r\n`,0
s_mv_wfail  db `mv: could not move the file\r\n`,0
s_mv_rm     db `mv: copied, but could not remove the source\r\n`,0

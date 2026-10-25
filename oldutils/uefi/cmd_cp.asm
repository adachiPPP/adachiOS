%include "uefi.inc"

bits 64
default rel

global cmd_cp

extern argp
extern split_args
extern a1
extern a2
extern prepare_two
extern args_equal
extern copy_file
extern puts
extern copy_nf
extern copy_err

section .text

cmd_cp:
    sub rsp, 40
    lea rax, [s_cp_nf]
    mov [copy_nf], rax
    lea rax, [s_cp_wfail]
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
    call args_equal
    test eax, eax
    jnz .same
    call copy_file
    add rsp, 40
    ret
.out:
    add rsp, 40
    ret
.same:
    lea rsi, [s_cp_same]
    call puts
    add rsp, 40
    ret
.usage:
    lea rsi, [s_cp_use]
    call puts
    add rsp, 40
    ret

section .data

s_cp_use    db `usage: cp SRC DST\r\n`,0
s_cp_nf     db `cp: no such file\r\n`,0
s_cp_same   db `cp: source and destination are the same\r\n`,0
s_cp_wfail  db `cp: could not write the destination\r\n`,0

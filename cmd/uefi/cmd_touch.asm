%include "uefi.inc"

bits 64
default rel

global cmd_touch

extern argp
extern split_args
extern a1
extern resolve_path
extern pathbuf
extern need_write
extern fs_open_x
extern puts

section .text

cmd_touch:
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
    mov rdx, 0x8000000000000003
    xor r8d, r8d
    call fs_open_x
    test rax, rax
    jz .fail
    mov rcx, rax
    call [rax + FILE_CLOSE]
    add rsp, 40
    ret
.fail:
    lea rsi, [s_touch_f]
    call puts
    add rsp, 40
    ret
.out:
    add rsp, 40
    ret
.usage:
    lea rsi, [s_touch_use]
    call puts
    add rsp, 40
    ret

section .data

s_touch_use db `usage: touch FILE\r\n`,0
s_touch_f   db `touch: could not create the file\r\n`,0

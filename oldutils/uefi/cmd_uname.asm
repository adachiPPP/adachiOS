%include "uefi.inc"

bits 64
default rel

global cmd_uname

extern puts

section .text

cmd_uname:
    sub rsp, 40
    lea rsi, [s_uname]
    call puts
    add rsp, 40
    ret

section .data

s_uname db `adachiOS 0.5 x86_64 UEFI\r\n`,0

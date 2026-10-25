%include "uefi.inc"

bits 64
default rel

global cmd_meow

extern puts

section .text

cmd_meow:
    sub rsp, 40
    lea rsi, [s_meow]
    call puts
    add rsp, 40
    ret

section .data

s_meow db `meow :3\r\n`,0

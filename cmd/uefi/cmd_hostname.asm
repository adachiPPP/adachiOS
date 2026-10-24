%include "uefi.inc"

bits 64
default rel

global cmd_hostname

extern puts

section .text

cmd_hostname:
    sub rsp, 40
    lea rsi, [s_hostname]
    call puts
    add rsp, 40
    ret

section .data

s_hostname db `adachios\r\n`,0

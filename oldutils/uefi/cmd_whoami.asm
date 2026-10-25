%include "uefi.inc"

bits 64
default rel

global cmd_whoami

extern puts

section .text

cmd_whoami:
    sub rsp, 40
    lea rsi, [s_whoami]
    call puts
    add rsp, 40
    ret

section .data

s_whoami db `adachi\r\n`,0

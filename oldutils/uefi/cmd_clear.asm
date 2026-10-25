%include "uefi.inc"

bits 64
default rel

global cmd_clear

extern con_clear

section .text

cmd_clear:
    sub rsp, 40
    call con_clear
    add rsp, 40
    ret

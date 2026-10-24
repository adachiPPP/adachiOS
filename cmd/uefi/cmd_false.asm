%include "uefi.inc"

bits 64
default rel

global cmd_false

section .text

cmd_false:
    sub rsp, 40
    mov eax, 1
    add rsp, 40
    ret

%include "uefi.inc"

bits 64
default rel

global cmd_true

section .text

cmd_true:
    sub rsp, 40
    add rsp, 40
    ret

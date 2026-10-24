%include "uefi.inc"

bits 64
default rel

global cmd_clear

extern conout

section .text

cmd_clear:
    sub rsp, 40
    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]
    add rsp, 40
    ret

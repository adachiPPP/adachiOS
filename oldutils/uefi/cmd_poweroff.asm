%include "uefi.inc"

bits 64
default rel

global cmd_poweroff

extern rt

section .text

cmd_poweroff:
    sub rsp, 40
    mov rax, [rt]
    mov ecx, 2
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call [rax + RT_RESETSYSTEM]
    add rsp, 40
    ret

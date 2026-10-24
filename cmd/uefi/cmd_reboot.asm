%include "uefi.inc"

bits 64
default rel

global cmd_reboot

extern rt

section .text

cmd_reboot:
    sub rsp, 40
    mov rax, [rt]
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call [rax + RT_RESETSYSTEM]
    add rsp, 40
    ret

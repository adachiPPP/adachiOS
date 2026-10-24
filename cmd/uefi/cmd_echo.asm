%include "uefi.inc"

bits 64
default rel

global cmd_echo

extern conout
extern argp
extern puts
extern s_nl

section .text

cmd_echo:
    sub rsp, 40
    mov rcx, [conout]
    mov rdx, [argp]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    lea rsi, [s_nl]
    call puts
    add rsp, 40
    ret

%include "uefi.inc"

bits 64
default rel

global cmd_echo

extern argp
extern puts_w
extern puts
extern s_nl

section .text

cmd_echo:
    sub rsp, 40
    mov rsi, [argp]
    call puts_w
    lea rsi, [s_nl]
    call puts
    add rsp, 40
    ret

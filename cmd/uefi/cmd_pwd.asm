%include "uefi.inc"

bits 64
default rel

global cmd_pwd

extern puts_w
extern cwd_w
extern puts
extern s_nl

section .text

cmd_pwd:
    sub rsp, 40
    lea rsi, [cwd_w]
    call puts_w
    lea rsi, [s_nl]
    call puts
    add rsp, 40
    ret

section .data

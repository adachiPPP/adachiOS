%include "uefi.inc"

bits 64
default rel

global cmd_adctl

extern argp
extern puts
extern rt

section .text

cmd_adctl:
    sub rsp, 40
    mov rsi, [argp]
.skipws:
    cmp word [rsi], 32
    je .ws
    cmp word [rsi], 9
    je .ws
    jmp .token
.ws:
    add rsi, 2
    jmp .skipws
.token:
    mov ax, [rsi]
    cmp ax, 'r'
    je .maybe_reboot
    cmp ax, 'p'
    je .poweroff
    cmp ax, 's'
    je .status
    cmp ax, 'h'
    je .usage
    cmp ax, 0
    je .usage
    jmp .usage

.maybe_reboot:
    cmp word [rsi + 2], 'e'
    jne .usage
    xor rcx, rcx
    xor rdx, rdx
    xor r8d, r8d
    xor r9d, r9d
    mov rax, [rt]
    call [rax + RT_RESETSYSTEM]
    jmp .done

.poweroff:
    mov rax, [rt]
    mov rcx, 2
    xor rdx, rdx
    xor r8d, r8d
    xor r9d, r9d
    call [rax + RT_RESETSYSTEM]
    jmp .done

.status:
    lea rsi, [s_status]
    call puts
    jmp .done

.usage:
    lea rsi, [s_help]
    call puts

.done:
    add rsp, 40
    ret

section .data

s_help db `adctl: status\r\n  reboot\r\n  poweroff\r\n`,0
s_status db `adctl status: system running\r\n`,0

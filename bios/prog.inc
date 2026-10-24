
bits 16
org 0
%include "bios/defs.inc"
%ifndef SELF_SEG
%define SELF_SEG PROG_SEG
%endif

start:
    cld
    mov al, [STATE_DRIVE]
    mov [drive], al
    mov al, [STATE_ROOT]
    mov [root_mode], al
    mov ax, [STATE_CWDC]
    mov [cwd_cluster], ax

    mov si, STATE_CWDP
    mov di, cwd_path
    mov cx, 64
.cpcwd:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jz .args
    dec cx
    jnz .cpcwd
    mov byte [di - 1], 0

.args:
    mov si, STATE_ARGS
    mov [argp], si
    call cmd_main

    mov al, [drive]
    mov [STATE_DRIVE], al
    mov al, [root_mode]
    mov [STATE_ROOT], al
    mov ax, [cwd_cluster]
    mov [STATE_CWDC], ax

    mov si, cwd_path
    mov di, STATE_CWDP
    mov cx, 64
.cpout:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    test al, al
    jz .done
    dec cx
    jnz .cpout
    mov byte [di - 1], 0
.done:
    retf

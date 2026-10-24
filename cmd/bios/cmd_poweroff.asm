%include "bios/prog.inc"

cmd_main:
    mov ax, 0x5301
    xor bx, bx
    int 0x15
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    mov ax, 0x2000
    mov dx, 0x0604
    out dx, ax
    mov dx, 0xB004
    out dx, ax
    mov si, s_off
    call puts
.h:
    cli
    hlt
    jmp .h

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

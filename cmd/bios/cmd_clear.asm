%include "bios/prog.inc"

cmd_main:
    mov ax, 0x0003
    int 0x10
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

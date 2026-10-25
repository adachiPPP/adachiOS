%include "bios/prog.inc"

cmd_main:
    mov ax, 1
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

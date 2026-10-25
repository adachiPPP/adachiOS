%include "bios/prog.inc"

cmd_main:
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

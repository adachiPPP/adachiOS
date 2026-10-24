%include "bios/prog.inc"

cmd_main:
    mov al, 0xFE
    out 0x64, al
    jmp 0xFFFF:0x0000

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

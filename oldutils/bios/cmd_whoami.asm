%include "bios/prog.inc"

cmd_main:
    mov si, s_bwhoami
    call puts
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

%include "bios/prog.inc"

cmd_main:
    mov si, s_bhostname
    call puts
    xor ax, ax
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

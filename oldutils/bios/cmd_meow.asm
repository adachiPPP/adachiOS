%include "bios/prog.inc"

cmd_main:
    mov si, s_meow
    call puts
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

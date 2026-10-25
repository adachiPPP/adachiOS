%include "bios/prog.inc"

cmd_main:
    mov si, [argp]
    test si, si
    jz .nl
    call puts
.nl:
    call newline
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

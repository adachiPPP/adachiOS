%include "bios/prog.inc"

cmd_main:
    mov si, cwd_path
    call puts
    call newline
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

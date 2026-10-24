bits 16
org 0

start:
    call cmd_flappy
    retf

%include "cmd/bios/flappy.asm"
%include "cmd/bios/cmd_strings.inc"
%include "bios/lib.asm"

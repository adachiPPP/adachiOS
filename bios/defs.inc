
%ifndef BIOS_DEFS_INC
%define BIOS_DEFS_INC

ROOT_LBA      equ 19
ROOT_SECT     equ 14
ROOT_ENT      equ 224
DATA_LBA      equ 33
MAXLINE       equ 96
DIRMAX        equ 14

PROG_SEG      equ 0x2000
PROG_STACK    equ 0xFF00

SCR_SEG       equ 0x3000
SCR_OFF       equ 0

STATE_DRIVE   equ 0xFE00
STATE_ROOT    equ 0xFE01
STATE_CWDC    equ 0xFE02
STATE_CWDP    equ 0xFE04
STATE_ARGS    equ 0xFE44
STATE_ARGS_MAX equ 96

%endif

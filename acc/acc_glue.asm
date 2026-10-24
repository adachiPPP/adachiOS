bits 64
default rel

global c_fs_open
global c_fs_open_x
global c_need_write

extern fs_open
extern fs_open_x
extern need_write

section .text

%macro SAVE 0
    push rbx
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40
%endmacro

%macro RESTORE 0
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    pop rbx
%endmacro

c_fs_open:
    SAVE
    call fs_open
    RESTORE
    ret

c_fs_open_x:
    SAVE
    call fs_open_x
    RESTORE
    ret

c_need_write:
    SAVE
    call need_write
    RESTORE
    ret

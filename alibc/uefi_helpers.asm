bits 64
default rel

%include "uefi.inc"

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

global c_fs_open
global c_fs_open_x
global c_need_write
global c_read_file
global c_write_file
global c_clear
global c_get_argp
global c_sleep_seconds
global c_delete_file
global c_reset_system

extern fs_open
extern fs_open_x
extern need_write
extern con_clear
extern rt
extern bs
extern g_argp

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

c_read_file:
    SAVE
    mov r12, [rbp + 16]
    mov r13, [rbp + 24]
    mov r14, [rbp + 32]
    lea rdi, [clib_buf]
    cmp byte [r12], '/'
    je .copy_path
    cmp byte [r12], 92
    je .copy_path
    lea rsi, [cwd_w]
.cwd_copy:
    mov ax, [rsi]
    test ax, ax
    jz .cwd_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .cwd_copy
.cwd_done:
    mov ax, [rdi - 2]
    cmp ax, 92
    je .copy_path
    mov word [rdi], 92
    add rdi, 2
.copy_path:
    xor rsi, rsi
.char_loop:
    movzx ax, byte [r12 + rsi]
    test ax, ax
    jz .done_path
    cmp ax, '/'
    jne .not_slash
    mov ax, 92
.not_slash:
    mov [rdi], ax
    inc rsi
    add rdi, 2
    jmp .char_loop
.done_path:
    mov word [rdi], 0
    lea rcx, [clib_buf]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .read_fail
    mov [clib_handle], rax
    xor r15, r15
.read_loop:
    mov rax, r14
    sub rax, r15
    jle .read_done
    mov [clib_size], rax
    mov rax, [clib_handle]
    mov rcx, rax
    lea rdx, [clib_size]
    lea r8, [r13 + r15]
    call [rax + FILE_READ]
    test rax, rax
    jnz .read_fail
    mov rax, [clib_size]
    test rax, rax
    jz .read_done
    add r15, rax
    jmp .read_loop
.read_done:
    mov rax, [clib_handle]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    mov rax, r15
    RESTORE
    ret
.read_fail:
    mov rax, -1
    RESTORE
    ret

c_write_file:
    SAVE
    mov r12, [rbp + 16]
    mov r13, [rbp + 24]
    mov r14, [rbp + 32]
    lea rdi, [clib_buf]
    cmp byte [r12], '/'
    je .wcopy_path
    cmp byte [r12], 92
    je .wcopy_path
    lea rsi, [cwd_w]
.wcwd_copy:
    mov ax, [rsi]
    test ax, ax
    jz .wcwd_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .wcwd_copy
.wcwd_done:
    mov ax, [rdi - 2]
    cmp ax, 92
    je .wcopy_path
    mov word [rdi], 92
    add rdi, 2
.wcopy_path:
    xor rsi, rsi
.wchar_loop:
    movzx ax, byte [r12 + rsi]
    test ax, ax
    jz .wdone_path
    cmp ax, '/'
    jne .wnot_slash
    mov ax, 92
.wnot_slash:
    mov [rdi], ax
    inc rsi
    add rdi, 2
    jmp .wchar_loop
.wdone_path:
    mov word [rdi], 0
    call c_need_write
    test rax, rax
    jz .write_fail
    lea rcx, [clib_buf]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .no_delete
    mov rcx, rax
    mov rax, rcx
    call [rax + FILE_DELETE]
.no_delete:
    lea rcx, [clib_buf]
    mov rdx, 0x8000000000000003
    xor r8d, r8d
    call fs_open_x
    test rax, rax
    jz .write_fail
    mov r15, rax
    ; write_size = r14
    mov qword [clib_size], r14
    mov rax, r15
    mov rcx, r15
    lea rdx, [clib_size]
    mov r8, r13
    call [rax + FILE_WRITE]
    cmp rax, 0
    jne .write_free
    mov rax, r15
    mov rcx, rax
    call [rax + FILE_CLOSE]
    xor rax, rax
    RESTORE
    ret
.write_free:
    mov rax, r15
    mov rcx, rax
    call [rax + FILE_CLOSE]
.write_fail:
    mov rax, -1
    RESTORE
    ret

c_clear:
    SAVE
    call con_clear
    RESTORE
    ret

c_get_argp:
    SAVE
    mov rax, [g_argp]
    RESTORE
    ret

c_sleep_seconds:
    SAVE
    mov r12, [rbp + 16]
.sleep_loop:
    test r12, r12
    jle .sleep_done
    mov rax, [bs]
    mov ecx, 1000000
    xor edx, edx
    call [rax + BS_STALL]
    dec r12
    jmp .sleep_loop
.sleep_done:
    RESTORE
    ret

c_delete_file:
    SAVE
    mov r12, [rbp + 16]
    lea rdi, [clib_buf]
    cmp byte [r12], '/'
    je .dpath
    lea rsi, [cwd_w]
.dcwc_copy:
    mov ax, [rsi]
    test ax, ax
    jz .dcwd_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .dcwc_copy
.dcdir?:
    nop
.dcwc_copy_loop:
    jmp .dcwc_copy
.dcwc_dummy:
    jmp .dcwc_copy
.dcwc_copy2:
    jmp .dcwc_copy
.dcwc_copy3:
    jmp .dcwc_copy
.dcwd_done:
    mov ax, [rdi - 2]
    cmp ax, 92
    je .dpath
    mov word [rdi], 92
    add rdi, 2
.dpath:
    xor rsi, rsi
.dchar_loop:
    movzx ax, byte [r12 + rsi]
    test ax, ax
    jz .ddone_path
    cmp ax, '/'
    jne .dnot_slash
    mov ax, 92
.dnot_slash:
    mov [rdi], ax
    inc rsi
    add rdi, 2
    jmp .dchar_loop
.ddone_path:
    mov word [rdi], 0
    lea rcx, [clib_buf]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .dwrite_fail
    mov rcx, rax
    mov rax, rcx
    call [rax + FILE_DELETE]
.dwrite_fail:
    xor rax, rax
    RESTORE
    ret

c_reset_system:
    SAVE
    mov r12, [rbp + 16]
    mov rax, [rt]
    mov rcx, r12
    xor rdx, rdx
    xor r8d, r8d
    xor r9d, r9d
    call [rax + RT_RESETSYSTEM]
    RESTORE
    ret

section .bss

clib_buf resw 260
clib_handle resq 1
clib_size resq 1

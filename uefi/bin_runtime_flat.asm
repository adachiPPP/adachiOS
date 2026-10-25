
%include "uefi.inc"

bits 64
default rel

%ifndef CMD
%error "build with -DCMD=cmd_xxx"
%endif

section .text

bin_entry:
    jmp short bin_start
    db 'A', 'D', 'B', '1'
    times 12 db 0
bin_start:
    sub rsp, 40
    mov [ctx_ptr], rcx

    mov rax, [rcx + FCTX_SYSTAB]
    mov [sys_table], rax
    mov rdx, [rcx + FCTX_IMAGE]
    mov [image_handle], rdx
    mov rdx, [rax + ST_CONOUT]
    mov [conout], rdx
    mov rdx, [rax + ST_CONIN]
    mov [conin], rdx
    mov rdx, [rax + ST_RUNTIME]
    mov [rt], rdx
    mov rdx, [rax + ST_BOOTSERVICES]
    mov [bs], rdx

    mov rax, [rcx + FCTX_DEVICE]
    mov [fs_device], rax

    mov rax, [rcx + FCTX_PUTC]
    mov [con_putc_hook], rax
    mov rax, [rcx + FCTX_CLEAR]
    mov [con_clear_hook], rax
    mov rax, [rcx + FCTX_SETCURSOR]
    mov [con_set_cursor_hook], rax
    mov rax, [rcx + FCTX_COLS]
    mov [text_cols], rax
    mov rax, [rcx + FCTX_ROWS]
    mov [text_rows], rax

    mov rsi, [rcx + FCTX_CWD]
    test rsi, rsi
    jz .nocwd
    lea rdi, [cwd_w]
    mov ecx, 259
    call copy_w
    jmp .args
.nocwd:
    lea rsi, [s_home_w]
    lea rdi, [cwd_w]
    mov ecx, 259
    call copy_w
.args:
    mov rax, [ctx_ptr]
    mov rax, [rax + FCTX_ARGS]
    test rax, rax
    jnz .setargs
    lea rax, [empty_w]
.setargs:
    mov [argp], rax
    mov [g_argp], rax

    mov rax, [ctx_ptr]
    mov al, [rax + FCTX_ROOT]
    mov [root_mode], al

    call CMD

    mov rax, [ctx_ptr]
    test rax, rax
    jz .done
    mov rdi, [rax + FCTX_CWD]
    test rdi, rdi
    jz .done
    lea rsi, [cwd_w]
    mov ecx, 260
    call copy_w
.done:
    add rsp, 40
    ret

copy_w:
.l:
    test ecx, ecx
    jz .end
    mov ax, [rsi]
    test ax, ax
    jz .end
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    dec ecx
    jmp .l
.end:
    mov word [rdi], 0
    ret

section .data

empty_w   dw 0

section .bss

image_handle resq 1
sys_table    resq 1
conout       resq 1
conin        resq 1
rt           resq 1
bs           resq 1
ctx_ptr      resq 1
cwd_w        resw 260
argp         resq 1
g_argp       resq 1
root_mode    resb 1

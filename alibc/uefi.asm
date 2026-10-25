
%include "uefi.inc"
bits 64
default rel

section .text

global c_putchar
global c_puts
global c_print_int
global c_printf
global c_strlen
global c_strcmp
global c_strcpy
global c_memcpy
global c_memset
global c_atoi
global c_malloc
global c_free
global c_exit

extern puts
extern print_dec
extern conout

c_putchar:
    push rbp
    mov rbp, rsp
    mov rax, [rbp + 16]
    mov [chbuf], al
    mov byte [chbuf + 1], 0
    lea rsi, [chbuf]
    call puts
    pop rbp
    ret

c_puts:
    push rbp
    mov rbp, rsp
    mov rsi, [rbp + 16]
    call puts
    pop rbp
    ret

c_print_int:
    push rbp
    mov rbp, rsp
    mov rax, [rbp + 16]
    call print_signed
    pop rbp
    ret

print_signed:
    test rax, rax
    jns .ps_pos
    push rax
    mov byte [chbuf], '-'
    mov byte [chbuf + 1], 0
    lea rsi, [chbuf]
    call puts
    pop rax
    neg rax
.ps_pos:
    jmp print_dec

c_printf:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    sub rsp, 8
    mov r12, [rbp + 16]
    lea r13, [rbp + 24]
.loop:
    mov al, [r12]
    test al, al
    jz .done
    cmp al, '%'
    jne .plain
    inc r12
    mov al, [r12]
    cmp al, 'd'
    je .dec
    cmp al, 'u'
    je .udec
    cmp al, 's'
    je .str
    cmp al, 'c'
    je .chr
    cmp al, 'x'
    je .hex
    cmp al, '%'
    je .plain
    jmp .next
.dec:
    mov rax, [r13]
    add r13, 8
    call print_signed
    jmp .next
.udec:
    mov rax, [r13]
    add r13, 8
    call print_dec
    jmp .next
.str:
    mov rsi, [r13]
    add r13, 8
    call puts
    jmp .next
.chr:
    mov al, [r13]
    add r13, 8
    mov [chbuf], al
    mov byte [chbuf + 1], 0
    lea rsi, [chbuf]
    call puts
    jmp .next
.hex:
    mov rax, [r13]
    add r13, 8
    call print_hex
    jmp .next
.plain:
    mov [chbuf], al
    mov byte [chbuf + 1], 0
    lea rsi, [chbuf]
    call puts
.next:
    inc r12
    jmp .loop
.done:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

print_hex:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    sub rsp, 8
    lea rdi, [hexbuf + 16]
    mov byte [rdi], 0
    mov rcx, 16
.ph_loop:
    mov rdx, rax
    and rdx, 15
    cmp dl, 10
    jb .ph_digit
    add dl, 'a' - 10
    jmp .ph_store
.ph_digit:
    add dl, '0'
.ph_store:
    dec rdi
    mov [rdi], dl
    shr rax, 4
    dec rcx
    jnz .ph_loop
    lea rsi, [hexbuf]
.ph_skip:
    cmp byte [rsi], '0'
    jne .ph_print
    cmp byte [rsi + 1], 0
    je .ph_print
    inc rsi
    jmp .ph_skip
.ph_print:
    call puts
    add rsp, 8
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

c_strlen:
    push rbp
    mov rbp, rsp
    mov rsi, [rbp + 16]
    xor rax, rax
.sl_loop:
    cmp byte [rsi], 0
    je .sl_done
    inc rsi
    inc rax
    jmp .sl_loop
.sl_done:
    pop rbp
    ret

c_strcmp:
    push rbp
    mov rbp, rsp
    mov rsi, [rbp + 16]
    mov rdi, [rbp + 24]
.sc_loop:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .sc_diff
    test al, al
    jz .sc_eq
    inc rsi
    inc rdi
    jmp .sc_loop
.sc_diff:
    movzx eax, al
    movzx edx, dl
    sub rax, rdx
    pop rbp
    ret
.sc_eq:
    xor rax, rax
    pop rbp
    ret

c_strcpy:
    push rbp
    mov rbp, rsp
    mov rdi, [rbp + 16]
    mov rsi, [rbp + 24]
.scp_loop:
    lodsb
    stosb
    test al, al
    jnz .scp_loop
    mov rax, [rbp + 16]
    pop rbp
    ret

c_memcpy:
    push rbp
    mov rbp, rsp
    mov rdi, [rbp + 16]
    mov rsi, [rbp + 24]
    mov rcx, [rbp + 32]
    rep movsb
    mov rax, [rbp + 16]
    pop rbp
    ret

c_memset:
    push rbp
    mov rbp, rsp
    mov rdi, [rbp + 16]
    mov al, [rbp + 24]
    mov rcx, [rbp + 32]
    rep stosb
    mov rax, [rbp + 16]
    pop rbp
    ret

c_atoi:
    push rbp
    mov rbp, rsp
    mov rsi, [rbp + 16]
    xor rax, rax
    xor r8, r8
.ai_skip:
    mov dl, [rsi]
    cmp dl, ' '
    je .ai_skip_one
    cmp dl, 9
    jne .ai_sign
.ai_skip_one:
    inc rsi
    jmp .ai_skip
.ai_sign:
    cmp dl, '-'
    jne .ai_plus
    mov r8, 1
    inc rsi
    jmp .ai_loop
.ai_plus:
    cmp dl, '+'
    jne .ai_loop
    inc rsi
.ai_loop:
    movzx rdx, byte [rsi]
    sub rdx, '0'
    cmp rdx, 9
    ja .ai_done
    imul rax, rax, 10
    add rax, rdx
    inc rsi
    jmp .ai_loop
.ai_done:
    test r8, r8
    jz .ai_ret
    neg rax
.ai_ret:
    pop rbp
    ret

c_malloc:
    push rbp
    mov rbp, rsp
    mov rax, [heap_ptr]
    test rax, rax
    jnz .m_have
    lea rax, [heap]
.m_have:
    mov rbx, rax
    add rax, [rbp + 16]
    add rax, 7
    and rax, -8
    lea rcx, [heap_end]
    cmp rax, rcx
    ja .m_fail
    mov [heap_ptr], rax
    mov rax, rbx
    pop rbp
    ret
.m_fail:
    xor rax, rax
    pop rbp
    ret

c_free:
    ret

c_exit:
    ret

section .data

chbuf    db 0, 0
hexbuf   times 20 db 0

section .bss

heap_ptr resq 1
heap     resb 65536
heap_end:

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

section .text

global c_read_file
global c_write_file
global c_fs_open
global c_fs_open_x
global c_need_write

extern fs_open
extern fs_open_x
extern need_write
extern cwd_w

section .text

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
    lea rdi, [read_wbuf]
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
    lea rcx, [read_wbuf]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .read_fail
    mov [read_handle], rax
    xor r15d, r15d
.read_loop:
    mov eax, r14d
    sub eax, r15d
    jle .read_done
    movsxd rax, r15d
    lea r8, [r13 + rax]
    mov rax, r14
    sub rax, r15
    mov [read_size], rax
    mov rax, [read_handle]
    mov rcx, rax
    lea rdx, [read_size]
    lea r8, [r13 + r15]
    call [rax + FILE_READ]
    test rax, rax
    jnz .read_fail
    mov rax, [read_size]
    test rax, rax
    jz .read_done
    add r15, rax
    jmp .read_loop
.read_done:
    mov rax, [read_handle]
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
    lea rdi, [read_wbuf]
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
    lea rcx, [read_wbuf]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .no_delete
    mov rcx, rax
    mov rax, rcx
    call [rax + FILE_DELETE]
.no_delete:
    lea rcx, [read_wbuf]
    mov rdx, 0x8000000000000003
    xor r8d, r8d
    call fs_open_x
    test rax, rax
    jz .write_fail
    mov r15, rax
    mov [write_size], r14
    mov rax, r15
    mov rcx, r15
    lea rdx, [write_size]
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

section .bss
read_wbuf resw 260
read_handle resq 1
read_size resq 1
write_size resq 1

global c_delete_file
global c_sleep_seconds

extern bs

c_delete_file:
    SAVE
    mov r12, [rbp + 16]
    ; build wide path (reuse read_wbuf)
    lea rdi, [read_wbuf]
    cmp byte [r12], '/'
    je .dpath
    cmp byte [r12], 92
    je .dpath
    lea rsi, [cwd_w]
.dcwd_copy:
    mov ax, [rsi]
    test ax, ax
    jz .dcwd_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .dcwd_copy
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
    lea rcx, [read_wbuf]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .dwrite_fail
    mov rcx, rax
    mov rax, rcx
    call [rax + FILE_DELETE]
    mov rcx, rax
    mov rax, rcx
    ; close old handle after delete best-effort
    ; rax currently delete status? keep handle is already deleted
    ; no further close needed
.dwrite_fail:
    xor rax, rax
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

global c_clear
extern con_clear
c_clear:
    SAVE
    call con_clear
    RESTORE
    ret

global c_get_argp
c_get_argp:
    SAVE
    mov rax, [argp]
    RESTORE
    ret

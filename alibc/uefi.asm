
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

%include "alibc/uefi_helpers.asm"

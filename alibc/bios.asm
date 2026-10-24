
bits 16

section .text

c_putchar:
    push bp
    mov bp, sp
    mov al, [bp + 4]
    call putc
    pop bp
    ret

c_puts:
    push bp
    mov bp, sp
    mov si, [bp + 4]
    call puts
    pop bp
    ret

c_print_int:
    push bp
    mov bp, sp
    mov ax, [bp + 4]
    call print_signed
    pop bp
    ret

print_signed:
    test ax, ax
    jns .ps_pos
    push ax
    mov al, '-'
    call putc
    pop ax
    neg ax
.ps_pos:
    jmp print_dec

c_printf:
    push bp
    mov bp, sp
    push bx
    push di
    mov bx, [bp + 4]
    mov di, bp
    add di, 6
.pf_loop:
    mov al, [bx]
    test al, al
    jz .pf_done
    cmp al, '%'
    jne .pf_plain
    inc bx
    mov al, [bx]
    cmp al, 'd'
    je .pf_dec
    cmp al, 'u'
    je .pf_udec
    cmp al, 's'
    je .pf_str
    cmp al, 'c'
    je .pf_chr
    cmp al, 'x'
    je .pf_hex
    cmp al, '%'
    je .pf_plain
    jmp .pf_next
.pf_dec:
    mov ax, [di]
    add di, 2
    call print_signed
    jmp .pf_next
.pf_udec:
    mov ax, [di]
    add di, 2
    call print_dec
    jmp .pf_next
.pf_str:
    mov si, [di]
    add di, 2
    call puts
    jmp .pf_next
.pf_chr:
    mov al, [di]
    add di, 2
    call putc
    jmp .pf_next
.pf_hex:
    mov ax, [di]
    add di, 2
    call print_hex
    jmp .pf_next
.pf_plain:
    call putc
.pf_next:
    inc bx
    jmp .pf_loop
.pf_done:
    pop di
    pop bx
    pop bp
    ret

print_hex:
    push ax
    push bx
    push cx
    push dx
    push di
    mov bx, ax
    lea di, [hexbuf]
    mov cx, 4
.ph_loop:
    rol bx, 4
    mov al, bl
    and al, 15
    cmp al, 10
    jb .ph_digit
    add al, 'a' - 10
    jmp .ph_store
.ph_digit:
    add al, '0'
.ph_store:
    stosb
    loop .ph_loop
    mov byte [di], 0
    mov si, hexbuf
    call puts
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

c_strlen:
    push bp
    mov bp, sp
    mov si, [bp + 4]
    xor ax, ax
.sl_loop:
    cmp byte [si], 0
    je .sl_done
    inc si
    inc ax
    jmp .sl_loop
.sl_done:
    pop bp
    ret

c_strcmp:
    push bp
    mov bp, sp
    mov si, [bp + 4]
    mov di, [bp + 6]
.sc_loop:
    mov al, [si]
    mov dl, [di]
    cmp al, dl
    jne .sc_diff
    test al, al
    jz .sc_eq
    inc si
    inc di
    jmp .sc_loop
.sc_diff:
    movzx ax, al
    movzx dx, dl
    sub ax, dx
    pop bp
    ret
.sc_eq:
    xor ax, ax
    pop bp
    ret

c_strcpy:
    push bp
    mov bp, sp
    mov di, [bp + 4]
    mov si, [bp + 6]
.scp_loop:
    lodsb
    stosb
    test al, al
    jnz .scp_loop
    mov ax, [bp + 4]
    pop bp
    ret

c_memcpy:
    push bp
    mov bp, sp
    mov di, [bp + 4]
    mov si, [bp + 6]
    mov cx, [bp + 8]
    rep movsb
    mov ax, [bp + 4]
    pop bp
    ret

c_memset:
    push bp
    mov bp, sp
    mov di, [bp + 4]
    mov al, [bp + 6]
    mov cx, [bp + 8]
    rep stosb
    mov ax, [bp + 4]
    pop bp
    ret

c_atoi:
    push bp
    mov bp, sp
    push bx
    mov si, [bp + 4]
    xor ax, ax
    xor bx, bx
.ai_skip:
    mov dl, [si]
    cmp dl, ' '
    je .ai_skip_one
    cmp dl, 9
    jne .ai_sign
.ai_skip_one:
    inc si
    jmp .ai_skip
.ai_sign:
    cmp dl, '-'
    jne .ai_plus
    mov bx, 1
    inc si
    jmp .ai_loop
.ai_plus:
    cmp dl, '+'
    jne .ai_loop
    inc si
.ai_loop:
    movzx cx, byte [si]
    sub cx, '0'
    cmp cx, 9
    ja .ai_done
    mov dx, 10
    mul dx
    add ax, cx
    inc si
    jmp .ai_loop
.ai_done:
    test bx, bx
    jz .ai_ret
    neg ax
.ai_ret:
    pop bx
    pop bp
    ret

c_malloc:
    push bp
    mov bp, sp
    push bx
    mov ax, [heap_ptr]
    test ax, ax
    jnz .m_have
    mov ax, heap
.m_have:
    mov bx, ax
    add ax, [bp + 4]
    jc .m_fail
    add ax, 1
    and ax, 0xFFFE
    cmp ax, heap_end
    ja .m_fail
    mov [heap_ptr], ax
    mov ax, bx
    pop bx
    pop bp
    ret
.m_fail:
    xor ax, ax
    pop bx
    pop bp
    ret

c_free:
    ret

c_exit:
    ret

section .data

hexbuf   db 0, 0, 0, 0, 0

section .bss

heap_ptr resw 1
heap     resb 16384
heap_end:

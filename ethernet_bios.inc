%ifndef ETHERNET_BIOS
%define ETHERNET_BIOS

    global cmd_net, cmd_ping

cmd_net:
    mov si, s_net_head
    call puts
    mov ax, [np_dev]
    test ax, ax
    jz .no_dev
    mov bx, ax
    lea bx, [bx + net_mac]
    mov ax, bx
    call net_print_mac
    mov si, s_nl
    call puts
    xor eax, eax
    ret
.no_dev:
    mov si, s_net_no_dev
    call puts
    xor eax, eax
    ret

cmd_ping:
    push si
    mov ax, [np_dev]
    test ax, ax
    jz .no_dev
    mov si, [argp]
    test si, si
    jz .done
    cmp byte [si], 0
    je .done
    call puts
    mov si, s_nl
    call puts
    jmp .done
.no_dev:
    mov si, s_net_no_dev
    call puts
.done:
    pop si
    xor ax, ax
    ret

; ---- helpers needed (shared with uefi inc only structurally; here implemented for 32-bit) ----
net_print_mac:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, ax
    mov cx, 6
.Lpm:
    mov al, [bx]
    call net_print_hex_byte
    mov dl, '.'
    call putc_char
    inc bx
    dec cx
    jnz .Lpm
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

net_print_hex_byte:
    push ax
    push bx
    movzx bx, byte [eax]
    mov cl, bl
    shr cl, 4
    and cl, 0xF
    add cl, '0'
    cmp cl, '9'
    jbe .Lok1
    add cl, 'A' - '0' - 10
.Lok1:
    mov al, cl
    call putc_char
    mov cl, bl
    and cl, 0xF
    add cl, '0'
    cmp cl, '9'
    jbe .Lok2
    add cl, 'A' - '0' - 10
.Lok2:
    mov al, cl
    call putc_char
    pop bx
    pop ax
    ret

putc_char:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, [stdout]
    mov ax, 1
    mov di, bx
    call [di]
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

net_print_addr:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    movzx ax, word [esp + 20]
    mov bx, 10
    xor cx, cx
.Loct:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .Loct
    pop ax
    add al, '0'
    call putc_char
    dec cx
    jz .Ldone
    mov al, '.'
    call putc_char
    pop ax
    push ax
    jmp .Loct
.Ldone:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

%endif

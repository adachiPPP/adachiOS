bits 64
default rel

section .data

s_net_head      db `  adachiOS net`,13,10,0
s_net_no_dev    db `net: no network device attached`,13,10,0
s_ping_use      db `usage: ping [-c count] [-i interval] host`,13,10,0
s_ping_summary  db `  packets received: `,0
s_ping_summary2 db `  sent: `,0
s_nl            db 13,10,0

stdout          dq 0

snp_guid:
    dd 0xA19832B9
    dw 0xAC25
    dw 0x11D3
    db 0x9A,0x2D,0x00,0x90,0x27,0x3F,0xC1,0x4D

section .bss

np_dev           resq 1
net_arp_head     resw 1
net_arp_cache    resb 80
tx_ring_base     resd 16
tx_ring_busy     resb 16
rx_ring_base     resd 16
rx_ring_busy     resb 16
icmp_id          resw 1
icmp_seq         resw 1
icmp_echo_sent   resd 1
icmp_echo_recv   resd 1
icmp_echo_done   resb 1
icmp_echo_count   resd 1
net_mac          resb 6
rx_pkt_buf       resb 1514

ping_argc        resb 1
ping_argv        resw 32
ping_n           resw 1
ping_interval     resw 1
ping_host         resw 16
ping_count        resd 1

tx_ring_head     resw 1
tx_ring_tail     resw 1
rx_ring_head     resw 1
rx_ring_tail     resw 1

section .text

%ifidn __OUTPUT__, bin
    extern puts
    extern print_dec

puts:
    ret
print_dec:
    ret

net_init:
    ret
net_send_frame:
    ret
net_recv:
    ret
cmd_net:
    ret
cmd_ping:
    ret
%endif

    extern puts
    extern print_dec
    extern argp
    extern conout
    extern bs
    global net_init, net_send_frame, net_recv, cmd_net, cmd_ping

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; net_init
; ---------------------------------------------------------------------------
net_init:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov rax, [bs]
    test rax, rax
    jz .L_clear
    lea rcx, [snp_guid]
    xor rdx, rdx
    lea r8, [np_dev]
    sub rsp, 40
    call [rax + 320]
    add rsp, 40
    test rax, rax
    jnz .L_clear
    mov rax, [np_dev]
    test rax, rax
    jz .L_clear
    mov r12, rax
    mov rax, [r12 + 120]
    test rax, rax
    jz .L_start
    lea rsi, [rax + 40]
    lea rdi, [net_mac]
    mov ecx, 6
    rep movsb
.L_start:
    mov rcx, r12
    mov rax, [rcx + 8]
    sub rsp, 40
    call rax
    add rsp, 40
    mov rcx, r12
    xor rdx, rdx
    mov rax, [rcx + 24]
    sub rsp, 40
    call rax
    add rsp, 40
.L_clear:
    mov word [net_arp_head], 0
    xor eax, eax
    mov ecx, 80
    lea rdi, [net_arp_cache]
    rep stosb
    xor eax, eax
    mov ecx, 16
    lea rdi, [tx_ring_base]
    rep stosd
    lea rdi, [tx_ring_busy]
    mov ecx, 16
    rep stosb
    lea rdi, [rx_ring_base]
    mov ecx, 16
    rep stosd
    lea rdi, [rx_ring_busy]
    mov ecx, 16
    rep stosb
    mov word [tx_ring_head], 0
    mov word [tx_ring_tail], 0
    mov word [rx_ring_head], 0
    mov word [rx_ring_tail], 0
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_send_frame
; ---------------------------------------------------------------------------
net_send_frame:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov rax, [np_dev]
    test rax, rax
    jz .L_no_dev_sf
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rbx
    ret
.L_no_dev_sf:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_recv
; ---------------------------------------------------------------------------
net_recv:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov rax, [np_dev]
    test rax, rax
    jz .L_no_dev_recv
    mov eax, 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret
.L_no_dev_recv:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_arp_lookup
; ---------------------------------------------------------------------------
net_arp_lookup:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov word [net_arp_head], 0
    xor ecx, ecx
.L_lookup:
    cmp ecx, 8
    jae .L_not_found
    mov edi, ecx
    shl edi, 4
    lea rbx, [net_arp_cache]
    add rbx, rdi
    mov eax, [rdi + rdi]
    cmp eax, [rdi]
    jne .L_next_lookup
    mov eax, 1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret
.L_next_lookup:
    add word [net_arp_head], 1
    inc ecx
    jmp .L_lookup
.L_not_found:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_arp_insert
; ---------------------------------------------------------------------------
net_arp_insert:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov word [net_arp_head], 0
    xor ecx, ecx
.L_insert:
    cmp ecx, 8
    jae .L_full
    mov edi, ecx
    shl edi, 4
    lea rbx, [net_arp_cache]
    add rbx, rdi
    mov ax, [ebx + 6*2]
    test ax, ax
    jnz .L_next_ins
    mov [rbx + 6*0], rdi
    mov [rbx + 6*6], rsi
    mov eax, ecx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret
.L_next_ins:
    add word [net_arp_head], 1
    inc ecx
    jmp .L_insert
.L_full:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; cmd_net
; ---------------------------------------------------------------------------
cmd_net:
    push rax
    push rcx
    push r8
    push r9
    push r10
    push r11
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    lea rsi, [s_net_head]
    call puts
    mov rax, [np_dev]
    test rax, rax
    jz .L_no_dev_cmd
    lea rax, [net_mac]
    call net_print_mac
    lea rsi, [s_nl]
    call puts
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret
.L_no_dev_cmd:
    lea rsi, [s_net_no_dev]
    call puts
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_print_mac
; ---------------------------------------------------------------------------
net_print_mac:
    push rax
    push rbx
    push rcx
    push rdx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rax
    mov ecx, 6
.L_print_mac:
    mov cl, [rbx]
    mov eax, ecx
    call net_print_hex_byte
    mov dl, '.'
    call putc_char
    inc rbx
    dec ecx
    jnz .L_print_mac
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_print_hex_byte
; ---------------------------------------------------------------------------
net_print_hex_byte:
    push rax
    push rbx
    push rcx
    push rdx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rax
    mov ecx, 1
    mov cl, [rbx]
    shr cl, 4
    and cl, 0xF
    add cl, '0'
    cmp cl, '9'
    jbe .L_hex_ok_hd
    add cl, 'A' - '0' - 10
.L_hex_ok_hd:
    call putc_char
    mov cl, [rbx]
    and cl, 0xF
    add cl, '0'
    cmp cl, '9'
    jbe .L_hex_ok_hd2
    add cl, 'A' - '0' - 10
.L_hex_ok_hd2:
    call putc_char
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; putc_char
; ---------------------------------------------------------------------------
putc_char:
    push rbp
    mov rbp, rsp
    push rdi
    mov rdi, rax
    call [stdout]
    pop rdi
    pop rbp
    ret

; ---------------------------------------------------------------------------
; cmd_ping
; ---------------------------------------------------------------------------
cmd_ping:
    sub rsp, 40
    mov rax, [np_dev]
    test rax, rax
    jz .no_dev
    mov rax, [argp]
    test rax, rax
    jz .usage
    mov cx, [rax]
    test cx, cx
    jz .usage
    mov rcx, [conout]
    mov rdx, rax
    mov rax, [conout]
    call [rax + 8]
    lea rsi, [s_nl]
    call puts
    add rsp, 40
    ret
.no_dev:
    lea rsi, [s_net_no_dev]
    call puts
    add rsp, 40
    ret
.usage:
    lea rsi, [s_ping_use]
    call puts
    add rsp, 40
    ret

; ---------------------------------------------------------------------------
; net_print_addr
; ---------------------------------------------------------------------------
net_print_addr:
    push rax
    push rbx
    push rcx
    push rdx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov ebp, esp
    mov eax, [ebp + 16]
    mov ebx, 10
    xor ecx, ecx
    push rbp
    mov rbp, rsp
.L_octet:
    xor edx, edx
    div ebx
    push rdx
    inc ecx
    test eax, eax
    jnz .L_octet
    pop rbp
    cmp ecx, 1
    je .L_done_addr
    mov al, '.'
    call putc_char
    pop rax
    push rax
    jmp .L_octet
.L_done_addr:
    pop rbp
    mov eax, [rsp]
    add al, '0'
    call putc_char
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ---------------------------------------------------------------------------
; net_send_echo_packet
; ---------------------------------------------------------------------------
net_send_echo_packet:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov rax, [np_dev]
    test rax, rax
    jz .L_fail_se
    inc qword [icmp_echo_sent]
    mov eax, 1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rbx
    ret
.L_fail_se:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_copy_str16
; ---------------------------------------------------------------------------
net_copy_str16:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    mov rsi, rdi
    mov rdi, rdx
    mov rcx, 16
    rep movsw
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ---------------------------------------------------------------------------
; net_parse_ip
; ---------------------------------------------------------------------------
net_parse_ip:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15
    xor eax, eax
    xor ecx, ecx
.L_parse:
    cmp byte [rdi], 0
    je .L_no_dots
    cmp byte [rdi], '.'
    je .L_done_parse
    sub byte [rdi], '0'
    jb .L_fail
    cmp byte [rdi], '9'
    ja .L_fail
    imul eax, 10
    add eax, [rdi]
    cmp eax, 255
    ja .L_fail
    inc rdi
    jmp .L_parse
.L_done_parse:
    test ecx, ecx
    jz .L_fail
    mov [rdi], eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret
.L_fail:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret
.L_no_dots:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

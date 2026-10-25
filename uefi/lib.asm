%include "uefi.inc"

bits 64
default rel

global puts
global puts_c
global puts_w
global print_dec
global s_nl
global fb_putc
global fb_clear
global con_clear
global con_set_cursor
global con_cols
global con_rows
global con_putc_hook
global con_clear_hook
global con_set_cursor_hook
global con_cursor_enable
global con_cursor_disable
global con_cursor_toggle
global cursor_y
global cursor_x
global text_rows
global text_cols
global font_h
global font_w
global font_scale
global fb_height
global fb_width
global fb_stride
global fb_base
global fb_white
global gop
global wbuf
global numbuf
global font8x16

extern conout

section .text

puts:
    push rbx
    push rdi
    push rsi
    sub rsp, 32
    cmp qword [gop], 0
    jne .fast
    cmp qword [con_putc_hook], 0
    jne .fast
    lea rdi, [wbuf]
    mov ebx, 2047
.legacy_loop:
    mov al, [rsi]
    test al, al
    jz .legacy_done
    test ebx, ebx
    jz .legacy_done
    movzx eax, al
    mov [rdi], ax
    inc rsi
    add rdi, 2
    dec ebx
    jmp .legacy_loop
.legacy_done:
    mov word [rdi], 0
    mov rax, [conout]
    test rax, rax
    jz .out
    mov rcx, rax
    lea rdx, [wbuf]
    call [rax + TXT_OUTPUTSTRING]
    jmp .out
.fast:
    mov al, [rsi]
    test al, al
    jz .out
    mov cl, al
    call fb_putc
    inc rsi
    jmp .fast
.out:
    add rsp, 32
    pop rsi
    pop rdi
    pop rbx
    ret

puts_c:
    mov rsi, rcx
    jmp puts

puts_w:
    push rbx
    push rdi
    push rsi
    sub rsp, 32
    cmp qword [gop], 0
    jne .fast
    cmp qword [con_putc_hook], 0
    jne .fast
    mov rax, [conout]
    test rax, rax
    jz .out
    mov rcx, rax
    mov rdx, rsi
    call [rax + TXT_OUTPUTSTRING]
    jmp .out
.fast:
    movzx eax, word [rsi]
    test ax, ax
    jz .out
    cmp eax, 0x7f
    jbe .fast_char
    mov al, '?'
.fast_char:
    mov cl, al
    call fb_putc
    add rsi, 2
    jmp .fast
.out:
    add rsp, 32
    pop rsi
    pop rdi
    pop rbx
    ret

print_dec:
    push rdi
    push rsi
    sub rsp, 40
    lea rdi, [numbuf + 31]
    mov byte [rdi], 0
    mov rcx, 10
.digit:
    xor edx, edx
    div rcx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .digit
    mov rsi, rdi
    call puts
    add rsp, 40
    pop rsi
    pop rdi
    ret

fb_cursor_toggle:
    push rbx
    push rbp
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15

    mov r12, [cursor_x]
    mov r13, [cursor_y]
    mov rax, [text_cols]
    test rax, rax
    jz .done
    cmp r12, rax
    jb .x_ok
    mov r12, rax
    dec r12
.x_ok:
    mov rax, [text_rows]
    test rax, rax
    jz .done
    cmp r13, rax
    jb .y_ok
    mov r13, rax
    dec r13
.y_ok:
    mov rax, r12
    mov rcx, [font_w]
    test rcx, rcx
    jz .done
    imul rax, rcx
    mov r15, rax
    mov rax, r13
    mov rcx, [font_h]
    test rcx, rcx
    jz .done
    imul rax, rcx
    mov r13, rax
    mov rbp, rcx
.loop_y:
    mov rax, r13
    imul rax, [fb_stride]
    add rax, r15
    mov rdi, [fb_base]
    lea rdi, [rdi + rax*4]
    mov rcx, [font_w]
.loop_x:
    mov eax, [rdi]
    xor eax, 0x00FFFFFF
    mov [rdi], eax
    add rdi, 4
    dec rcx
    jnz .loop_x
    inc r13
    dec rbp
    jnz .loop_y
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbp
    pop rbx
    ret

fb_cursor_hide:
    cmp qword [cursor_drawn], 0
    je .ret
    cmp qword [gop], 0
    je .ret
    call fb_cursor_toggle
    mov qword [cursor_drawn], 0
.ret:
    ret

fb_cursor_show:
    cmp qword [cursor_visible], 0
    je .ret
    cmp qword [cursor_drawn], 0
    jne .ret
    cmp qword [gop], 0
    je .ret
    call fb_cursor_toggle
    mov qword [cursor_drawn], 1
.ret:
    ret

con_cursor_enable:
    push rax
    mov qword [cursor_visible], 1
    call fb_cursor_show
    pop rax
    ret

con_cursor_disable:
    push rax
    call fb_cursor_hide
    mov qword [cursor_visible], 0
    pop rax
    ret

con_cursor_toggle:
    cmp qword [cursor_visible], 0
    je .ret
    cmp qword [cursor_drawn], 0
    jne .hide
    jmp fb_cursor_show
.hide:
    jmp fb_cursor_hide
.ret:
    ret

fb_clear:
    mov rax, [con_clear_hook]
    test rax, rax
    jnz .hook
    cmp qword [gop], 0
    je .legacy
    call fb_cursor_hide
    push rdi
    push rsi
    mov rcx, [fb_stride]
    imul rcx, [fb_height]
    mov rdi, [fb_base]
    xor eax, eax
    rep stosd
    mov qword [cursor_x], 0
    mov qword [cursor_y], 0
    pop rsi
    pop rdi
    call fb_cursor_show
    ret
.legacy:
    mov rax, [conout]
    test rax, rax
    jz .done
    sub rsp, 40
    mov rcx, rax
    call [rax + TXT_CLEARSCREEN]
    add rsp, 40
.done:
    ret
.hook:
    jmp rax

con_clear:
    jmp fb_clear

con_cols:
    mov rax, [text_cols]
    test rax, rax
    jnz .done
    mov rax, 80
.done:
    ret

con_rows:
    mov rax, [text_rows]
    test rax, rax
    jnz .done
    mov rax, 25
.done:
    ret

con_set_cursor:
    mov rax, [con_set_cursor_hook]
    test rax, rax
    jnz .hook
    cmp qword [gop], 0
    je .legacy
    call fb_cursor_hide
    mov rax, [text_cols]
    test rax, rax
    jz .x_ok
    cmp rdx, rax
    jb .x_ok
    mov rdx, rax
    dec rdx
.x_ok:
    mov rax, [text_rows]
    test rax, rax
    jz .y_ok
    cmp r8, rax
    jb .y_ok
    mov r8, rax
    dec r8
.y_ok:
    mov [cursor_x], rdx
    mov [cursor_y], r8
    call fb_cursor_show
    ret
.legacy:
    mov rax, [conout]
    test rax, rax
    jz .done
    sub rsp, 40
    mov rcx, rax
    call [rax + TXT_SETCURSOR]
    add rsp, 40
.done:
    ret
.hook:
    jmp rax

fb_putc:
    mov rax, [con_putc_hook]
    test rax, rax
    jnz .hook
    cmp qword [gop], 0
    je .fallback

    push rbx
    push rbp
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8

    movzx eax, cl
    push rax
    call fb_cursor_hide
    pop rax
    mov r15, [fb_base]
    mov rbp, [fb_stride]
    mov r14, [font_scale]
    test r14, r14
    jnz .scale_ok
    mov r14, 1
.scale_ok:
    cmp al, 13
    je .cr
    cmp al, 10
    je .lf
    cmp al, 8
    je .bs
    cmp al, 12
    je .clear
    cmp al, 9
    je .tab

    mov rbx, rax
    shl rbx, 4
    lea rdx, [font8x16]
    add rbx, rdx
    mov r12, [cursor_x]
    mov r13, [cursor_y]
    xor r8d, r8d
.gy:
    movzx r11d, byte [rbx + r8]
    xor r9d, r9d
.gx:
    mov rax, r12
    mov rcx, [font_w]
    imul rax, rcx
    mov rcx, r9
    imul rcx, r14
    add rax, rcx
    mov rdx, r13
    mov rcx, [font_h]
    imul rdx, rcx
    mov rcx, r8
    imul rcx, r14
    add rdx, rcx
    imul rdx, rbp
    add rdx, rax
    lea rdi, [r15 + rdx*4]
    mov eax, r11d
    mov ecx, 7
    sub ecx, r9d
    shr eax, cl
    test al, 1
    jz .black
    mov eax, [fb_white]
    jmp .fill
.black:
    xor eax, eax
.fill:
    mov r10, r14
.dy:
    mov rcx, r14
    mov rdx, rdi
.dx:
    mov [rdx], eax
    add rdx, 4
    dec rcx
    jnz .dx
    mov rcx, rbp
    shl rcx, 2
    add rdi, rcx
    dec r10
    jnz .dy
    inc r9
    cmp r9, 8
    jl .gx
    inc r8
    cmp r8, 16
    jl .gy

    inc r12
    mov rax, [text_cols]
    test rax, rax
    jz .store_cursor
    cmp r12, rax
    jl .store_cursor
    xor r12d, r12d
    inc r13
    mov rax, [text_rows]
    test rax, rax
    jz .store_cursor
    cmp r13, rax
    jl .store_cursor
    jmp .scroll
.store_cursor:
    mov [cursor_x], r12
    mov [cursor_y], r13
    jmp .done
.cr:
    mov qword [cursor_x], 0
    jmp .done
.lf:
    mov qword [cursor_x], 0
    inc qword [cursor_y]
    mov rax, [text_rows]
    test rax, rax
    jz .done
    mov rcx, [cursor_y]
    cmp rcx, rax
    jl .done
    mov r12, 0
    mov r13, rcx
    jmp .scroll
.bs:
    cmp qword [cursor_x], 0
    je .done
    dec qword [cursor_x]
    jmp .done
.tab:
    mov rax, [cursor_x]
    add rax, 8
    and rax, -8
    mov [cursor_x], rax
    mov rcx, [text_cols]
    test rcx, rcx
    jz .done
    cmp rax, rcx
    jl .done
    mov qword [cursor_x], 0
    inc qword [cursor_y]
    mov rax, [text_rows]
    test rax, rax
    jz .done
    mov rcx, [cursor_y]
    cmp rcx, rax
    jl .done
    mov r12, 0
    mov r13, rcx
    jmp .scroll
.scroll:
    mov rax, [font_h]
    imul rax, [fb_stride]
    shl rax, 2
    mov rdx, rax
    mov rsi, r15
    add rsi, rax
    mov rdi, r15
    mov rcx, [text_rows]
    dec rcx
    imul rcx, rdx
    shr rcx, 3
    rep movsq
    mov rax, [text_rows]
    dec rax
    mov rcx, [font_h]
    imul rax, rcx
    mov rcx, [fb_stride]
    imul rax, rcx
    add r15, rax
    mov rcx, [font_h]
    imul rcx, [fb_stride]
    shl rcx, 2
    xor eax, eax
    rep stosd
    mov r13, [text_rows]
    dec r13
    xor r12d, r12d
    mov [cursor_x], r12
    mov [cursor_y], r13
    jmp .done
.clear:
    call fb_clear
    jmp .done
.done:
    call fb_cursor_show
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbp
    pop rbx
    ret
.fallback:
    push rbx
    push rbp
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    movzx eax, cl
    mov [onechar_w], ax
    mov word [onechar_w + 2], 0
    mov rax, [conout]
    test rax, rax
    jz .done
    mov rcx, rax
    lea rdx, [onechar_w]
    call [rax + TXT_OUTPUTSTRING]
    jmp .done
.hook:
    jmp rax

section .data

s_nl      db `\r\n`,0

section .bss

wbuf             resb 4096
numbuf           resb 32
onechar_w        resw 2

gop              resq 1
fb_base          resq 1
fb_stride        resq 1
fb_white         resq 1
fb_width         resq 1
fb_height        resq 1
font_scale       resq 1
font_w           resq 1
font_h           resq 1
text_cols        resq 1
text_rows        resq 1
cursor_x         resq 1
cursor_y         resq 1
cursor_drawn     resq 1
cursor_visible   resq 1

con_putc_hook        resq 1
con_clear_hook       resq 1
con_set_cursor_hook  resq 1

section .data

font8x16:
    incbin "build/font_glyphs.bin"

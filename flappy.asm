%include "uefi.inc"

bits 64
default rel

global cmd_flappy

extern conout
extern conin
extern bs
extern puts
extern print_dec

BIRDX     equ 8
PIPEW     equ 5
GAPH      equ 7
PIPESPACE equ 28
FRAMEUS   equ 60000

section .text

rng:
    mov rax, [g_seed]
    mov rcx, rax
    shl rcx, 13
    xor rax, rcx
    mov rcx, rax
    shr rcx, 7
    xor rax, rcx
    mov rcx, rax
    shl rcx, 17
    xor rax, rcx
    mov [g_seed], rax
    ret

newgap:
    sub rsp, 40
    call rng
    xor edx, edx
    mov rcx, [fb_h]
    sub rcx, GAPH+4
    div rcx
    lea rax, [rdx + 2]
    add rsp, 40
    ret

set_cursor:
    sub rsp, 40
    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_SETCURSOR]
    add rsp, 40
    ret

fl_put:
    cmp rcx, 0
    jl .r
    cmp rcx, [fb_w]
    jge .r
    cmp rdx, 0
    jl .r
    cmp rdx, [fb_h]
    jge .r
    mov rax, rdx
    shl rax, 8
    add rax, rcx
    shl rax, 1
    lea r9, [fb]
    mov [r9 + rax], r8w
.r:
    ret

fl_init:
    sub rsp, 40
    mov rax, [conout]
    mov rax, [rax + 72]
    mov eax, [rax + 4]
    mov [fl_curmode], rax
    mov rcx, [conout]
    mov rdx, [fl_curmode]
    lea r8, [fl_cols]
    lea r9, [fl_rows]
    mov rax, [conout]
    call [rax + TXT_QUERYMODE]
    test rax, rax
    jz .qok
    mov qword [fl_cols], 80
    mov qword [fl_rows], 25
.qok:
    mov rax, [fl_cols]
    dec rax
    cmp rax, 255
    jbe .wok
    mov rax, 255
.wok:
    mov [fb_w], rax
    mov rax, [fl_rows]
    cmp rax, 64
    jbe .hok
    mov rax, 64
.hok:
    mov [fb_h], rax
    mov rax, [fb_h]
    shr rax, 1
    shl rax, 2
    mov [g_y], rax
    mov qword [g_vel], 0
    mov qword [g_score], 0
    mov qword [g_alive], 1
    mov rax, [fb_w]
    mov [pipe_x], rax
    add rax, PIPESPACE
    mov [pipe_x + 8], rax
    add rax, PIPESPACE
    mov [pipe_x + 16], rax
    mov qword [pipe_passed], 0
    mov qword [pipe_passed + 8], 0
    mov qword [pipe_passed + 16], 0
    rdtsc
    shl rdx, 32
    or rax, rdx
    or rax, 1
    mov [g_seed], rax
    call newgap
    mov [pipe_gap], rax
    call newgap
    mov [pipe_gap + 8], rax
    call newgap
    mov [pipe_gap + 16], rax
    add rsp, 40
    ret

fl_input:
    sub rsp, 40
.k:
    mov rax, [conin]
    mov rcx, rax
    lea rdx, [fkey]
    call [rax + IN_READKEYSTROKE]
    test rax, rax
    jnz .d
    movzx eax, word [fkey + 2]
    cmp ax, 32
    je .flap
    cmp ax, 'w'
    je .flap
    cmp ax, 'q'
    je .quit
    jmp .k
.flap:
    mov qword [g_vel], -6
    jmp .k
.quit:
    mov qword [g_alive], 0
    jmp .k
.d:
    add rsp, 40
    ret

fl_step:
    sub rsp, 40
    mov rax, [g_vel]
    inc rax
    cmp rax, 4
    jle .gv
    mov rax, 4
.gv:
    mov [g_vel], rax
    add [g_y], rax
    mov rax, [g_y]
    sar rax, 2
    mov [g_row], rax
    cmp rax, 0
    jl .die
    mov rcx, [fb_h]
    dec rcx
    cmp rax, rcx
    jge .die

    mov qword [fl_idx], 0
.pl:
    mov rcx, [fl_idx]
    cmp rcx, 3
    jae .pdone
    lea rsi, [pipe_x]
    mov rax, [rsi + rcx*8]
    dec rax
    mov [rsi + rcx*8], rax
    lea rdx, [rax + PIPEW]
    cmp rdx, 0
    jg .check
    mov rax, [fb_w]
    mov [rsi + rcx*8], rax
    lea rdi, [pipe_passed]
    mov qword [rdi + rcx*8], 0
    call newgap
    mov rcx, [fl_idx]
    lea rdi, [pipe_gap]
    mov [rdi + rcx*8], rax
    jmp .pnext
.check:
    lea rsi, [pipe_x]
    mov rax, [rsi + rcx*8]
    cmp rax, BIRDX
    jg .noc
    lea rdx, [rax + PIPEW]
    cmp rdx, BIRDX
    jle .noc
    lea rdi, [pipe_gap]
    mov rdx, [rdi + rcx*8]
    mov rax, [g_row]
    cmp rax, rdx
    jl .die
    add rdx, GAPH
    cmp rax, rdx
    jge .die
.noc:
    lea rsi, [pipe_x]
    mov rax, [rsi + rcx*8]
    lea rdx, [rax + PIPEW]
    cmp rdx, BIRDX
    jg .pnext
    lea rdi, [pipe_passed]
    cmp qword [rdi + rcx*8], 0
    jne .pnext
    mov qword [rdi + rcx*8], 1
    inc qword [g_score]
.pnext:
    inc qword [fl_idx]
    jmp .pl
.pdone:
    add rsp, 40
    ret
.die:
    mov qword [g_alive], 0
    add rsp, 40
    ret

fl_draw_pipes:
    sub rsp, 40
    mov qword [fl_idx], 0
.dp:
    mov rcx, [fl_idx]
    cmp rcx, 3
    jae .dpd
    lea rsi, [pipe_x]
    mov rax, [rsi + rcx*8]
    mov [dp_px], rax
    lea rsi, [pipe_gap]
    mov rax, [rsi + rcx*8]
    mov [dp_gap], rax
    mov qword [dp_col], 0
.dc:
    mov rax, [dp_col]
    cmp rax, PIPEW
    jge .dpn
    mov qword [dp_row], 0
.dr:
    mov rax, [dp_row]
    mov rdx, [fb_h]
    dec rdx
    cmp rax, rdx
    jge .drn
    mov rdx, [dp_gap]
    cmp rax, rdx
    jl .draw
    add rdx, GAPH
    cmp rax, rdx
    jge .draw
    jmp .skip
.draw:
    mov rcx, [dp_px]
    add rcx, [dp_col]
    mov rdx, [dp_row]
    mov r8, '#'
    call fl_put
.skip:
    inc qword [dp_row]
    jmp .dr
.drn:
    inc qword [dp_col]
    jmp .dc
.dpn:
    inc qword [fl_idx]
    jmp .dp
.dpd:
    add rsp, 40
    ret

fl_render:
    sub rsp, 40

    mov qword [rv_y], 0
.cy:
    mov rax, [rv_y]
    cmp rax, [fb_h]
    jge .cyd
    mov qword [rv_x], 0
.cx:
    mov rax, [rv_x]
    cmp rax, [fb_w]
    jge .cxd
    mov rdx, [rv_y]
    shl rdx, 8
    add rdx, rax
    shl rdx, 1
    lea rcx, [fb]
    mov word [rcx + rdx], 32
    inc qword [rv_x]
    jmp .cx
.cxd:
    inc qword [rv_y]
    jmp .cy
.cyd:

    call fl_draw_pipes

    mov qword [rv_x], 0
    mov rdx, [fb_h]
    dec rdx
    mov [rv_y], rdx
.fl:
    mov rax, [rv_x]
    cmp rax, [fb_w]
    jge .fld
    mov rcx, rax
    mov rdx, [rv_y]
    mov r8, '='
    call fl_put
    inc qword [rv_x]
    jmp .fl
.fld:

    mov rcx, BIRDX
    mov rdx, [g_row]
    mov r8, '@'
    call fl_put

    mov qword [rv_y], 0
.oy:
    mov rax, [rv_y]
    cmp rax, [fb_h]
    jge .oyd
    mov qword [rv_x], 0
.ox:
    mov rax, [rv_x]
    cmp rax, [fb_w]
    jge .oxd
    mov rdx, [rv_y]
    shl rdx, 8
    add rdx, rax
    shl rdx, 1
    lea rcx, [fb]
    movzx r8d, word [rcx + rdx]
    lea rcx, [rowbuf]
    mov rdx, rax
    shl rdx, 1
    mov [rcx + rdx], r8w
    inc qword [rv_x]
    jmp .ox
.oxd:
    lea rcx, [rowbuf]
    mov rdx, [fb_w]
    shl rdx, 1
    mov word [rcx + rdx], 0
    mov rdx, 0
    mov r8, [rv_y]
    call set_cursor
    mov rcx, [conout]
    lea rdx, [rowbuf]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    inc qword [rv_y]
    jmp .oy
.oyd:

    xor edx, edx
    xor r8d, r8d
    call set_cursor
    lea rsi, [s_score]
    call puts
    mov rax, [g_score]
    call print_dec

    add rsp, 40
    ret

fl_over:
    sub rsp, 40
    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]
    lea rsi, [s_over]
    call puts
    mov rax, [g_score]
    call print_dec
    lea rsi, [s_over2]
    call puts
.w:
    mov rax, [conin]
    mov rcx, [rax + IN_WAITFORKEY]
    mov [fl_evt], rcx
    mov rax, [bs]
    mov ecx, 1
    lea rdx, [fl_evt]
    lea r8, [fl_evidx]
    call [rax + BS_WAITFOREVENT]
    mov rax, [conin]
    mov rcx, rax
    lea rdx, [fkey]
    call [rax + IN_READKEYSTROKE]
    test rax, rax
    jnz .w
    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]
    add rsp, 40
    ret

cmd_flappy:
    sub rsp, 40

    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]

    mov rcx, [conout]
    xor edx, edx
    mov rax, [conout]
    call [rax + TXT_ENABLECURSOR]

    call fl_init
.gl:
    call fl_input
    cmp qword [g_alive], 0
    je .over
    call fl_step
    call fl_render
    mov rcx, FRAMEUS
    mov rax, [bs]
    call [rax + BS_STALL]
    jmp .gl
.over:
    call fl_over

    mov rcx, [conout]
    mov edx, 1
    mov rax, [conout]
    call [rax + TXT_ENABLECURSOR]

    add rsp, 40
    ret

section .data

s_score   db `score: `,0
s_over    db `game over! score: `,0
s_over2   db `\r\npress any key to go back\r\n`,0

section .bss

fkey         resd 1
fl_evt       resq 1
fl_evidx     resq 1
fl_curmode   resq 1
fl_cols      resq 1
fl_rows      resq 1

fb           resw 16384
rowbuf       resw 258
fb_w         resq 1
fb_h         resq 1
g_y          resq 1
g_vel        resq 1
g_row        resq 1
g_score      resq 1
g_alive      resq 1
g_seed       resq 1
fl_idx       resq 1
pipe_x       resq 3
pipe_gap     resq 3
pipe_passed  resq 3
dp_px        resq 1
dp_gap       resq 1
dp_col       resq 1
dp_row       resq 1
rv_x         resq 1
rv_y         resq 1

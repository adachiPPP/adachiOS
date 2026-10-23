FLW        equ 80
FLH        equ 25
FBIRDX     equ 8
FPIPEW     equ 5
FGAPH      equ 7
FPIPESPACE equ 28

cmd_flappy:
    mov ax, 0x0003
    int 0x10
    call fl_init
.loop:
    call fl_input
    cmp byte [fl_alive], 0
    je .over
    call fl_step
    call fl_render
    mov ax, 0x8600
    xor cx, cx
    mov dx, 60000
    int 0x15
    jmp .loop
.over:
    call fl_over
    ret

fl_rng:
    mov ax, [fl_seed]
    mov dx, ax
    shl dx, 7
    xor ax, dx
    mov dx, ax
    shr dx, 9
    xor ax, dx
    mov dx, ax
    shl dx, 8
    xor ax, dx
    or ax, 1
    mov [fl_seed], ax
    ret

fl_newgap:
    call fl_rng
    xor dx, dx
    mov cx, 14
    div cx
    add dx, 2
    mov ax, dx
    ret

fl_init:
    call fl_clear
    int 0x1A
    mov [fl_seed], dx
    or word [fl_seed], 1
    mov word [fl_y], 48
    mov word [fl_vel], 0
    mov word [fl_score], 0
    mov byte [fl_alive], 1
    mov word [pipe_x], FLW
    mov word [pipe_x + 2], FLW + FPIPESPACE
    mov word [pipe_x + 4], FLW + FPIPESPACE * 2
    mov byte [pipe_passed], 0
    mov byte [pipe_passed + 1], 0
    mov byte [pipe_passed + 2], 0
    call fl_newgap
    mov [pipe_gap], ax
    call fl_newgap
    mov [pipe_gap + 2], ax
    call fl_newgap
    mov [pipe_gap + 4], ax
    ret

fl_put:
    cmp ax, FLW
    jae .r
    cmp bx, FLH
    jae .r
    push ax
    push bx
    push cx
    push di
    push es
    mov cx, FLW
    imul bx, cx
    add bx, ax
    shl bx, 1
    mov ax, 0xB800
    mov es, ax
    mov [es:bx], dx
    pop es
    pop di
    pop cx
    pop bx
    pop ax
.r:
    ret

fl_clear:
    push ax
    push cx
    push di
    push es
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    ret

fl_input:
    mov ah, 1
    int 0x16
    jz .done
    mov ah, 0
    int 0x16
    cmp al, ' '
    je .flap
    cmp al, 'w'
    je .flap
    cmp al, 'q'
    je .quit
    jmp fl_input
.flap:
    mov word [fl_vel], -6
    jmp fl_input
.quit:
    mov byte [fl_alive], 0
.done:
    ret

fl_step:
    mov ax, [fl_vel]
    inc ax
    cmp ax, 4
    jle .gv
    mov ax, 4
.gv:
    mov [fl_vel], ax
    add [fl_y], ax
    mov ax, [fl_y]
    sar ax, 1
    sar ax, 1
    mov [fl_row], ax
    cmp ax, 0
    jl .die
    cmp ax, FLH - 1
    jge .die
    xor bx, bx
.pipe:
    mov si, bx
    shl si, 1
    mov ax, [pipe_x + si]
    dec ax
    mov [pipe_x + si], ax
    mov dx, ax
    add dx, FPIPEW
    cmp dx, 0
    jg .check
    mov word [pipe_x + si], FLW
    mov byte [pipe_passed + bx], 0
    call fl_newgap
    mov si, bx
    shl si, 1
    mov [pipe_gap + si], ax
    jmp .next
.check:
    cmp ax, FBIRDX
    jg .passed
    mov dx, ax
    add dx, FPIPEW
    cmp dx, FBIRDX
    jle .passed
    mov si, bx
    shl si, 1
    mov dx, [pipe_gap + si]
    mov ax, [fl_row]
    cmp ax, dx
    jl .die
    add dx, FGAPH
    cmp ax, dx
    jge .die
.passed:
    mov si, bx
    shl si, 1
    mov ax, [pipe_x + si]
    add ax, FPIPEW
    cmp ax, FBIRDX
    jg .next
    cmp byte [pipe_passed + bx], 0
    jne .next
    mov byte [pipe_passed + bx], 1
    inc word [fl_score]
.next:
    inc bx
    cmp bx, 3
    jb .pipe
    ret
.die:
    mov byte [fl_alive], 0
    ret

fl_draw_pipes:
    xor bp, bp
.pl:
    cmp bp, 3
    jae .done
    mov si, bp
    shl si, 1
    mov ax, [pipe_x + si]
    mov [dp_px], ax
    mov ax, [pipe_gap + si]
    mov [dp_gap], ax
    xor bx, bx
.dc:
    cmp bx, FPIPEW
    jae .pn
    xor cx, cx
.dr:
    cmp cx, FLH
    jae .dn
    cmp cx, [dp_gap]
    jl .draw
    mov ax, [dp_gap]
    add ax, FGAPH
    cmp cx, ax
    jge .draw
    jmp .skip
.draw:
    mov [dp_col], bx            ; this KILLED me
    mov ax, [dp_px]
    add ax, bx
    mov dx, 0x0A23
    mov bx, cx
    call fl_put
    mov bx, [dp_col]
.skip:
    inc cx
    jmp .dr
.dn:
    inc bx
    jmp .dc
.pn:
    inc bp
    jmp .pl
.done:
    ret

fl_render:
    call fl_clear
    call fl_draw_pipes
    xor ax, ax
.g:
    cmp ax, FLW
    jae .gd
    mov bx, FLH - 1
    mov dx, 0x073D
    call fl_put
    inc ax
    jmp .g
.gd:
    mov ax, FBIRDX
    mov bx, [fl_row]
    mov dx, 0x0E40
    call fl_put
    xor bh, bh
    xor dx, dx
    mov ah, 2
    int 0x10
    mov si, s_fl_score
    call puts
    mov ax, [fl_score]
    call print_dec
    ret

fl_over:
    mov ax, 0x0003
    int 0x10
    xor bh, bh
    xor dx, dx
    mov ah, 2
    int 0x10
    mov si, s_fl_over
    call puts
    mov ax, [fl_score]
    call print_dec
    mov si, s_fl_over2
    call puts
    xor ah, ah
    int 0x16
    mov ax, 0x0003
    int 0x10
    ret

s_fl_score db 'score: ',0
s_fl_over  db 'game over! score: ',0
s_fl_over2 db 13,10,'press any key to go back',13,10,0

fl_seed      dw 0
fl_y         dw 0
fl_vel       dw 0
fl_row       dw 0
fl_score     dw 0
fl_alive     db 0
pipe_x       times 3 dw 0
pipe_gap     times 3 dw 0
pipe_passed  times 3 db 0
dp_px        dw 0
dp_gap       dw 0
dp_col       dw 0

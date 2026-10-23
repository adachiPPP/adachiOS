%include "uefi.inc"

bits 64
default rel

global cmd_vi

extern conout
extern conin
extern bs
extern puts
extern fs_open

section .bss
file_h   resq 1
vi_buf   resq 1
vi_len   resq 1
cur      resq 1
row      resq 1
mode     resq 1
eol      resq 1
evt      resq 1

section .text

cmd_vi:
    sub rsp, 40
    mov rax, [argp]
    cmp word [rax], 0
    je .usage
    mov rcx, [argp]
    mov rdx, 0
    call fs_open
    test rax, rax
    jz .readfail
    mov [file_h], rax
    mov qword [vi_buf], 4096
    mov qword [vi_len], qword [vi_buf]
    mov qword [cur], 0
    mov qword [row], 0
    mov qword [mode], 0
    mov qword [eol], 0
.read:
    mov rax, [file_h]
    mov rcx, rax
    lea rdx, [vi_buf]
    mov r8, qword [vi_len]
    call [rax + FILE_READ]
    test rax, rax
    jnz .done
    cmp qword [vi_buf], 0
    je .done
    mov rax, [vi_len]
    add rax, qword [vi_buf]
    mov qword [vi_len], rax
    mov qword [vi_buf], 0
    jmp .read
.done:
    mov rax, [vi_len]
    mov qword [vi_buf], rax
    lea rsi, [vi_buf]
    call print_bytes
    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]
    mov rcx, [conout]
    mov edx, 1
    mov rax, [conout]
    call [rax + TXT_ENABLECURSOR]
    call show_row
.wait:
    mov rax, [conin]
    mov rcx, [rax + IN_WAITFORKEY]
    mov [evt], rcx
    mov rax, [bs]
    mov ecx, 1
    lea rdx, [evt]
    lea r8, [evidx]
    call [rax + BS_WAITFOREVENT]

    mov rax, [conin]
    mov rcx, rax
    lea rdx, [key]
    call [rax + IN_READKEYSTROKE]
    test rax, rax
    jnz .scan
    jmp .wait

.scan:
    movzx ecx, word [key]
    cmp ecx, 27
    je .esc
    cmp ecx, 13
    je .enter
    cmp ecx, 127
    je .backspace
    cmp ecx, 32
    jae .type
    cmp ecx, 'w'
    je .wcmd
    cmp ecx, 'q'
    je .qcmd
    cmp ecx, ':'
    je .colcmd
    jmp .wait

.esc:
    cmp qword [mode], 0
    jne .normal
    jmp .wait
.enter:
    cmp qword [mode], 0
    jne .normal
    call newline
    jmp .wait
.backspace:
    cmp qword [mode], 0
    jne .normal
    cmp qword [cur], 0
    je .wait
    dec qword [cur]
    call show_row
    jmp .wait
.type:
    cmp qword [mode], 0
    jne .normal
    cmp qword [cur], [eol]
    jae .append
    mov rdx, [cur]
    shl rdx, 1
    mov rax, [vi_buf + rdx]
    cmp ax, 0
    jne .ins
    mov rdx, [cur]
    shl rdx, 1
    mov rax, [key]
    mov [vi_buf + rdx], ax
    inc qword [cur]
    inc qword [eol]
    jmp .show
.append:
    mov rdx, [cur]
    shl rdx, 1
    mov rax, [key]
    mov rcx, [eol]
    shl rcx, 1
    mov [vi_buf + rcx], ax
    shl rcx, 1
    inc qword [eol]
    inc qword [cur]
    mov rdx, [cur]
    shl rdx, 1
    mov rax, [vi_buf + rdx]
    mov [vi_buf + rdx + 2], ax
    jmp .show
.ins:
    mov rdx, [cur]
    shl rdx, 1
    mov rax, [vi_buf + rdx + 2]
    mov rcx, [eol]
    shl rcx, 1
    sub rcx, rdx
    lea rdi, [vi_buf + rdx]
    rep movsb
    mov rdx, [cur]
    shl rdx, 1
    mov rax, [key]
    mov [vi_buf + rdx], ax
    inc qword [cur]
    inc qword [eol]
    mov rdx, [eol]
    shl rdx, 1
    mov word [vi_buf + rdx], 0
    jmp .show
.wcmd:
    cmp qword [mode], 0
    jne .normal
    call save
    jmp .wait
.qcmd:
    cmp qword [mode], 0
    jne .normal
    call save
    jmp .quit
.colcmd:
    cmp qword [mode], 0
    jne .normal
    lea rsi, [s_unsaved]
    call puts
    mov qword [mode], 2
    jmp .wait
.normal:
    cmp qword [mode], 1
    je .save
    cmp qword [mode], 2
    je .quit
    jmp .wait
.save:
    call save
    mov qword [mode], 0
    jmp .wait
.quit:
    mov qword [mode], 0
    jmp .wait

show_row:
    sub rsp, 40
    mov rax, [cur]
    mov rdx, rax
    shl rdx, 1
    lea rsi, [vi_buf + rdx]
    mov rcx, [conout]
    mov rdx, [row]
    mov rax, [conout]
    call [rax + TXT_SETCURSOR]
    lea rdx, [vi_buf]
    mov rcx, rax
    call [rax + TXT_OUTPUTSTRING]
    lea rsi, [s_nl]
    call puts
    mov rax, [cur]
    add rax, 1
    mov [cur], rax
    mov rdx, [cur]
    shl rdx, 1
    mov rax, [vi_buf + rdx]
    mov word [vi_buf + [cur]*2], ax
    inc qword [eol]
    mov rcx, [conout]
    mov rdx, [cur]
    mov rax, [conout]
    call [rax + TXT_SETCURSOR]
    lea rdx, [vi_buf]
    mov rcx, rax
    call [rax + TXT_OUTPUTSTRING]
    jmp .done
.show:
    call show_row
.done:
    add rsp, 40
    ret

newline:
    sub rsp, 40
    mov rax, [cur]
    shl rax, 1
    mov rdx, [eol]
    shl rdx, 1
    sub rdx, rax
    lea rsi, [vi_buf + rax]
    mov rcx, rdx
    rep movsb
    mov word [vi_buf + [eol]], 0
    mov qword [eol], rax
    mov rax, [cur]
    add rax, 1
    mov [cur], rax
    mov rcx, [conout]
    mov rdx, [cur]
    mov rax, [conout]
    call [rax + TXT_SETCURSOR]
    lea rdx, [vi_buf]
    mov rcx, rax
    call [rax + TXT_OUTPUTSTRING]
    lea rsi, [s_nl]
    call puts
    mov rdx, [eol]
    shl rdx, 1
    mov word [vi_buf + rdx], 0
    mov qword [eol], 0
    jmp .done2
.done2:
    add rsp, 40
    ret

save:
    sub rsp, 40
    mov rax, [argp]
    mov rdx, 0
    call fs_open
    test rax, rax
    jz .fail
    mov [file_h], rax
    mov rax, [vi_len]
    mov rcx, rax
    lea rdx, [vi_buf]
    mov r8, [file_h]
    call [rax + FILE_WRITE]
    mov rax, [file_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    cmp rax, 0
    jne .fail
    lea rsi, [s_written]
    call puts
    add rsp, 40
    ret
.fail:
    lea rsi, [s_writefail]
    call puts
    add rsp, 40
    ret

print_bytes:
    sub rsp, 40
    mov [pb_src], rsi
    mov [pb_left], rcx
.outer:
    cmp qword [pb_left], 0
    je .done
    lea rdi, [pbuf]
    xor r9d, r9d
.inner:
    cmp qword [pb_left], 0
    je .flush
    cmp r9, 500
    jae .flush
    mov rsi, [pb_src]
    movzx eax, byte [rsi]
    inc qword [pb_src]
    dec qword [pb_left]
    cmp eax, 10
    jne .put
    mov word [rdi], 13
    add rdi, 2
    inc r9
.put:
    mov [rdi], ax
    add rdi, 2
    inc r9
    jmp .inner
.flush:
    mov word [rdi], 0
    mov rax, [conout]
    mov rcx, rax
    lea rdx, [pbuf]
    call [rax + TXT_OUTPUTSTRING]
    jmp .outer
.done:
    add rsp, 40
    ret

section .data

s_usage   db `usage: vi FILE`,13,10,0
s_written db `written`,0
s_writefail db `write failed`,0
s_unsaved db `unsaved changes (:q! to discard)`,13,10,0

section .bss

file_h       resq 1
vi_buf       resq 1
vi_len       resq 1
cur          resq 1
row          resq 1
mode         resq 1
eol          resq 1
evt          resq 1

pbuf         resw 512
pb_src       resq 1
pb_left      resq 1

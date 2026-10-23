%include "uefi.inc"

bits 64
default rel

global cmd_vi

extern conout
extern conin
extern bs
extern argp
extern puts
extern fs_open

VBUFMAX equ 16384

section .text

cmd_vi:
    sub rsp, 40
    mov rax, [argp]
    cmp word [rax], 0
    je .usage

    mov rsi, [argp]
    lea rdi, [vname]
.cp:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .cp

    call vi_size
    mov qword [vlen], 0
    mov qword [vpos], 0
    mov qword [vtop], 0
    mov qword [vmode], 0
    mov qword [vmod], 0
    mov qword [vquit], 0
    mov qword [vmsgp], 0
    mov qword [vcmdlen], 0
    call vi_load

    mov rax, [conout]
    mov rcx, rax
    call [rax + TXT_CLEARSCREEN]

    call vi_loop

    mov rax, [conout]
    mov rcx, rax
    call [rax + TXT_CLEARSCREEN]
    add rsp, 40
    ret
.usage:
    lea rsi, [s_vi_usage]
    call puts
    add rsp, 40
    ret

vi_size:
    sub rsp, 40
    mov rax, [conout]
    mov rax, [rax + 72]
    mov eax, [rax + 4]
    mov [vmode_holder], rax
    mov rax, [conout]
    mov rcx, rax
    mov rdx, [vmode_holder]
    lea r8, [vcols]
    lea r9, [vrow2s]
    call [rax + TXT_QUERYMODE]
    test rax, rax
    jz .ok
    mov qword [vcols], 80
    mov qword [vrow2s], 25
.ok:
    cmp qword [vcols], 256
    jbe .done
    mov qword [vcols], 256
.done:
    add rsp, 40
    ret

vi_load:
    sub rsp, 40
    lea rcx, [vname]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .out
    mov [vh], rax
.rd:
    mov rax, VBUFMAX
    sub rax, [vlen]
    jz .close
    mov [vsz], rax
    mov rax, [vh]
    mov rcx, rax
    lea rdx, [vsz]
    lea r8, [vbuf]
    add r8, [vlen]
    call [rax + FILE_READ]
    test rax, rax
    jnz .close
    mov rax, [vsz]
    test rax, rax
    jz .close
    add [vlen], rax
    jmp .rd
.close:
    mov rax, [vh]
    mov rcx, rax
    call [rax + FILE_CLOSE]
.out:
    add rsp, 40
    ret

vi_save:
    sub rsp, 40
    lea rcx, [vname]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .create
    mov rcx, rax
    call [rax + FILE_DELETE]
.create:
    lea rcx, [vname]
    mov rdx, 0x8000000000000003
    call fs_open
    test rax, rax
    jz .fail
    mov [vh], rax
    mov rax, [vlen]
    mov [vsz], rax
    mov rax, [vh]
    mov rcx, rax
    lea rdx, [vsz]
    lea r8, [vbuf]
    call [rax + FILE_WRITE]
    mov [vst], rax
    mov rax, [vh]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    cmp qword [vst], 0
    jne .fail
    mov qword [vmod], 0
    lea rax, [s_saved]
    mov [vmsgp], rax
    add rsp, 40
    ret
.fail:
    lea rax, [s_savefail]
    mov [vmsgp], rax
    add rsp, 40
    ret

vi_getkey:
    sub rsp, 40
.w:
    mov rax, [conin]
    mov rcx, [rax + IN_WAITFORKEY]
    mov [vevt2], rcx
    mov rax, [bs]
    mov ecx, 1
    lea rdx, [vevt2]
    lea r8, [vevidx2]
    call [rax + BS_WAITFOREVENT]

    mov rax, [conin]
    mov rcx, rax
    lea rdx, [vkey2]
    call [rax + IN_READKEYSTROKE]
    test rax, rax
    jnz .w

    movzx eax, word [vkey2]
    mov [vsc2], rax
    movzx eax, word [vkey2 + 2]
    mov [vch2], rax
    add rsp, 40
    ret

vi_loop:
    sub rsp, 40
.top:
    call vi_draw
    call vi_getkey
    mov qword [vmsgp], 0
    cmp qword [vsc2], 0
    jne .special
    mov rax, [vmode]
    cmp rax, 1
    je .insk
    cmp rax, 2
    je .cmdk
    jmp .normk

.special:
    mov rax, [vsc2]
    cmp rax, 23
    je .esc
    cmp rax, 1
    je .up
    cmp rax, 2
    je .down
    cmp rax, 3
    je .right
    cmp rax, 4
    je .left
    jmp .next

.esc:
    mov qword [vmode], 0
    jmp .next
.up:
    call vi_up
    jmp .next
.down:
    call vi_down
    jmp .next
.right:
    call vi_right
    jmp .next
.left:
    call vi_left
    jmp .next

.insk:
    mov rax, [vch2]
    cmp rax, 13
    je .ins_nl
    cmp rax, 8
    je .ins_bs
    cmp rax, 32
    jb .next
    cmp rax, 126
    ja .next
    call vi_insert_char
    jmp .next
.ins_nl:
    mov qword [vch2], 10
    call vi_insert_char
    jmp .next
.ins_bs:
    call vi_backspace
    jmp .next

.cmdk:
    mov rax, [vch2]
    cmp rax, 13
    je .cmd_enter
    cmp rax, 8
    je .cmd_bs
    cmp rax, 32
    jb .next
    cmp rax, 126
    ja .next
    cmp qword [vcmdlen], 60
    jae .next
    mov rcx, [vcmdlen]
    lea rdx, [vcmd]
    mov [rdx + rcx], al
    inc qword [vcmdlen]
    mov rcx, [vcmdlen]
    mov byte [rdx + rcx], 0
    jmp .next
.cmd_bs:
    cmp qword [vcmdlen], 0
    je .cmd_cancel
    dec qword [vcmdlen]
    mov rcx, [vcmdlen]
    lea rdx, [vcmd]
    mov byte [rdx + rcx], 0
    jmp .next
.cmd_cancel:
    mov qword [vmode], 0
    jmp .next
.cmd_enter:
    call vi_cmd_exec
    jmp .next

.normk:
    mov rax, [vch2]
    cmp rax, 'h'
    je .left
    cmp rax, 'l'
    je .right
    cmp rax, 'j'
    je .down
    cmp rax, 'k'
    je .up
    cmp rax, '0'
    je .home
    cmp rax, '$'
    je .end
    cmp rax, 'i'
    je .ins
    cmp rax, 'a'
    je .app
    cmp rax, 'o'
    je .open
    cmp rax, 'x'
    je .xdel
    cmp rax, ':'
    je .colon
    jmp .next
.home:
    mov rax, [vpos]
    call vi_linestart
    mov [vpos], rax
    jmp .next
.end:
    mov rax, [vpos]
    call vi_lineend
    mov [vpos], rax
    jmp .next
.ins:
    mov qword [vmode], 1
    jmp .next
.app:
    call vi_right
    mov qword [vmode], 1
    jmp .next
.open:
    mov rax, [vpos]
    call vi_lineend
    mov [vpos], rax
    mov qword [vch2], 10
    call vi_insert_char
    mov qword [vmode], 1
    jmp .next
.xdel:
    mov rcx, [vpos]
    cmp rcx, [vlen]
    jae .next
    lea rdx, [vbuf]
    cmp byte [rdx + rcx], 10
    je .next
    call vi_delete_at
    jmp .next
.colon:
    mov qword [vmode], 2
    mov qword [vcmdlen], 0
    lea rdx, [vcmd]
    mov byte [rdx], 0
    jmp .next

.next:
    cmp qword [vquit], 0
    jne .exit
    jmp .top
.exit:
    add rsp, 40
    ret

vi_cmd_exec:
    sub rsp, 40
    mov qword [vmode], 0
    lea rsi, [vcmd]
    lea rdi, [s_cw]
    call vi_streq
    test eax, eax
    jnz .save
    lea rsi, [vcmd]
    lea rdi, [s_cwq]
    call vi_streq
    test eax, eax
    jnz .savequit
    lea rsi, [vcmd]
    lea rdi, [s_cq]
    call vi_streq
    test eax, eax
    jnz .quit
    lea rsi, [vcmd]
    lea rdi, [s_cqb]
    call vi_streq
    test eax, eax
    jnz .forcequit
    lea rax, [s_badcmd]
    mov [vmsgp], rax
    jmp .out
.save:
    call vi_save
    jmp .out
.savequit:
    call vi_save
    mov qword [vquit], 1
    jmp .out
.quit:
    cmp qword [vmod], 0
    jne .warn
.forcequit:
    mov qword [vquit], 1
    jmp .out
.warn:
    lea rax, [s_modwarn]
    mov [vmsgp], rax
.out:
    add rsp, 40
    ret

vi_streq:
.l:
    mov al, [rsi]
    cmp al, [rdi]
    jne .n
    test al, al
    jz .y
    inc rsi
    inc rdi
    jmp .l
.y:
    mov eax, 1
    ret
.n:
    xor eax, eax
    ret

vi_linestart:
.l:
    test rax, rax
    jz .r
    lea rdx, [vbuf]
    cmp byte [rdx + rax - 1], 10
    je .r
    dec rax
    jmp .l
.r:
    ret

vi_lineend:
.l:
    cmp rax, [vlen]
    jae .r
    lea rdx, [vbuf]
    cmp byte [rdx + rax], 10
    je .r
    inc rax
    jmp .l
.r:
    ret

vi_left:
    cmp qword [vpos], 0
    je .r
    dec qword [vpos]
.r:
    ret

vi_right:
    mov rax, [vpos]
    cmp rax, [vlen]
    jae .r
    lea rdx, [vbuf]
    cmp byte [rdx + rax], 10
    je .r
    inc qword [vpos]
.r:
    ret

vi_down:
    sub rsp, 40
    mov rax, [vpos]
    call vi_linestart
    mov rcx, [vpos]
    sub rcx, rax
    mov [vcol], rcx
    mov rax, [vpos]
    call vi_lineend
    cmp rax, [vlen]
    jae .done
    inc rax
    mov [vnext], rax
    call vi_lineend
    mov rdx, rax
    mov rax, [vnext]
    add rax, [vcol]
    cmp rax, rdx
    jbe .set
    mov rax, rdx
.set:
    mov [vpos], rax
.done:
    add rsp, 40
    ret

vi_up:
    sub rsp, 40
    mov rax, [vpos]
    call vi_linestart
    test rax, rax
    jz .done
    mov [vnext], rax
    mov rcx, [vpos]
    sub rcx, rax
    mov [vcol], rcx
    dec rax
    call vi_linestart
    mov rdx, [vnext]
    dec rdx
    add rax, [vcol]
    cmp rax, rdx
    jbe .set
    mov rax, rdx
.set:
    mov [vpos], rax
.done:
    add rsp, 40
    ret

vi_insert_char:
    mov rax, [vlen]
    cmp rax, VBUFMAX - 1
    jae .r
    mov rcx, [vlen]
.mv:
    cmp rcx, [vpos]
    jbe .place
    lea rdx, [vbuf]
    movzx r8d, byte [rdx + rcx - 1]
    mov [rdx + rcx], r8b
    dec rcx
    jmp .mv
.place:
    lea rdx, [vbuf]
    mov rax, [vpos]
    mov r8, [vch2]
    mov [rdx + rax], r8b
    inc qword [vlen]
    inc qword [vpos]
    mov qword [vmod], 1
.r:
    ret

vi_backspace:
    cmp qword [vpos], 0
    je .r
    dec qword [vpos]
    mov rcx, [vpos]
    call vi_delete_at
.r:
    ret

vi_delete_at:
    lea rdx, [vbuf]
.m:
    mov rax, rcx
    inc rax
    cmp rax, [vlen]
    jae .d
    movzx r8d, byte [rdx + rcx + 1]
    mov [rdx + rcx], r8b
    inc rcx
    jmp .m
.d:
    dec qword [vlen]
    mov qword [vmod], 1
    ret

vi_cursor_line:
    sub rsp, 40
    xor ecx, ecx
    xor edx, edx
.l:
    cmp rdx, [vpos]
    jae .d
    lea rax, [vbuf]
    cmp byte [rax + rdx], 10
    jne .n
    inc rcx
.n:
    inc rdx
    jmp .l
.d:
    mov [vcurline2], rcx
    mov rax, [vpos]
    call vi_linestart
    mov rcx, [vpos]
    sub rcx, rax
    mov [vcurcol2], rcx
    add rsp, 40
    ret

vi_cpz:
.l:
    movzx eax, byte [rsi]
    test eax, eax
    jz .r
    cmp r10, r11
    jae .r
    mov [r9], ax
    add r9, 2
    inc r10
    inc rsi
    jmp .l
.r:
    ret

vi_draw:
    sub rsp, 40
    mov rax, [vrow2s]
    dec rax
    mov [vtrows], rax
    call vi_cursor_line

    mov rax, [vcurline2]
    cmp rax, [vtop]
    jae .below
    mov [vtop], rax
    jmp .render
.below:
    mov rcx, rax
    sub rcx, [vtop]
    cmp rcx, [vtrows]
    jb .render
    mov rdx, rax
    sub rdx, [vtrows]
    inc rdx
    mov [vtop], rdx

.render:
    xor esi, esi
    mov rcx, [vtop]
.skipl:
    test rcx, rcx
    jz .rows
.sk:
    cmp rsi, [vlen]
    jae .rows
    lea rdx, [vbuf]
    movzx eax, byte [rdx + rsi]
    inc rsi
    cmp eax, 10
    jne .sk
    dec rcx
    jmp .skipl

.rows:
    mov [vidx], rsi
    mov qword [vr], 0
    mov qword [vdone], 0
.rl:
    mov rax, [vr]
    cmp rax, [vtrows]
    jae .status
    mov rsi, [vidx]
    lea r9, [vrow2]
    xor r10d, r10d
    mov r11, [vcols]
    dec r11
    cmp qword [vdone], 0
    je .cp
    cmp rsi, [vlen]
    jb .cp
    mov word [r9], 126
    add r9, 2
    mov r10, 1
    jmp .pad
.cp:
    cmp rsi, [vlen]
    jae .eof
    lea rdx, [vbuf]
    movzx eax, byte [rdx + rsi]
    inc rsi
    cmp eax, 10
    je .eol
    cmp r10, r11
    jae .cp
    mov [r9], ax
    add r9, 2
    inc r10
    jmp .cp
.eol:
    mov qword [vdone], 0
    jmp .pad
.eof:
    mov qword [vdone], 1
.pad:
    cmp r10, r11
    jae .term
    mov word [r9], 32
    add r9, 2
    inc r10
    jmp .pad
.term:
    mov word [r9], 0
    mov [vidx], rsi
    mov rax, [conout]
    mov rcx, rax
    xor edx, edx
    mov r8, [vr]
    call [rax + TXT_SETCURSOR]
    mov rax, [conout]
    mov rcx, rax
    lea rdx, [vrow2]
    call [rax + TXT_OUTPUTSTRING]
    inc qword [vr]
    jmp .rl

.status:
    lea r9, [vrow2]
    xor r10d, r10d
    mov r11, [vcols]
    dec r11
    cmp qword [vmode], 2
    jne .st_norm
    mov word [r9], 58
    add r9, 2
    inc r10
    lea rsi, [vcmd]
    call vi_cpz
    jmp .st_pad
.st_norm:
    mov rsi, [vmsgp]
    test rsi, rsi
    jnz .st_copy
    lea rsi, [s_normal]
    cmp qword [vmode], 1
    jne .st_copy
    lea rsi, [s_insert]
.st_copy:
    call vi_cpz
.st_pad:
    cmp r10, r11
    jae .st_term
    mov word [r9], 32
    add r9, 2
    inc r10
    jmp .st_pad
.st_term:
    mov word [r9], 0
    mov rax, [conout]
    mov rcx, rax
    xor edx, edx
    mov r8, [vrow2s]
    dec r8
    call [rax + TXT_SETCURSOR]
    mov rax, [conout]
    mov rcx, rax
    lea rdx, [vrow2]
    call [rax + TXT_OUTPUTSTRING]

    mov rax, [vmode]
    cmp rax, 2
    jne .cur_text
    mov rdx, [vcmdlen]
    inc rdx
    mov r8, [vrow2s]
    dec r8
    jmp .cur_set
.cur_text:
    mov rdx, [vcurcol2]
    cmp rdx, [vcols]
    jb .cur_c
    mov rdx, [vcols]
    dec rdx
.cur_c:
    mov r8, [vcurline2]
    sub r8, [vtop]
.cur_set:
    mov rax, [conout]
    mov rcx, rax
    call [rax + TXT_SETCURSOR]
    add rsp, 40
    ret

section .data

s_vi_usage db `usage: vi FILE\r\n`,0
s_normal   db `-- NORMAL --  :w save  :q quit  :wq save+quit`,0
s_insert   db `-- INSERT --  esc to leave`,0
s_saved    db `written`,0
s_savefail db `write failed`,0
s_modwarn  db `unsaved changes (:q! to discard)`,0
s_badcmd   db `not an editor command`,0
s_cw       db `w`,0
s_cwq      db `wq`,0
s_cq       db `q`,0
s_cqb      db `q!`,0

section .bss

vbuf      resb VBUFMAX
vlen      resq 1
vpos      resq 1
vtop      resq 1
vmode     resq 1
vmod      resq 1
vquit     resq 1
vmsgp     resq 1
vcmd      resb 64
vcmdlen   resq 1
vname     resw 256
vh        resq 1
vsz       resq 1
vst       resq 1
vsc2       resq 1
vch2       resq 1
vkey2      resd 1
vevt2      resq 1
vevidx2    resq 1
vcurline2  resq 1
vcurcol2   resq 1
vtrows    resq 1
vcols     resq 1
vrow2s     resq 1
vmode_holder  resq 1
vr        resq 1
vidx      resq 1
vdone     resq 1
vcol      resq 1
vnext     resq 1
vrow2      resw 300

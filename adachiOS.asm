%include "uefi.inc"

bits 64
default rel

global efi_main
global conout
global conin
global bs
global rt
global sys_table
global image_handle
global puts
global puts_w
global print_dec
global s_nl
global argp
global cwd_w
global root_mode

extern cmd_fetch
extern cmd_ls
extern cmd_flappy
extern cmd_cat
extern cmd_vi
extern cmd_rm
extern cmd_mkdir
extern cmd_touch
extern cmd_cp
extern cmd_mv
extern cmd_cd
extern cmd_pwd

section .text

efi_main:
    sub rsp, 40
    mov [image_handle], rcx
    mov [sys_table], rdx
    mov rax, [rdx + ST_CONOUT]
    mov [conout], rax
    mov rax, [rdx + ST_CONIN]
    mov [conin], rax
    mov rax, [rdx + ST_RUNTIME]
    mov [rt], rax
    mov rax, [rdx + ST_BOOTSERVICES]
    mov [bs], rax

    call setbigmode

    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]

    mov rcx, [conout]
    mov edx, 1
    mov rax, [conout]
    call [rax + TXT_ENABLECURSOR]

    lea rsi, [s_banner]
    call puts

.prompt_loop:
    lea rsi, [s_prompt]
    call puts
    lea rsi, [cwd_w]
    call puts_w
    lea rsi, [s_prompt2]
    call puts
    call readline
    call dispatch
    jmp .prompt_loop

setbigmode:
    sub rsp, 40
    mov rax, [conout]
    mov rax, [rax + 72]
    mov eax, [rax]
    mov [maxmode], rax
    mov qword [bestmode], 0
    mov qword [bestarea], 0
    mov qword [modei], 0
.loop:
    mov rax, [modei]
    cmp rax, [maxmode]
    jae .set
    mov rcx, [conout]
    mov rdx, [modei]
    lea r8, [qcols]
    lea r9, [qrows]
    mov rax, [conout]
    call [rax + TXT_QUERYMODE]
    test rax, rax
    jnz .next
    mov rax, [qcols]
    imul rax, [qrows]
    cmp rax, [bestarea]
    jbe .next
    mov [bestarea], rax
    mov rax, [modei]
    mov [bestmode], rax
.next:
    inc qword [modei]
    jmp .loop
.set:
    mov rcx, [conout]
    mov rdx, [bestmode]
    mov rax, [conout]
    call [rax + TXT_SETMODE]
    add rsp, 40
    ret

puts_w:
    sub rsp, 40
    mov rcx, [conout]
    mov rdx, rsi
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    add rsp, 40
    ret

puts:
    sub rsp, 40
    lea rdi, [wbuf]
.c:
    mov al, [rsi]
    test al, al
    jz .done
    movzx eax, al
    mov [rdi], ax
    inc rsi
    add rdi, 2
    jmp .c
.done:
    mov word [rdi], 0
    mov rcx, [conout]
    lea rdx, [wbuf]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    add rsp, 40
    ret

print_dec:
    sub rsp, 40
    lea rdi, [numbuf + 31]
    mov byte [rdi], 0
    mov rcx, 10
.d:
    xor edx, edx
    div rcx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .d
    mov rsi, rdi
    call puts
    add rsp, 40
    ret

readline:
    sub rsp, 40
    mov qword [linelen], 0
    mov qword [hist_nav], 0
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
    jnz .wait

    movzx ecx, word [key]
    test ecx, ecx
    jnz .scan

    movzx eax, word [key + 2]
    cmp ax, 13
    je .enter
    cmp ax, 8
    je .backspace
    cmp ax, 32
    jb .wait
    cmp qword [linelen], 255
    jae .wait

    mov rcx, [linelen]
    lea rdx, [linebuf]
    mov [rdx + rcx*2], ax
    inc qword [linelen]

    mov [echobuf], ax
    mov word [echobuf + 2], 0
    mov rcx, [conout]
    lea rdx, [echobuf]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    jmp .wait

.enter:
    mov rcx, [linelen]
    lea rdx, [linebuf]
    mov word [rdx + rcx*2], 0
    call hist_push
    lea rsi, [s_nl]
    call puts
    add rsp, 40
    ret

.backspace:
    cmp qword [linelen], 0
    je .wait
    dec qword [linelen]
    lea rsi, [s_bs]
    call puts
    jmp .wait

.scan:
    cmp ecx, 1
    je .hup
    cmp ecx, 2
    je .hdown
    jmp .wait

.hup:
    mov rax, [hist_count]
    cmp [hist_nav], rax
    jae .wait
    cmp qword [hist_nav], 0
    jne .hup_inc
    call save_live
.hup_inc:
    inc qword [hist_nav]
    call show_hist
    jmp .wait

.hdown:
    cmp qword [hist_nav], 0
    je .wait
    dec qword [hist_nav]
    cmp qword [hist_nav], 0
    jne .hdown_show
    call erase_line
    call restore_live
    call echo_line
    jmp .wait
.hdown_show:
    call show_hist
    jmp .wait

hist_push:
    sub rsp, 40
    cmp qword [linelen], 0
    je .x
    mov rax, [hist_head]
    shl rax, 9
    lea rdi, [hist]
    add rdi, rax
    lea rsi, [linebuf]
    mov rcx, 256
    rep movsw
    mov rax, [hist_head]
    inc rax
    and rax, 15
    mov [hist_head], rax
    cmp qword [hist_count], 16
    jae .x
    inc qword [hist_count]
.x:
    add rsp, 40
    ret

hist_load:
    sub rsp, 40
    shl rax, 9
    lea rsi, [hist]
    add rsi, rax
    lea rdi, [linebuf]
    xor ecx, ecx
.c:
    cmp rcx, 255
    jae .d
    movzx edx, word [rsi + rcx*2]
    mov [rdi + rcx*2], dx
    test edx, edx
    jz .d
    inc rcx
    jmp .c
.d:
    mov word [rdi + rcx*2], 0
    mov [linelen], rcx
    add rsp, 40
    ret

show_hist:
    sub rsp, 40
    call erase_line
    mov rax, [hist_head]
    sub rax, [hist_nav]
    and rax, 15
    call hist_load
    call echo_line
    add rsp, 40
    ret

erase_line:
    sub rsp, 40
.e:
    cmp qword [linelen], 0
    je .x
    lea rsi, [s_bs]
    call puts
    dec qword [linelen]
    jmp .e
.x:
    add rsp, 40
    ret

echo_line:
    sub rsp, 40
    mov rax, [conout]
    mov rcx, rax
    lea rdx, [linebuf]
    call [rax + TXT_OUTPUTSTRING]
    add rsp, 40
    ret

save_live:
    sub rsp, 40
    mov rcx, [linelen]
    lea rdx, [linebuf]
    mov word [rdx + rcx*2], 0
    lea rsi, [linebuf]
    lea rdi, [livebuf]
    mov rcx, 256
    rep movsw
    add rsp, 40
    ret

restore_live:
    sub rsp, 40
    lea rsi, [livebuf]
    lea rdi, [linebuf]
    mov rcx, 256
    rep movsw
    xor ecx, ecx
    lea rdx, [linebuf]
.l:
    cmp word [rdx + rcx*2], 0
    je .x
    inc rcx
    jmp .l
.x:
    mov [linelen], rcx
    add rsp, 40
    ret

dispatch:
    sub rsp, 40
.restart:
    cmp word [linebuf], 0
    je .out

    lea rdi, [linebuf]
.findsp:
    mov ax, [rdi]
    test ax, ax
    jz .setargs
    cmp ax, 32
    je .gotsp
    add rdi, 2
    jmp .findsp
.gotsp:
    add rdi, 2
.setargs:
    mov [argp], rdi

    lea rsi, [n_sudo]
    call cmd_is
    test eax, eax
    jz .dispatch

    cmp byte [root_mode], 0
    jne .sudo_root
    mov rsi, [argp]
    cmp word [rsi], 0
    je .sudo_use
    lea rdi, [linebuf]
.mvarg:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .mvarg
    mov byte [root_mode], 1
    jmp .restart
.sudo_root:
    lea rsi, [s_sudo_root]
    call puts
    jmp .out
.sudo_use:
    lea rsi, [s_sudo_use]
    call puts
    jmp .out

.dispatch:
    mov qword [tabidx], 0

.try:
    mov rax, [tabidx]
    shl rax, 4
    lea rcx, [cmdtab]
    mov rsi, [rcx + rax]
    test rsi, rsi
    jz .unknown
    call cmd_is
    test eax, eax
    jnz .found
    inc qword [tabidx]
    jmp .try

.found:
    mov rax, [tabidx]
    shl rax, 4
    lea rcx, [cmdtab]
    call [rcx + rax + 8]
    mov byte [root_mode], 0
    jmp .out

.unknown:
    lea rsi, [s_unknown]
    call puts
.out:
    add rsp, 40
    ret

cmd_is:
    lea rdi, [linebuf]
.l:
    movzx eax, byte [rsi]
    test al, al
    jz .end
    movzx ecx, word [rdi]
    cmp ecx, eax
    jne .no
    inc rsi
    add rdi, 2
    jmp .l
.end:
    movzx ecx, word [rdi]
    test ecx, ecx
    jz .yes
    cmp ecx, 32
    je .yes
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

cmd_help:
    sub rsp, 40
    lea rsi, [s_help]
    call puts
    add rsp, 40
    ret

cmd_echo:
    sub rsp, 40
    mov rcx, [conout]
    mov rdx, [argp]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    lea rsi, [s_nl]
    call puts
    add rsp, 40
    ret

cmd_clear:
    sub rsp, 40
    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]
    add rsp, 40
    ret

cmd_uname:
    sub rsp, 40
    lea rsi, [s_uname]
    call puts
    add rsp, 40
    ret

cmd_meow:
    sub rsp, 40
    lea rsi, [s_meow]
    call puts
    add rsp, 40
    ret

cmd_reboot:
    sub rsp, 40
    mov rax, [rt]
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call [rax + RT_RESETSYSTEM]
    add rsp, 40
    ret

cmd_poweroff:
    sub rsp, 40
    mov rax, [rt]
    mov ecx, 2
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call [rax + RT_RESETSYSTEM]
    add rsp, 40
    ret

section .data

s_banner  db `\r\n  adachiOS 0.2 - a tiny os :3\r\n  type 'help' if you are lost\r\n\r\n`,0
s_prompt  db `:3 adachiOS:`,0
s_prompt2 db `> `,0
s_help    db `commands:\r\n  help      show this list\r\n  echo      echo your words back\r\n  clear     clear the screen\r\n  fetch     system, cpu and memory info\r\n  pwd       print the current directory\r\n  cd        change directory (cd DIR, cd to go home)\r\n  ls        list a directory (ls [DIR])\r\n  cat       print a file (cat FILE)\r\n  vi        edit a file (vi FILE, needs sudo outside /home)\r\n  touch     create an empty file (touch FILE)\r\n  mkdir     create a directory (mkdir DIR)\r\n  rm        delete a file (rm FILE)\r\n  cp        copy a file (cp SRC DST)\r\n  mv        move a file (mv SRC DST)\r\n  uname     kernel info\r\n  meow      :3\r\n  sudo      run one command as root (sudo CMD)\r\n  flappy    play flappy bird (space/w flap, q quit)\r\n  reboot    cold reboot\r\n  poweroff  power off\r\n  up/down   recall previous commands\r\n`,0
s_unknown db `adachiOS: command not found (rude)\r\n`,0
s_sudo_use  db `usage: sudo CMD   (you start with only /home, sudo is root)\r\n`,0
s_sudo_root db `sudo: you are already root for this command\r\n`,0
s_uname   db `adachiOS 0.2 x86_64 UEFI\r\n`,0
s_meow    db `meow :3\r\n`,0
s_nl      db `\r\n`,0
s_bs      db 8,' ',8,0

n_help     db `help`,0
n_cd       db `cd`,0
n_pwd      db `pwd`,0
n_echo     db `echo`,0
n_clear    db `clear`,0
n_fetch    db `fetch`,0
n_ls       db `ls`,0
n_cat      db `cat`,0
n_vi       db `vi`,0
n_touch    db `touch`,0
n_mkdir    db `mkdir`,0
n_rm       db `rm`,0
n_cp       db `cp`,0
n_mv       db `mv`,0
n_uname    db `uname`,0
n_meow     db `meow`,0
n_sudo     db `sudo`,0
n_reboot   db `reboot`,0
n_poweroff db `poweroff`,0
n_flappy   db `flappy`,0

cmdtab:
    dq n_help,     cmd_help
    dq n_cd,       cmd_cd
    dq n_pwd,      cmd_pwd
    dq n_echo,     cmd_echo
    dq n_clear,    cmd_clear
    dq n_fetch,    cmd_fetch
    dq n_ls,       cmd_ls
    dq n_cat,      cmd_cat
    dq n_vi,       cmd_vi
    dq n_touch,    cmd_touch
    dq n_mkdir,    cmd_mkdir
    dq n_rm,       cmd_rm
    dq n_cp,       cmd_cp
    dq n_mv,       cmd_mv
    dq n_uname,    cmd_uname
    dq n_meow,     cmd_meow
    dq n_flappy,   cmd_flappy
    dq n_reboot,   cmd_reboot
    dq n_poweroff, cmd_poweroff
    dq 0, 0

section .data
cwd_w    dw 0x5C, 'h', 'o', 'm', 'e', 0
times 254 dw 0

section .bss

image_handle resq 1
sys_table    resq 1
conout       resq 1
conin        resq 1
rt           resq 1
bs           resq 1
root_mode    resb 1

linelen      resq 1
evt          resq 1
evidx        resq 1
key          resd 1
echobuf      resw 2
linebuf      resw 256
livebuf      resw 256
argp         resq 1
tabidx       resq 1
wbuf         resb 1024
numbuf       resb 32

hist         resw 4096
hist_head    resq 1
hist_count   resq 1
hist_nav     resq 1

maxmode      resq 1
modei        resq 1
bestmode     resq 1
bestarea     resq 1
qcols        resq 1
qrows        resq 1

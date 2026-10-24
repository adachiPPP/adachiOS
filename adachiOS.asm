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

cmd_whoami:
    sub rsp, 40
    lea rsi, [s_whoami]
    call puts
    add rsp, 40
    ret

cmd_hostname:
    sub rsp, 40
    lea rsi, [s_hostname]
    call puts
    add rsp, 40
    ret

cmd_yes:
    sub rsp, 40
    mov ecx, 10
.L_yes_loop:
    mov rax, [conin]
    lea rdx, [numbuf]
    sub rsp, 40
    call [rax + 8]
    add rsp, 40
    test rax, rax
    jnz .L_yes_print
    movzx eax, word [numbuf + 2]
    cmp ax, 3
    je .L_yes_done
    cmp ax, 0x001B
    je .L_yes_done
    cmp ax, 'q'
    je .L_yes_done
    cmp ax, 'Q'
    je .L_yes_done
.L_yes_print:
    lea rsi, [s_yes_word]
    call puts
    dec ecx
    jnz .L_yes_loop
.L_yes_done:
    add rsp, 40
    ret

cmd_seq:
    sub rsp, 40
    mov rax, [argp]
    xor rcx, rcx
    mov rsi, rax
.L_seq_parse:
    movzx eax, word [rsi]
    test ax, ax
    jz .L_seq_done_parse
    cmp ax, '0'
    jb .L_seq_done_parse
    cmp ax, '9'
    ja .L_seq_done_parse
    sub ax, '0'
    imul rcx, 10
    add rcx, rax
    add rsi, 2
    jmp .L_seq_parse
.L_seq_done_parse:
    cmp rcx, 0
    jle .L_seq_out
    mov r12, 1
.L_seq_print:
    cmp r12, rcx
    jg .L_seq_out
    mov rax, r12
    call print_dec
    lea rsi, [s_nl]
    call puts
    mov rax, [conin]
    lea rdx, [numbuf]
    sub rsp, 40
    call [rax + 8]
    add rsp, 40
    test rax, rax
    jnz .L_seq_nokey
    movzx eax, word [numbuf + 2]
    cmp ax, 3
    je .L_seq_out
    cmp ax, 0x001B
    je .L_seq_out
    cmp ax, 'q'
    je .L_seq_out
    cmp ax, 'Q'
    je .L_seq_out
.L_seq_nokey:
    inc r12
    jmp .L_seq_print
.L_seq_out:
    add rsp, 40
    ret

cmd_sleep:
    sub rsp, 40
    mov rax, [argp]
    xor rcx, rcx
    mov rsi, rax
.L_sleep_parse:
    movzx eax, word [rsi]
    test ax, ax
    jz .L_sleep_done
    cmp ax, '0'
    jb .L_sleep_done
    cmp ax, '9'
    ja .L_sleep_done
    sub ax, '0'
    imul rcx, 10
    add rcx, rax
    add rsi, 2
    jmp .L_sleep_parse
.L_sleep_done:
    cmp rcx, 0
    jle .L_sleep_out
 .L_sleep_loop:
    mov rax, [bs]
    mov edx, 1000000
    sub rsp, 40
    call [rax + 248]
    add rsp, 40
    dec rcx
    jnz .L_sleep_loop
.L_sleep_out:
    add rsp, 40
    ret


cmd_true:
    sub rsp, 40
    add rsp, 40
    ret

cmd_false:
    sub rsp, 40
    mov eax, 1
    add rsp, 40
    ret

cmd_factor:
    sub rsp, 40
    mov rax, [argp]
    xor rcx, rcx
    mov rsi, rax
.L_factor_parse:
    movzx eax, word [rsi]
    test ax, ax
    jz .L_factor_have
    cmp ax, '0'
    jb .L_factor_have
    cmp ax, '9'
    ja .L_factor_have
    sub ax, '0'
    imul rcx, 10
    add rcx, rax
    add rsi, 2
    jmp .L_factor_parse
.L_factor_have:
    cmp rcx, 2
    jl .L_factor_out
    mov r12, 2
.L_factor_loop:
    cmp r12, rcx
    jg .L_factor_out
    mov rax, rcx
    xor rdx, rdx
    div r12
    test rdx, rdx
    jnz .L_factor_next
    mov rax, r12
    call print_dec
    lea rsi, [s_nl]
    call puts
    mov rax, rcx
    xor rdx, rdx
    div r12
    mov rcx, rax
    jmp .L_factor_loop
.L_factor_next:
    inc r12
    jmp .L_factor_loop
.L_factor_out:
    cmp rcx, 1
    jle .L_factor_done
    mov rax, rcx
    call print_dec
    lea rsi, [s_nl]
    call puts
.L_factor_done:
    add rsp, 40
    ret

cmd_rev:
    sub rsp, 40
    mov rax, [argp]
    test rax, rax
    jz .L_rev_out
    mov rsi, rax
    xor rcx, rcx
.L_rev_len:
    movzx eax, word [rsi + rcx*2]
    test ax, ax
    jz .L_rev_print
    inc rcx
    jmp .L_rev_len
.L_rev_print:
    cmp rcx, 0
    jz .L_rev_nl
.L_rev_char:
    dec rcx
    movzx eax, word [rsi + rcx*2]
    mov [numbuf], al
    mov byte [numbuf + 1], 0
    lea rsi, [numbuf]
    call puts
    test rcx, rcx
    jnz .L_rev_char
.L_rev_nl:
    lea rsi, [s_nl]
    call puts
.L_rev_out:
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

s_banner  db `\r\n  adachiOS 0.3 - a tiny os :3\r\n  type 'help' if you are lost\r\n\r\n`,0
s_prompt  db `:3 adachiOS:`,0
s_prompt2 db `> `,0
s_help    db `commands:\r\n  help      show this list\r\n  echo      echo your words back\r\n  clear     clear the screen\r\n  fetch     system, cpu and memory info\r\n  pwd       print the current directory\r\n  cd        change directory (cd DIR, cd to go home)\r\n  ls        list a directory (ls [DIR])\r\n  cat       print a file (cat FILE)\r\n  vi        edit a file (vi FILE, needs sudo outside /home)\r\n  touch     create an empty file (touch FILE)\r\n  mkdir     create a directory (mkdir DIR)\r\n  rm        delete a file (rm FILE)\r\n  cp        copy a file (cp SRC DST)\r\n  mv        move a file (mv SRC DST)\r\n  uname     kernel info\r\n  meow      :3\r\n  true      do nothing\r\n  false     do nothing\r\n  factor N  factor a number\r\n  rev TEXT  reverse text\r\n  whoami    show user\r\n  hostname  show host\r\n  yes       repeat text\r\n  seq N     print 1..N\r\n  sleep N   wait seconds\r\n  sudo      run one command as root (sudo CMD)\r\n  flappy    play flappy bird (space/w flap, q quit)\r\n  reboot    cold reboot\r\n  poweroff  power off\r\n  up/down   recall previous commands\r\n`,0
s_unknown db `adachiOS: command not found (rude)\r\n`,0
s_sudo_use  db `usage: sudo CMD   (you start with only /home, sudo is root)\r\n`,0
s_sudo_root db `sudo: you are already root for this command\r\n`,0
s_uname   db `adachiOS 0.3 x86_64 UEFI\r\n`,0
s_meow    db `meow :3\r\n`,0
s_whoami  db `adachi\r\n`,0
s_hostname db `adachios\r\n`,0
s_yes_word db `y\r\n`,0
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
n_true     db `true`,0
n_false    db `false`,0
n_factor   db `factor`,0
n_rev      db `rev`,0
n_whoami   db `whoami`,0
n_hostname db `hostname`,0
n_yes      db `yes`,0
n_seq      db `seq`,0
n_sleep    db `sleep`,0
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
    dq n_true,     cmd_true
    dq n_false,    cmd_false
    dq n_factor,   cmd_factor
    dq n_rev,      cmd_rev
    dq n_whoami,   cmd_whoami
    dq n_hostname, cmd_hostname
    dq n_yes,      cmd_yes
    dq n_seq,      cmd_seq
    dq n_sleep,    cmd_sleep
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

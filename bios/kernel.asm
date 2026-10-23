bits 16
org 0x0000

KSEG        equ 0x1000
SCR_SEG     equ 0x1C00
SCR_OFF     equ 0xC000
ROOT_LBA    equ 19
ROOT_SECT   equ 14
ROOT_ENT    equ 224
DATA_LBA    equ 33
MAXLINE     equ 96

start:
    cli
    mov ax, KSEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    mov [drive], dl

    mov ax, 0x0003
    int 0x10

    mov si, s_banner
    call puts

.main:
    mov si, s_prompt
    call puts
    call readline
    call dispatch
    jmp .main



putc:
    push ax
    push bx
    push cx
    push dx
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret

puts:
    push ax
    push si
.l:
    lodsb
    test al, al
    jz .d
    call putc
    jmp .l
.d:
    pop si
    pop ax
    ret

print_dec:
    pusha
    xor cx, cx
    mov bx, 10
.d:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .d
.p:
    pop ax
    add al, '0'
    call putc
    loop .p
    popa
    ret

newline:
    mov al, 13
    call putc
    mov al, 10
    call putc
    ret



readline:
    mov ax, KSEG
    mov es, ax
    mov di, linebuf
    xor cx, cx
.loop:
    xor ah, ah
    int 0x16
    cmp al, 13
    je .enter
    cmp al, 8
    je .bs
    cmp al, 32
    jb .loop
    cmp cx, MAXLINE - 1
    jae .loop
    stosb
    inc cx
    call putc
    jmp .loop
.bs:
    test cx, cx
    jz .loop
    dec cx
    dec di
    mov al, 8
    call putc
    mov al, ' '
    call putc
    mov al, 8
    call putc
    jmp .loop
.enter:
    mov al, 0
    stosb
    call newline
    ret



dispatch:
    cmp byte [linebuf], 0
    je .ret

    mov word [argp], 0
    mov si, linebuf
.find:
    mov al, [si]
    test al, al
    jz .go
    cmp al, ' '
    je .space
    inc si
    jmp .find
.space:
    mov byte [si], 0
    inc si
    mov [argp], si
.go:
    mov bx, cmdtab
.try:
    mov si, [bx]
    test si, si
    jz .unknown
    mov di, linebuf
    call strcmp
    test al, al
    jnz .found
    add bx, 4
    jmp .try
.found:
    call word [bx + 2]
.ret:
    ret
.unknown:
    mov si, s_unknown
    call puts
    ret


strcmp:
.l:
    mov al, [si]
    test al, al
    jz .end
    mov ah, [di]
    cmp al, ah
    jne .no
    inc si
    inc di
    jmp .l
.end:
    cmp byte [di], 0
    jne .no
    mov al, 1
    ret
.no:
    xor al, al
    ret




read_sector:
    push ax
    push bx
    push cx
    push dx
    push di
    mov di, ax
    xor dx, dx
    mov cx, 36
    div cx
    mov ch, al
    mov ax, dx
    xor dx, dx
    mov cl, 18
    div cl
    mov dh, al
    mov cl, ah
    inc cl
    mov dl, [drive]
    mov ax, 0x0201
    int 0x13
    jc disk_error
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

write_sector:
    push ax
    push bx
    push cx
    push dx
    push di
    mov di, ax
    xor dx, dx
    mov cx, 36
    div cx
    mov ch, al
    mov ax, dx
    xor dx, dx
    mov cl, 18
    div cl
    mov dh, al
    mov cl, ah
    inc cl
    mov dl, [drive]
    mov ax, 0x0301
    int 0x13
    jc disk_error
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

disk_error:
    mov si, s_disk
    call puts
.h:
    cli
    hlt
    jmp .h


load_root:
    push ax
    push bx
    push cx
    push es
    mov ax, SCR_SEG
    mov es, ax
    xor bx, bx
    mov ax, ROOT_LBA
    mov cx, ROOT_SECT
.rd:
    call read_sector
    inc ax
    add bx, 512
    loop .rd
    pop es
    pop cx
    pop bx
    pop ax
    ret



cmd_help:
    mov si, s_help
    call puts
    ret

cmd_echo:
    mov si, [argp]
    test si, si
    jz .nl
    call puts
.nl:
    call newline
    ret

cmd_clear:
    mov ax, 0x0003
    int 0x10
    ret

cmd_fetch:
    mov si, s_f_head
    call puts
    mov si, s_f_arch
    call puts
    call mem_probe
    mov si, s_f_mem
    call puts
    mov ax, [mem_mib]
    call print_dec
    mov si, s_f_mib
    call puts
    mov si, s_f_low
    call puts
    mov ax, [mem_lo]
    call print_dec
    mov si, s_f_kib
    call puts
    mov si, s_f_boot
    call puts
    mov al, [drive]
    add al, '0'
    call putc
    call newline
    ret

mem_probe:
    int 0x12
    mov [mem_lo], ax
    mov word [mem_kb], ax
    mov word [mem_kb + 2], 0
    mov ax, 0xE801
    int 0x15
    jc .fallback
    add word [mem_kb], ax
    adc word [mem_kb + 2], 0
    mov ax, bx
    xor dx, dx
    mov cx, 6
.shift:                         ; this KILLED me
    shl ax, 1
    rcl dx, 1
    loop .shift
    add word [mem_kb], ax
    adc word [mem_kb + 2], dx
    jmp .calc
.fallback:
    mov ax, 0x88
    int 0x15
    jc .calc
    add word [mem_kb], ax
    adc word [mem_kb + 2], 0
.calc:
    mov ax, [mem_kb]
    mov dx, [mem_kb + 2]
    mov cx, 10
.shr:
    shr dx, 1
    rcr ax, 1
    loop .shr
    mov [mem_mib], ax
    ret

cmd_uname:
    mov si, s_uname
    call puts
    ret

cmd_meow:
    mov si, s_meow
    call puts
    ret

cmd_sudo:
    mov si, s_sudo
    call puts
    ret

cmd_reboot:
    mov al, 0xFE
    out 0x64, al
    jmp 0xFFFF:0x0000

cmd_poweroff:
    mov ax, 0x5301
    xor bx, bx
    int 0x15
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    mov ax, 0x2000
    mov dx, 0x0604
    out dx, ax
    mov dx, 0xB004
    out dx, ax
    mov si, s_off
    call puts
.h:
    cli
    hlt
    jmp .h

cmd_ls:
    call load_root
    mov si, SCR_OFF
    mov cx, ROOT_ENT
.ent:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 0xE5
    je .next
    mov al, [si + 11]
    cmp al, 0x0F
    je .next
    test al, 0x08
    jnz .next
    call print_name
    mov al, [si + 11]
    test al, 0x10
    jz .nl
    mov al, '/'
    call putc
.nl:
    call newline
.next:
    add si, 32
    dec cx
    jnz .ent
.done:
    ret

print_name:
    push si
    push cx
    xor bx, bx
    mov cx, 8
.n:
    mov al, [si + bx]
    cmp al, ' '
    je .skip
    call putc
.skip:
    inc bx
    loop .n
    mov al, [si + 8]
    cmp al, ' '
    je .done
    mov al, '.'
    call putc
    xor bx, bx
    mov cx, 3
.e:
    mov al, [si + 8 + bx]
    cmp al, ' '
    je .eskip
    call putc
.eskip:
    inc bx
    loop .e
.done:
    pop cx
    pop si
    ret

cmd_cat:
    mov si, [argp]
    test si, si
    jz .usage
    cmp byte [si], 0
    je .usage

    call build_name
    call load_root

    mov si, SCR_OFF
    mov cx, ROOT_ENT
.scan:
    mov al, [si]
    test al, al
    jz .nf
    xor bx, bx
.cmp:
    mov al, [si + bx]
    cmp al, [name83 + bx]
    jne .next
    inc bx
    cmp bx, 11
    jne .cmp
    jmp .found
.next:
    add si, 32
    dec cx
    jnz .scan
    jmp .nf

.found:
    mov ax, [si + 26]
    mov [cluster], ax
    mov ax, [si + 28]
    mov [fsize], ax
    mov ax, [si + 30]
    mov [fsize + 2], ax

.rd:
    mov ax, [fsize]
    or ax, [fsize + 2]
    jz .done
    mov ax, [cluster]
    cmp ax, 2
    jb .done
    cmp ax, 0xFF8
    jae .done
    add ax, DATA_LBA - 2

    mov bx, 0
    mov dx, SCR_SEG
    mov es, dx
    call read_sector

    mov bp, [fsize]
    cmp bp, 512
    jbe .sz
    mov bp, 512
.sz:
    mov si, SCR_OFF
    mov cx, bp
.pr:
    mov al, [si]
    inc si
    cmp al, 10
    jne .raw
    mov al, 13
    call putc
    mov al, 10
.raw:
    call putc
    loop .pr

    mov ax, [fsize]
    sub ax, bp
    mov [fsize], ax
    mov ax, [fsize + 2]
    sbb ax, 0                   ; mreow
    mov [fsize + 2], ax


    mov ax, [cluster]
    mov dx, ax
    shr ax, 1
    add ax, dx
    xor dx, dx
    mov cx, 512
    div cx
    mov [fat_off], dx

    mov bx, 0
    mov dx, SCR_SEG
    mov es, dx
    add ax, 1
    call read_sector
    inc ax
    add bx, 512
    call read_sector            ; gfdesbjdbshbhbhj

    mov si, [fat_off]
    mov ax, [si + SCR_OFF]
    mov dx, [cluster]
    test dx, 1
    jz .even
    shr ax, 4
    jmp .set
.even:
    and ax, 0x0FFF
.set:
    mov [cluster], ax
    jmp .rd

.done:
    ret
.nf:
    mov si, s_cat_nf
    call puts
    ret
.usage:
    mov si, s_cat_use
    call puts
    ret


build_name:
    mov di, name83
    mov cx, 11
    mov al, ' '
    rep stosb

    mov si, [argp]
    mov di, name83
    xor bx, bx
.base:
    mov al, [si]
    test al, al
    jz .done
    cmp al, '.'
    je .ext
    cmp al, 'a'
    jb .store
    cmp al, 'z'
    ja .store
    sub al, 32
.store:
    cmp bx, 8
    jae .bskip
    mov [di + bx], al
    inc bx
.bskip:
    inc si
    jmp .base
.ext:
    inc si
    xor bx, bx
.extloop:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 'a'
    jb .estore
    cmp al, 'z'
    ja .estore
    sub al, 32
.estore:
    cmp bx, 3
    jae .eskip
    mov [di + 8 + bx], al
    inc bx
.eskip:
    inc si
    jmp .extloop
.done:
    ret



s_banner    db `\r\n  adachiOS 0.1 - a tiny os :3 (bios build)\r\n  type 'help' if you are lost\r\n\r\n`,0
s_prompt    db `:3 adachiOS> `,0
s_help      db `commands:\r\n  help      show this list\r\n  echo      echo your words back\r\n  clear     clear the screen\r\n  fetch     system and memory info\r\n  ls        list the boot floppy\r\n  cat       print a file (cat FILE)\r\n  vi        edit a file (vi FILE)\r\n  flappy    play flappy bird (space/w flap, q quit)\r\n  uname     kernel info\r\n  meow      :3\r\n  sudo      do not\r\n  reboot    reboot\r\n  poweroff  power off\r\n`,0
s_unknown   db `adachiOS: command not found (rude)\r\n`,0
s_uname     db `adachiOS 0.1 i386 BIOS (16-bit real mode)\r\n`,0
s_meow      db `meow :3\r\n`,0
s_sudo      db `nice try. this incident will be reported.\r\n`,0
s_disk      db `adachiOS: disk read error\r\n`,0
s_cat_use   db `usage: cat FILE\r\n`,0
s_cat_nf    db `cat: no such file\r\n`,0
s_off       db `poweroff failed, halting.\r\n`,0
s_f_head    db `\r\n  adachiOS fetch\r\n  --------------\r\n`,0
s_f_arch    db `  arch:     i386 (16-bit real mode)\r\n`,0
s_f_mem     db `  memory:   `,0
s_f_mib     db ` MiB total\r\n`,0
s_f_low     db `  low:      `,0
s_f_kib     db ` KiB\r\n`,0
s_f_boot    db `  boot:     drive 0x`,0

n_help      db `help`,0
n_echo      db `echo`,0
n_clear     db `clear`,0
n_fetch     db `fetch`,0
n_ls        db `ls`,0
n_cat       db `cat`,0
n_vi        db `vi`,0
n_flappy    db `flappy`,0
n_uname     db `uname`,0
n_meow      db `meow`,0
n_sudo      db `sudo`,0
n_reboot    db `reboot`,0
n_poweroff  db `poweroff`,0

cmdtab:
    dw n_help,     cmd_help
    dw n_echo,     cmd_echo
    dw n_clear,    cmd_clear
    dw n_fetch,    cmd_fetch
    dw n_ls,       cmd_ls
    dw n_cat,      cmd_cat
    dw n_vi,       cmd_vi
    dw n_flappy,   cmd_flappy
    dw n_uname,    cmd_uname
    dw n_meow,     cmd_meow
    dw n_sudo,     cmd_sudo
    dw n_reboot,   cmd_reboot
    dw n_poweroff, cmd_poweroff
    dw 0, 0

drive    db 0
argp     dw 0
mem_kb   dd 0
mem_mib  dw 0
mem_lo   dw 0
cluster  dw 0
fat_off  dw 0
fsize    dd 0
name83   times 11 db ' '
linebuf  times MAXLINE db 0

%include "bios/flappy.asm"
%include "bios/vi.asm"

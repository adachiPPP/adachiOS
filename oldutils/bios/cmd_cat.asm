%include "bios/prog.inc"

cmd_main:
    mov si, [argp]
    test si, si
    jz .usage
    cmp byte [si], 0
    je .usage
    call resolve
    cmp byte [res_err], 0
    jne .nf
    mov ax, [res_dir]
    call dir_load
    call dir_find
    test al, al
    jz .nf
    test byte [res_attr], 0x10
    jnz .isdir
    mov ax, [res_first]
    mov [cluster], ax
    mov ax, [res_size]
    mov [fsize], ax
    mov ax, [res_size + 2]
    mov [fsize + 2], ax
.rd:
    mov ax, [fsize]
    or ax, [fsize + 2]
    jz .ok
    mov ax, [cluster]
    cmp ax, 2
    jb .ok
    cmp ax, 0xFF8
    jae .ok
    add ax, DATA_LBA - 2
    mov [tmp_lba], ax
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
    mov al, [es:si]
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
    sbb ax, 0
    mov [fsize + 2], ax
    mov ax, [cluster]
    call fat_next
    mov [cluster], ax
    jmp .rd
.ok:
    ret
.nf:
    mov si, s_cat_nf
    call puts
    ret
.isdir:
    mov si, s_is_dir
    call puts
    ret
.usage:
    mov si, s_cat_use
    call puts
    ret

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

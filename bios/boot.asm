bits 16
org 0x7c3e

KERNEL_SEG  equ 0x1000
ROOT_LBA    equ 19
ROOT_SECT   equ 14
ROOT_ENT    equ 224
DATA_LBA    equ 33

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti
    mov [drive], dl

    xor ah, ah
    mov dl, [drive]
    int 0x13
    jc disk_error

    mov ax, 0x0800
    mov es, ax
    xor bx, bx
    mov ax, ROOT_LBA
    mov cx, ROOT_SECT
.root:
    call read_sector
    inc ax
    add bx, 512
    loop .root

    mov si, 0x8000
    mov cx, ROOT_ENT
.scan:
    mov al, [si]
    test al, al
    jz not_found
    cmp al, 0xE5
    je .next
    xor bx, bx
.cmp:
    mov al, [si + bx]
    cmp al, [kname + bx]
    jne .next
    inc bx
    cmp bx, 11
    jne .cmp
    jmp found
.next:
    add si, 32
    dec cx
    jnz .scan
    jmp not_found

found:
    mov ax, [si + 26]
    mov [cluster], ax
    mov ax, KERNEL_SEG
    mov es, ax
    xor bx, bx
.load:
    mov ax, [cluster]
    cmp ax, 2
    jb loaded
    cmp ax, 0xFF8
    jae loaded
    add ax, DATA_LBA - 2
    call read_sector
    add bx, 512

    mov ax, [cluster]
    mov dx, ax
    shr ax, 1
    add ax, dx
    xor dx, dx
    mov cx, 512
    div cx
    mov [fat_off], dx

    push es
    push bx
    mov bx, 0
    mov dx, 0x0840
    mov es, dx
    add ax, 1
    call read_sector
    inc ax
    add bx, 512
    call read_sector
    pop bx
    pop es

    mov si, [fat_off]
    mov ax, [si + 0x8400]
    mov dx, [cluster]
    test dx, 1
    jz .even
    shr ax, 4
    jmp .set
.even:
    and ax, 0x0FFF
.set:
    mov [cluster], ax
    jmp .load

loaded:
    mov dl, [drive]
    jmp KERNEL_SEG:0x0000

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

disk_error:
    mov si, s_disk
    jmp print_msg
not_found:
    mov si, s_nofile
print_msg:
    lodsb
    test al, al
    jz halt
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp print_msg
halt:
    cli
    hlt
    jmp halt

drive    db 0
cluster  dw 0
fat_off  dw 0
kname    db 'KERNEL  BIN'
s_disk   db `adachiOS: disk read error`,13,10,0
s_nofile db `adachiOS: KERNEL.BIN not found`,13,10,0

times (448 - ($ - $$)) db 0
dw 0xAA55

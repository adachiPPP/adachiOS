%include "uefi.inc"

bits 64
default rel

global cmd_fetch
global cmd_ls
global cmd_cat
global fs_open

extern conout
extern bs
extern image_handle
extern sys_table
extern puts
extern print_dec
extern s_nl
extern argp

section .text

cmd_fetch:
    sub rsp, 40

    mov qword [mmsize], 0
    lea rax, [descver]
    mov [rsp + 32], rax
    lea rcx, [mmsize]
    xor edx, edx
    lea r8, [mmkey]
    lea r9, [descsz]
    mov rax, [bs]
    call [rax + BS_GETMEMORYMAP]

    mov rax, [mmsize]
    add rax, 4096
    mov [mmsize], rax
    mov rax, [bs]
    mov ecx, 2
    mov rdx, [mmsize]
    lea r8, [mmbuf]
    call [rax + BS_ALLOCATEPOOL]
    test rax, rax
    jnz .err

    lea rax, [descver]
    mov [rsp + 32], rax
    lea rcx, [mmsize]
    mov rdx, [mmbuf]
    lea r8, [mmkey]
    lea r9, [descsz]
    mov rax, [bs]
    call [rax + BS_GETMEMORYMAP]
    test rax, rax
    jnz .err

    xor r9d, r9d
    xor r10d, r10d
    mov rdx, [descsz]
    mov r8, [mmbuf]
    mov rcx, [mmsize]
    add rcx, r8
.sum:
    cmp r8, rcx
    jae .summed
    mov rax, [r8 + 24]
    shl rax, 12
    mov r11d, [r8]
    test r11d, r11d
    jz .nxt
    cmp r11d, EFI_CONV_MEMORY
    je .free
    cmp r11d, 8
    je .nxt
    cmp r11d, 11
    jae .nxt
    add r9, rax
    jmp .nxt
.free:
    add r9, rax
    add r10, rax
.nxt:
    add r8, rdx
    jmp .sum
.summed:
    mov [tot], r9
    mov [conv], r10

    lea rsi, [s_f_head]
    call puts

    lea rsi, [s_f_fw]
    call puts
    mov rcx, [conout]
    mov rdx, [sys_table]
    mov rdx, [rdx + ST_FIRMWAREVENDOR]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]
    lea rsi, [s_nl]
    call puts

    lea rsi, [s_f_arch]
    call puts

    lea rsi, [s_f_mem]
    call puts
    mov rax, [tot]
    shr rax, 20
    call print_dec
    lea rsi, [s_f_mib]
    call puts

    lea rsi, [s_f_used]
    call puts
    mov rax, [tot]
    sub rax, [conv]
    shr rax, 20
    call print_dec
    lea rsi, [s_f_mib2]
    call puts

    lea rsi, [s_f_free]
    call puts
    mov rax, [conv]
    shr rax, 20
    call print_dec
    lea rsi, [s_f_mib3]
    call puts
    jmp .done

.err:
    lea rsi, [s_f_err]
    call puts
.done:
    add rsp, 40
    ret

cmd_ls:
    sub rsp, 40

    call fs_root_handle
    test rax, rax
    jz .err
    mov [root_ptr], rax

    mov rax, [bs]
    mov ecx, 2
    mov edx, 4096
    lea r8, [dirbuf_ptr]
    call [rax + BS_ALLOCATEPOOL]
    test rax, rax
    jnz .err

.rd:
    mov qword [dirsz], 4096
    mov rcx, [root_ptr]
    lea rdx, [dirsz]
    mov r8, [dirbuf_ptr]
    mov rax, [root_ptr]
    call [rax + FILE_READ]
    test rax, rax
    jnz .err
    cmp qword [dirsz], 0
    je .close

    mov rax, [dirbuf_ptr]
    mov [lscur], rax
    add rax, [dirsz]
    mov [lsend], rax

.ent:
    mov r8, [lscur]
    cmp r8, [lsend]
    jae .rd

    mov rcx, [conout]
    lea rdx, [r8 + 80]
    mov rax, [conout]
    call [rax + TXT_OUTPUTSTRING]

    mov r8, [lscur]
    test qword [r8 + 72], 0x10
    jz .file
    lea rsi, [s_slash]
    call puts
.file:
    lea rsi, [s_nl]
    call puts

    mov r8, [lscur]
    add r8, [r8]
    mov [lscur], r8
    jmp .ent

.close:
    mov rcx, [root_ptr]
    mov rax, [root_ptr]
    call [rax + FILE_CLOSE]
    add rsp, 40
    ret

.err:
    lea rsi, [s_ls_err]
    call puts
    add rsp, 40
    ret

fs_root_handle:
    sub rsp, 40
    mov rax, [bs]
    mov rcx, [image_handle]
    lea rdx, [guid_loaded]
    lea r8, [li_ptr]
    call [rax + BS_HANDLEPROTOCOL]
    test rax, rax
    jnz .fail

    mov rax, [li_ptr]
    mov rcx, [rax + LI_DEVICEHANDLE]
    mov rax, [bs]
    lea rdx, [guid_sfs]
    lea r8, [sfs_ptr]
    call [rax + BS_HANDLEPROTOCOL]
    test rax, rax
    jnz .fail

    mov rax, [sfs_ptr]
    mov rcx, rax
    lea rdx, [fs_rootp]
    call [rax + SFS_OPENVOLUME]
    test rax, rax
    jnz .fail

    mov rax, [fs_rootp]
    add rsp, 40
    ret
.fail:
    xor eax, eax
    add rsp, 40
    ret

fs_open:
    sub rsp, 40
    mov [fs_name], rcx
    mov [fs_mode], rdx
    call fs_root_handle
    test rax, rax
    jz .fail
    mov [fs_root], rax

    mov rcx, rax
    lea rdx, [fs_h]
    mov r8, [fs_name]
    mov r9, [fs_mode]
    mov qword [rsp + 32], 0
    call [rax + FILE_OPEN]
    mov [fs_st], rax

    mov rax, [fs_root]
    mov rcx, rax
    call [rax + FILE_CLOSE]

    cmp qword [fs_st], 0
    jne .fail
    mov rax, [fs_h]
    add rsp, 40
    ret
.fail:
    xor eax, eax
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

cmd_cat:
    sub rsp, 40
    mov rax, [argp]
    cmp word [rax], 0
    je .usage

    mov rcx, [argp]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nofile
    mov [cat_h], rax

.rd:
    mov qword [cat_sz], 4096
    mov rax, [cat_h]
    mov rcx, rax
    lea rdx, [cat_sz]
    lea r8, [catbuf]
    call [rax + FILE_READ]
    test rax, rax
    jnz .close
    mov rcx, [cat_sz]
    test rcx, rcx
    jz .close
    lea rsi, [catbuf]
    call print_bytes
    jmp .rd

.close:
    mov rax, [cat_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    add rsp, 40
    ret

.nofile:
    lea rsi, [s_cat_nf]
    call puts
    add rsp, 40
    ret

.usage:
    lea rsi, [s_cat_use]
    call puts
    add rsp, 40
    ret

section .data

guid_loaded db 0xA1,0x31,0x1B,0x5B, 0x62,0x95, 0xD2,0x11, 0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B
guid_sfs    db 0x22,0x5B,0x4E,0x96, 0x59,0x64, 0xD2,0x11, 0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B

s_slash    db `/`,0
s_ls_err   db `ls: could not read the boot volume\r\n`,0
s_cat_use  db `usage: cat FILE\r\n`,0
s_cat_nf   db `cat: no such file\r\n`,0

s_f_head  db `\r\n  adachiOS fetch\r\n  --------------\r\n`,0
s_f_fw    db `  firmware: `,0
s_f_arch  db `  arch:     x86_64\r\n`,0
s_f_mem   db `  memory:   `,0
s_f_mib   db ` MiB total\r\n`,0
s_f_used  db `  used:     `,0
s_f_mib2  db ` MiB used\r\n`,0
s_f_free  db `  free:     `,0
s_f_mib3  db ` MiB free\r\n\r\n`,0
s_f_err   db `fetch: could not read the memory map\r\n`,0

section .bss

mmsize       resq 1
mmkey        resq 1
descsz       resq 1
descver      resq 1
mmbuf        resq 1
tot          resq 1
conv         resq 1

li_ptr       resq 1
sfs_ptr      resq 1
fs_rootp     resq 1
root_ptr     resq 1
dirbuf_ptr   resq 1
dirsz        resq 1
lscur        resq 1
lsend        resq 1

fs_name      resq 1
fs_mode      resq 1
fs_root      resq 1
fs_h         resq 1
fs_st        resq 1

cat_h        resq 1
cat_sz       resq 1
catbuf       resb 4096
pbuf         resw 512
pb_src       resq 1
pb_left      resq 1

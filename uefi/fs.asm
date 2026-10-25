%include "uefi.inc"

bits 64
default rel

global fs_open
global fs_open_x
global resolve_path
global path_can_write
global need_write
global pathbuf
global pathbuf2
global prepare_two
global split_args
global args_equal
global copy_file
global print_bytes
global guid_fileinfo
global guid_loaded
global copy_nf
global copy_err
global a1
global a2
global s_home_w
global li_ptr
global fs_device

extern bs
extern image_handle
extern puts
extern argp
extern cwd_w
extern root_mode

section .text

fs_root_handle:
    sub rsp, 40
    mov rcx, [fs_device]
    test rcx, rcx
    jnz .have_device

    mov rax, [bs]
    mov rcx, [image_handle]
    lea rdx, [guid_loaded]
    lea r8, [li_ptr]
    call [rax + BS_HANDLEPROTOCOL]
    test rax, rax
    jnz .fail

    mov rax, [li_ptr]
    mov rcx, [rax + LI_DEVICEHANDLE]
.have_device:
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
    xor r8d, r8d
fs_open_x:
    sub rsp, 40
    mov [fs_name], rcx
    mov [fs_mode], rdx
    mov [fs_attr], r8
    call fs_root_handle
    test rax, rax
    jz .fail
    mov [fs_root], rax

    mov rcx, rax
    lea rdx, [fs_h]
    mov r8, [fs_name]
    mov r9, [fs_mode]
    mov rax, [fs_attr]
    mov [rsp + 32], rax
    mov rax, [fs_root]
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
    mov byte [rdi], 13
    inc rdi
    inc r9
.put:
    mov [rdi], al
    inc rdi
    inc r9
    jmp .inner
.flush:
    mov byte [rdi], 0
    lea rsi, [pbuf]
    call puts
    jmp .outer
.done:
    add rsp, 40
    ret

resolve_path:
    sub rsp, 40
    movzx eax, word [rsi]
    cmp eax, 0x5C
    je .abs
    cmp eax, 0x2F
    je .abs

    lea rdi, [pathbuf]
    lea r10, [cwd_w]
.cp_cwd:
    mov ax, [r10]
    mov [rdi], ax
    add r10, 2
    add rdi, 2
    test ax, ax
    jnz .cp_cwd
    sub rdi, 2
    jmp .comp
.abs:
    lea rdi, [pathbuf]
    mov word [rdi], 0x5C
    mov word [rdi + 2], 0
    add rdi, 2
    add rsi, 2

.comp:
    movzx eax, word [rsi]
    test eax, eax
    jz .done
    cmp eax, 0x5C
    je .sep
    cmp eax, 0x2F
    je .sep

    mov r8, rsi
.fend:
    movzx eax, word [rsi]
    test eax, eax
    jz .fend_done
    cmp eax, 0x5C
    je .fend_done
    cmp eax, 0x2F
    je .fend_done
    add rsi, 2
    jmp .fend
.fend_done:
    mov r9, rsi
    sub r9, r8
    shr r9, 1

    cmp r9, 1
    jne .two
    cmp word [r8], '.'
    je .comp
.two:
    cmp r9, 2
    jne .add
    cmp word [r8], '.'
    jne .add
    cmp word [r8 + 2], '.'
    jne .add
    call pb_up
    jmp .comp

.add:
    lea r10, [pathbuf]
    cmp rdi, r10
    je .nonsep
    cmp word [rdi - 2], 0x5C
    je .nonsep
    mov word [rdi], 0x5C
    add rdi, 2
.nonsep:
    mov rcx, r9
    lea rdx, [pathbuf + 500]
.cp:
    test rcx, rcx
    jz .cp_done
    cmp rdi, rdx
    jae .cp_done
    mov ax, [r8]
    cmp ax, 'A'
    jb .put
    cmp ax, 'Z'
    ja .put
    add ax, 32
.put:
    mov [rdi], ax
    add r8, 2
    add rdi, 2
    dec rcx
    jmp .cp
.cp_done:
    mov word [rdi], 0
    jmp .comp
.sep:
    add rsi, 2
    jmp .comp
.done:
    add rsp, 40
    ret

pb_up:
    lea rax, [pathbuf]
    cmp rdi, rax
    jbe .done
    mov rdx, rdi
    sub rdx, 2
.scan:
    cmp rdx, pathbuf
    jbe .root
    cmp word [rdx], 0x5C
    je .cut
    sub rdx, 2
    jmp .scan
.cut:
    mov rdi, rdx
    mov word [rdi], 0
    ret
.root:
    lea rdi, [pathbuf + 2]
    mov word [rdi], 0
.done:
    ret

path_can_write:
    cmp byte [root_mode], 0
    jne .yes
    mov r8, rsi
    lea rdi, [s_home_w]
.l:
    mov ax, [rdi]
    test ax, ax
    jz .pref
    cmp ax, [r8]
    jne .no
    add rdi, 2
    add r8, 2
    jmp .l
.pref:
    mov ax, [r8]
    test ax, ax
    jz .yes
    cmp ax, 0x5C
    je .yes
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

need_write:
    sub rsp, 40
    lea rsi, [pathbuf]
    call path_can_write
    test eax, eax
    jnz .ok
    lea rsi, [s_denied]
    call puts
    xor eax, eax
    add rsp, 40
    ret
.ok:
    mov eax, 1
    add rsp, 40
    ret

prepare_two:
    sub rsp, 40
    mov rsi, [a1]
    call resolve_path
    lea rsi, [pathbuf]
    lea rdi, [pathbuf2]
.cp:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .cp

    mov rsi, [a2]
    call resolve_path
    lea rsi, [pathbuf]
    call need_write
    test eax, eax
    jz .no

    lea rax, [pathbuf2]
    mov [a1], rax
    lea rax, [pathbuf]
    mov [a2], rax
    mov eax, 1
    add rsp, 40
    ret
.no:
    xor eax, eax
    add rsp, 40
    ret

split_args:
    sub rsp, 40
    mov qword [a1], 0
    mov qword [a2], 0
    mov rsi, [argp]
    test rsi, rsi
    jz .done
    mov [a1], rsi
    mov rdi, rsi
.findsp:
    movzx eax, word [rdi]
    test eax, eax
    jz .done
    cmp eax, 32
    je .sp
    add rdi, 2
    jmp .findsp
.sp:
    mov word [rdi], 0
    add rdi, 2
.skip:
    movzx eax, word [rdi]
    cmp eax, 32
    jne .set
    add rdi, 2
    jmp .skip
.set:
    test eax, eax
    jz .done
    mov [a2], rdi
.done:
    add rsp, 40
    ret

args_equal:
    mov rsi, [a1]
    mov rdi, [a2]
.l:
    mov ax, [rsi]
    cmp ax, [rdi]
    jne .no
    test ax, ax
    jz .yes
    add rsi, 2
    add rdi, 2
    jmp .l
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

copy_file:
    sub rsp, 40
    mov qword [cp_src], 0
    mov qword [cp_dst], 0

    mov rcx, [a1]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nosrc
    mov [cp_src], rax

    mov rcx, [a2]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .create
    mov rcx, rax
    call [rax + FILE_DELETE]

.create:
    mov rcx, [a2]
    mov rdx, 0x8000000000000003
    xor r8d, r8d
    call fs_open_x
    test rax, rax
    jz .fail
    mov [cp_dst], rax

.rd:
    mov qword [cp_sz], 4096
    mov rax, [cp_src]
    mov rcx, rax
    lea rdx, [cp_sz]
    lea r8, [cpbuf]
    call [rax + FILE_READ]
    test rax, rax
    jnz .fail
    mov rax, [cp_sz]
    test rax, rax
    jz .ok
    mov [cp_wsz], rax
    mov rax, [cp_dst]
    mov rcx, rax
    lea rdx, [cp_wsz]
    lea r8, [cpbuf]
    call [rax + FILE_WRITE]
    test rax, rax
    jnz .fail
    jmp .rd

.ok:
    mov rax, [cp_src]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    mov rax, [cp_dst]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    xor eax, eax
    add rsp, 40
    ret

.nosrc:
    mov rsi, [copy_nf]
    call puts
    mov eax, 1
    add rsp, 40
    ret

.fail:
    mov rsi, [copy_err]
    call puts
    mov rax, [cp_src]
    test rax, rax
    jz .e1
    mov rcx, rax
    call [rax + FILE_CLOSE]
.e1:
    mov rax, [cp_dst]
    test rax, rax
    jz .e2
    mov rcx, rax
    call [rax + FILE_CLOSE]
.e2:
    mov eax, 1
    add rsp, 40
    ret

section .data

guid_loaded db 0xA1,0x31,0x1B,0x5B, 0x62,0x95, 0xD2,0x11, 0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B
guid_sfs    db 0x22,0x5B,0x4E,0x96, 0x59,0x64, 0xD2,0x11, 0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B
guid_fileinfo db 0x92,0x6E,0x57,0x09, 0x3F,0x6D, 0xD2,0x11, 0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B

s_home_w   dw 0x5C, 'h', 'o', 'm', 'e', 0
s_denied   db `adachiOS: permission denied (that is outside /home, try rodo)\r\n`,0

section .bss

li_ptr       resq 1
sfs_ptr      resq 1
fs_rootp     resq 1
fs_device    resq 1

fs_name      resq 1
fs_mode      resq 1
fs_attr      resq 1
fs_root      resq 1
fs_h         resq 1
fs_st        resq 1

pathbuf      resw 260
pathbuf2     resw 260

a1           resq 1
a2           resq 1
cp_src       resq 1
cp_dst       resq 1
cp_sz        resq 1
cp_wsz       resq 1
copy_nf      resq 1
copy_err     resq 1
cpbuf        resb 4096
pbuf         resb 1024
pb_src       resq 1
pb_left      resq 1

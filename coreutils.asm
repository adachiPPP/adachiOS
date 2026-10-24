%include "uefi.inc"

bits 64
default rel

global cmd_fetch
global cmd_ls
global cmd_cat
global cmd_rm
global cmd_mkdir
global cmd_touch
global cmd_cp
global cmd_mv
global cmd_cd
global cmd_pwd
global fs_open
global resolve_path
global path_can_write
global need_write
global pathbuf

extern conout
extern bs
extern image_handle
extern sys_table
extern puts
extern puts_w
extern print_dec
extern s_nl
extern argp
extern cwd_w
extern root_mode

section .text

cmd_fetch:
    sub rsp, 40

    call cpu_probe

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

    lea rsi, [s_f_cpu]
    call puts
    lea rsi, [cpu_name]
    call puts
    lea rsi, [s_nl]
    call puts

    lea rsi, [s_f_cores]
    call puts
    mov rax, [cpu_cores]
    call print_dec
    lea rsi, [s_nl]
    call puts

    lea rsi, [s_f_threads]
    call puts
    mov rax, [cpu_threads]
    call print_dec
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

; fills cpu_name with the brand string (or the vendor id), plus core counts
cpu_probe:
    push rbx

    xor eax, eax
    cpuid
    mov dword [cpu_max], eax
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0

    mov qword [cpu_cores], 1
    mov qword [cpu_threads], 1

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000004
    jb .vendor

    lea rdi, [cpu_brand]
    mov eax, 0x80000002
    cpuid
    mov [rdi], eax
    mov [rdi + 4], ebx
    mov [rdi + 8], ecx
    mov [rdi + 12], edx
    mov eax, 0x80000003
    cpuid
    mov [rdi + 16], eax
    mov [rdi + 20], ebx
    mov [rdi + 24], ecx
    mov [rdi + 28], edx
    mov eax, 0x80000004
    cpuid
    mov [rdi + 32], eax
    mov [rdi + 36], ebx
    mov [rdi + 40], ecx
    mov [rdi + 44], edx
    mov byte [cpu_brand + 48], 0

    lea rsi, [cpu_brand]
.b_lead:
    cmp byte [rsi], ' '
    jne .b_end
    inc rsi
    jmp .b_lead
.b_end:
    mov rdi, rsi
.b_scan:
    cmp byte [rdi], 0
    je .b_trim
    inc rdi
    jmp .b_scan
.b_trim:
    cmp rdi, rsi
    jbe .b_done
    cmp byte [rdi - 1], ' '
    jne .b_done
    dec rdi
    jmp .b_trim
.b_done:
    mov byte [rdi], 0
    cmp byte [rsi], 0
    je .vendor

    lea rdi, [cpu_name]
.b_copy:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .b_copy
    jmp .count

.vendor:
    lea rsi, [cpu_vendor]
    lea rdi, [cpu_name]
.v_copy:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    test al, al
    jnz .v_copy

.count:
    cmp dword [cpu_max], 4
    jb .leafb
    mov eax, 4
    xor ecx, ecx
    cpuid
    shr eax, 26
    inc eax
    test eax, eax
    jz .leafb
    mov [cpu_cores], rax
.leafb:
    cmp dword [cpu_max], 0xB
    jb .leaf1
    mov eax, 0xB
    xor ecx, ecx
    cpuid
    movzx eax, bx
    test eax, eax
    jz .leaf1
    mov [cpu_threads], rax
    jmp .out
.leaf1:
    mov eax, 1
    cpuid
    mov eax, ebx
    shr eax, 16
    and eax, 0xFF
    test eax, eax
    jz .out
    mov [cpu_threads], rax
.out:
    pop rbx
    ret

cmd_ls:
    sub rsp, 40

    mov rsi, [argp]
    cmp word [rsi], 0
    jne .path
    lea rsi, [cwd_w]
    jmp .open
.path:
    call resolve_path
    lea rsi, [pathbuf]
.open:
    mov rcx, rsi
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .err
    mov [root_ptr], rax

    mov rax, [bs]
    mov ecx, 2
    mov edx, 4096
    lea r8, [dirbuf_ptr]
    call [rax + BS_ALLOCATEPOOL]
    test rax, rax
    jnz .close_err

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

    mov ax, [r8 + 80]
    cmp ax, '.'
    jne .show
    mov ax, [r8 + 82]
    test ax, ax
    jz .skipent
    cmp ax, '.'
    jne .show
    mov ax, [r8 + 84]
    test ax, ax
    jz .skipent
.show:
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

.skipent:
    mov r8, [lscur]
    add r8, [r8]
    mov [lscur], r8
    jmp .ent

.close:
    mov rcx, [root_ptr]
    mov rax, [root_ptr]
    call [rax + FILE_CLOSE]
    mov rcx, [dirbuf_ptr]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    add rsp, 40
    ret

.close_err:
    mov rcx, [root_ptr]
    mov rax, [root_ptr]
    call [rax + FILE_CLOSE]
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

    mov rsi, [argp]
    call resolve_path
    lea rcx, [pathbuf]
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

; rsi = path as typed (UTF-16) -> absolute, lowercased path in [pathbuf]
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

; eax = 1 when this path may be written (root, or anything under /home)
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

; resolves both cp/mv arguments: a1 -> pathbuf2, a2 -> pathbuf.
; only the destination has to be writable here, mv checks the source itself
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

cmd_cd:
    sub rsp, 40
    mov rsi, [argp]
    cmp word [rsi], 0
    jne .resolve
    lea rsi, [s_home_w]
    mov [cd_path], rsi
    jmp .open
.resolve:
    call resolve_path
    lea rsi, [pathbuf]
    mov [cd_path], rsi
.open:
    mov rcx, [cd_path]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nf
    mov [cd_h], rax

    mov qword [infosz], 512
    mov rcx, [cd_h]
    lea rdx, [guid_fileinfo]
    lea r8, [infosz]
    lea r9, [infobuf]
    mov rax, [cd_h]
    call [rax + FILE_GETINFO]
    mov [cd_st], rax

    mov rax, [cd_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]

    cmp qword [cd_st], 0
    jne .nf
    test byte [infobuf + 72], 0x10
    jz .notdir

    mov rsi, [cd_path]
    lea rdi, [cwd_w]
.cp:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .cp
    add rsp, 40
    ret
.nf:
    lea rsi, [s_cd_nf]
    call puts
    add rsp, 40
    ret
.notdir:
    lea rsi, [s_cd_nd]
    call puts
    add rsp, 40
    ret

cmd_pwd:
    sub rsp, 40
    lea rsi, [cwd_w]
    call puts_w
    lea rsi, [s_nl]
    call puts
    add rsp, 40
    ret

; splits "SRC DST" in place, left in [a1] and [a2] (0 when missing)
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

cmd_rm:
    sub rsp, 40
    call split_args
    mov rcx, [a1]
    test rcx, rcx
    jz .usage
    cmp word [rcx], 0
    je .usage

    mov rsi, [a1]
    call resolve_path
    lea rsi, [pathbuf]
    mov [a1], rsi
    call need_write
    test eax, eax
    jz .out

    mov rcx, [a1]
    mov rdx, 3
    call fs_open
    test rax, rax
    jnz .have
    mov rcx, [a1]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .nofile
.have:
    mov [rm_h], rax
    mov rcx, rax
    call [rax + FILE_DELETE]
    test rax, rax
    jz .done
    mov rax, [rm_h]
    mov rcx, rax
    call [rax + FILE_CLOSE]
    lea rsi, [s_rm_busy]
    call puts
    add rsp, 40
    ret
.done:
    add rsp, 40
    ret
.nofile:
    lea rsi, [s_rm_nf]
    call puts
    add rsp, 40
    ret
.out:
    add rsp, 40
    ret
.usage:
    lea rsi, [s_rm_use]
    call puts
    add rsp, 40
    ret

cmd_mkdir:
    sub rsp, 40
    call split_args
    mov rcx, [a1]
    test rcx, rcx
    jz .usage
    cmp word [rcx], 0
    je .usage

    mov rsi, [a1]
    call resolve_path
    lea rsi, [pathbuf]
    mov [a1], rsi
    call need_write
    test eax, eax
    jz .out

    mov rcx, [a1]
    mov rdx, 0x8000000000000003
    mov r8, 0x10
    call fs_open_x
    test rax, rax
    jz .fail
    mov rcx, rax
    call [rax + FILE_CLOSE]
    add rsp, 40
    ret
.fail:
    lea rsi, [s_mk_fail]
    call puts
    add rsp, 40
    ret
.out:
    add rsp, 40
    ret
.usage:
    lea rsi, [s_mk_use]
    call puts
    add rsp, 40
    ret

cmd_touch:
    sub rsp, 40
    call split_args
    mov rcx, [a1]
    test rcx, rcx
    jz .usage
    cmp word [rcx], 0
    je .usage

    mov rsi, [a1]
    call resolve_path
    lea rsi, [pathbuf]
    mov [a1], rsi
    call need_write
    test eax, eax
    jz .out

    mov rcx, [a1]
    mov rdx, 0x8000000000000003
    xor r8d, r8d
    call fs_open_x
    test rax, rax
    jz .fail
    mov rcx, rax
    call [rax + FILE_CLOSE]
    add rsp, 40
    ret
.fail:
    lea rsi, [s_touch_f]
    call puts
    add rsp, 40
    ret
.out:
    add rsp, 40
    ret
.usage:
    lea rsi, [s_touch_use]
    call puts
    add rsp, 40
    ret

cmd_cp:
    sub rsp, 40
    lea rax, [s_cp_nf]
    mov [copy_nf], rax
    lea rax, [s_cp_wfail]
    mov [copy_err], rax
    call split_args
    mov rax, [a1]
    test rax, rax
    jz .usage
    cmp word [rax], 0
    je .usage
    cmp qword [a2], 0
    je .usage

    call prepare_two
    test eax, eax
    jz .out
    call args_equal
    test eax, eax
    jnz .same
    call copy_file
    add rsp, 40
    ret
.out:
    add rsp, 40
    ret
.same:
    lea rsi, [s_cp_same]
    call puts
    add rsp, 40
    ret
.usage:
    lea rsi, [s_cp_use]
    call puts
    add rsp, 40
    ret

cmd_mv:
    sub rsp, 40
    lea rax, [s_mv_nf]
    mov [copy_nf], rax
    lea rax, [s_mv_wfail]
    mov [copy_err], rax
    call split_args
    mov rax, [a1]
    test rax, rax
    jz .usage
    cmp word [rax], 0
    je .usage
    cmp qword [a2], 0
    je .usage

    call prepare_two
    test eax, eax
    jz .out
    lea rsi, [pathbuf2]
    call need_write
    test eax, eax
    jz .out
    call args_equal
    test eax, eax
    jnz .same
    call copy_file
    test rax, rax
    jnz .out

    mov rcx, [a1]
    mov rdx, 3
    call fs_open
    test rax, rax
    jz .out
    mov rcx, rax
    call [rax + FILE_DELETE]
    test rax, rax
    jz .out
    lea rsi, [s_mv_rm]
    call puts
.out:
    add rsp, 40
    ret
.same:
    lea rsi, [s_mv_same]
    call puts
    add rsp, 40
    ret
.usage:
    lea rsi, [s_mv_use]
    call puts
    add rsp, 40
    ret

; copies [a1] to [a2]; 0 on success, 1 on failure
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

s_slash    db `/`,0
s_home_w   dw 0x5C, 'h', 'o', 'm', 'e', 0
s_denied   db `adachiOS: permission denied (that is outside /home, try sudo)\r\n`,0
s_cd_nf    db `cd: no such directory\r\n`,0
s_cd_nd    db `cd: not a directory\r\n`,0
guid_fileinfo db 0x92,0x6E,0x57,0x09, 0x3F,0x6D, 0xD2,0x11, 0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B
s_ls_err   db `ls: could not read the boot volume\r\n`,0
s_cat_use  db `usage: cat FILE\r\n`,0
s_cat_nf   db `cat: no such file\r\n`,0

s_rm_use    db `usage: rm FILE\r\n`,0
s_rm_nf     db `rm: no such file\r\n`,0
s_rm_busy   db `rm: could not remove it (directory not empty?)\r\n`,0
s_mk_use    db `usage: mkdir DIR\r\n`,0
s_mk_fail   db `mkdir: could not create the directory\r\n`,0
s_touch_use db `usage: touch FILE\r\n`,0
s_touch_f   db `touch: could not create the file\r\n`,0
s_cp_use    db `usage: cp SRC DST\r\n`,0
s_cp_nf     db `cp: no such file\r\n`,0
s_cp_same   db `cp: source and destination are the same\r\n`,0
s_cp_wfail  db `cp: could not write the destination\r\n`,0
s_mv_use    db `usage: mv SRC DST\r\n`,0
s_mv_same   db `mv: source and destination are the same\r\n`,0
s_mv_nf     db `mv: no such file\r\n`,0
s_mv_wfail  db `mv: could not move the file\r\n`,0
s_mv_rm     db `mv: copied, but could not remove the source\r\n`,0

s_f_head  db `\r\n  adachiOS fetch\r\n  --------------\r\n`,0
s_f_fw    db `  firmware: `,0
s_f_cpu   db `  cpu:      `,0
s_f_cores db `  cores:    `,0
s_f_threads db `  threads:  `,0
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
fs_attr      resq 1
fs_root      resq 1
fs_h         resq 1
fs_st        resq 1

pathbuf      resw 260
pathbuf2     resw 260
cd_path      resq 1
cd_h         resq 1
cd_st        resq 1
infosz       resq 1
infobuf      resb 512

a1           resq 1
a2           resq 1
rm_h         resq 1
cp_src       resq 1
cp_dst       resq 1
cp_sz        resq 1
cp_wsz       resq 1
copy_nf      resq 1
copy_err     resq 1
cpbuf        resb 4096

cpu_max      resd 1
cpu_cores    resq 1
cpu_threads  resq 1
cpu_vendor   resb 13
cpu_brand    resb 49
cpu_name     resb 64

cat_h        resq 1
cat_sz       resq 1
catbuf       resb 4096
pbuf         resw 512
pb_src       resq 1
pb_left      resq 1

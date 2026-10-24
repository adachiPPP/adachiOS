%include "uefi.inc"

bits 64
default rel

global cmd_fetch

extern conout
extern bs
extern sys_table
extern puts
extern print_dec
extern s_nl

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

section .data

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

cpu_max      resd 1
cpu_cores    resq 1
cpu_threads  resq 1
cpu_vendor   resb 13
cpu_brand    resb 49
cpu_name     resb 64

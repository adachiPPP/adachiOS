%include "bios/prog.inc"

cmd_main:
    call cpu_probe
    mov si, s_f_head
    call puts
    mov si, s_f_cpu
    call puts
    mov si, cpu_name
    call puts
    call newline
    mov si, s_f_cores
    call puts
    mov ax, [cpu_cores]
    call print_dec
    call newline
    mov si, s_f_threads
    call puts
    mov ax, [cpu_threads]
    call print_dec
    call newline
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

%include "cmd/bios/cmd_strings.inc"

%include "bios/lib.asm"

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
global argp
global cwd_w
global root_mode

extern fs_open
extern gop
extern fb_base
extern fb_stride
extern fb_white
extern fb_width
extern fb_height
extern font_scale
extern font_w
extern font_h
extern cursor_x
extern cursor_y
extern text_cols
extern text_rows
extern fb_clear
extern fb_putc
extern con_set_cursor
extern con_cursor_enable
extern con_cursor_disable
extern con_cursor_toggle
extern li_ptr
extern guid_loaded
extern puts
extern print_dec
extern puts_w
extern s_nl

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

    call setup_blink
    call setbigmode

    lea rcx, [guid_gop]
    xor rdx, rdx
    lea r8, [gop]
    mov rax, [bs]
    call [rax + BS_LOCATEPROTOCOL]
    test rax, rax
    jz .gop_ok
    mov rcx, [image_handle]
    lea rdx, [guid_gop]
    lea r8, [gop]
    mov rax, [bs]
    call [rax + BS_HANDLEPROTOCOL]
    test rax, rax
    jnz .no_gop
.gop_ok:
    mov rax, [gop]
    mov rax, [rax + 24]
    test rax, rax
    jz .no_gop
    mov rcx, [rax + 24]
    mov [fb_base], rcx
    mov rcx, [rax + 32]
    mov [fb_size], rcx
    mov rax, [rax + 8]
    test rax, rax
    jz .no_gop
    mov ecx, [rax + 4]
    mov [fb_width], rcx
    mov ecx, [rax + 8]
    mov [fb_height], rcx
    mov ecx, [rax + 12]
    cmp ecx, 3
    jae .no_gop
    mov qword [fb_white], 0x00FFFFFF
    cmp ecx, 2
    jne .color_ok
    mov ecx, [rax + 16]
    mov r8d, [rax + 20]
    or ecx, r8d
    mov r8d, [rax + 24]
    or ecx, r8d
    mov [fb_white], rcx
.color_ok:
    mov ecx, [rax + 32]
    mov [fb_stride], rcx

    cmp qword [fb_base], 0
    je .no_gop
    cmp qword [fb_width], 0
    je .no_gop
    cmp qword [fb_height], 0
    je .no_gop
    cmp qword [fb_stride], 0
    jne .stride_ok
    mov rax, [fb_size]
    xor edx, edx
    mov rcx, [fb_height]
    shl rcx, 2
    div rcx
    mov [fb_stride], rax
.stride_ok:
    mov rax, [fb_stride]
    cmp rax, [fb_width]
    jae .stride_final
    mov rax, [fb_width]
    mov [fb_stride], rax
.stride_final:
    test rax, rax
    jz .no_gop

    mov qword [cursor_x], 0
    mov qword [cursor_y], 0

    mov rax, [fb_height]
    mov rcx, 720
    xor edx, edx
    div rcx
    test rax, rax
    jnz .scale_nonzero
    mov eax, 1
.scale_nonzero:
    cmp rax, 4
    jbe .scale_cap
    mov eax, 4
.scale_cap:
    mov rcx, rax
.scale_ready:
    mov r8, 8
    imul r8, rcx
    mov rax, [fb_width]
    xor edx, edx
    div r8
    cmp rax, 80
    jae .scale_ok
    cmp rcx, 1
    jbe .scale_ok
    dec rcx
    jmp .scale_ready
.scale_ok:
    mov [font_scale], rcx
    mov rax, 16
    imul rax, rcx
    mov [font_h], rax
    mov rax, 8
    imul rax, rcx
    mov [font_w], rax
    mov rax, [fb_width]
    xor edx, edx
    mov rcx, [font_w]
    div rcx
    mov [text_cols], rax
    mov rax, [fb_height]
    xor edx, edx
    mov rcx, [font_h]
    div rcx
    mov [text_rows], rax
    test rax, rax
    jz .no_gop
    mov rax, [text_cols]
    test rax, rax
    jz .no_gop
    call fb_clear
    call con_cursor_enable
    mov rcx, [conout]
    xor edx, edx
    mov rax, [conout]
    call [rax + TXT_ENABLECURSOR]
    jmp .text_ready
.no_gop:
    mov qword [gop], 0
    mov rcx, [conout]
    mov rax, [conout]
    call [rax + TXT_CLEARSCREEN]
    mov rcx, [conout]
    mov edx, 1
    mov rax, [conout]
    call [rax + TXT_ENABLECURSOR]
.text_ready:
    mov word [linebuf], 'a'
    mov word [linebuf + 2], 'd'
    mov word [linebuf + 4], 'i'
    mov word [linebuf + 6], 'n'
    mov word [linebuf + 8], 'i'
    mov word [linebuf + 10], 't'
    mov word [linebuf + 12], 0
    call run_external

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

setup_blink:
    sub rsp, 40
    mov rax, [bs]
    mov ecx, 0x80000000
    mov edx, 4
    xor r8d, r8d
    xor r9d, r9d
    lea r10, [timer_evt]
    mov [rsp + 32], r10
    call [rax + BS_CREATEEVENT]
    test rax, rax
    jnz .done
    mov rcx, [timer_evt]
    mov edx, 1
    mov r8, 5000000
    mov rax, [bs]
    call [rax + BS_SETTIMER]
    test rax, rax
    jz .done
    mov qword [timer_evt], 0
.done:
    add rsp, 40
    ret

readline:
    sub rsp, 40
    mov qword [linelen], 0
    mov qword [hist_nav], 0
.wait:
    mov rax, [conin]
    mov rcx, [rax + IN_WAITFORKEY]
    mov [evts], rcx
    mov rax, [timer_evt]
    test rax, rax
    jz .wait_one
    mov [evts + 8], rax
    mov ecx, 2
    jmp .wait_go
.wait_one:
    mov ecx, 1
.wait_go:
    mov rax, [bs]
    lea rdx, [evts]
    lea r8, [evidx]
    call [rax + BS_WAITFOREVENT]
    test rax, rax
    jnz .wait
    cmp qword [evidx], 1
    je .blink

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

    mov cl, al
    call fb_putc
    jmp .wait

.blink:
    call con_cursor_toggle
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
    lea rsi, [linebuf]
    call puts_w
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

    lea rsi, [s_rodo_name]
    call cmd_is
    test eax, eax
    jz .not_rodo

    cmp byte [root_mode], 0
    jne .rodo_root
    mov rsi, [argp]
    cmp word [rsi], 0
    je .rodo_use
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
.rodo_root:
    lea rsi, [s_rodo_root]
    call puts
    jmp .out
.rodo_use:
    lea rsi, [s_rodo_use]
    call puts
    jmp .out
.not_rodo:
    lea rsi, [s_exec_name]
    call cmd_is
    test eax, eax
    jz .dispatch

    mov rsi, [argp]
    lea rdi, [extpath]
.exec_copy:
    mov ax, [rsi]
    cmp ax, 32
    je .exec_copy_done
    cmp ax, 9
    je .exec_copy_done
    test ax, ax
    jz .exec_copy_done
    cmp ax, '/'
    jne .exec_copy_noslash
    mov ax, 92
.exec_copy_noslash:
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .exec_copy
.exec_copy_done:
    mov word [rdi], 0
    cmp word [extpath], 0
    jz .exec_usage
.exec_skipws:
    cmp word [rsi], 32
    je .exec_ws
    cmp word [rsi], 9
    je .exec_ws
    jmp .exec_wsdone
.exec_ws:
    add rsi, 2
    jmp .exec_skipws
.exec_wsdone:
    mov [argp], rsi

    call run_file
    test eax, eax
    jnz .out
    lea rsi, [s_execfail]
    call puts
    jmp .out
.exec_usage:
    lea rsi, [s_execusage]
    call puts
    jmp .out

.dispatch:
    call run_external
    test eax, eax
    jnz .out
    lea rsi, [s_unknown]
    call puts
.out:
    mov byte [root_mode], 0
    add rsp, 40
    ret

run_file:
    sub rsp, 40

    lea rcx, [extpath]
    mov rdx, 1
    call fs_open
    test rax, rax
    jnz .open_ok

    lea rdi, [extpath]
.find_end:
    mov ax, [rdi]
    test ax, ax
    jz .append_bin
    add rdi, 2
    jmp .find_end
.append_bin:
    mov word [rdi], '.'
    add rdi, 2
    mov word [rdi], 'B'
    add rdi, 2
    mov word [rdi], 'I'
    add rdi, 2
    mov word [rdi], 'N'
    add rdi, 2
    mov word [rdi], 0

    lea rcx, [extpath]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .not_found

.open_ok:
    mov [ext_h], rax

    mov rax, [bs]
    mov ecx, 2
    mov edx, 0x100000
    lea r8, [ext_buf]
    call [rax + BS_ALLOCATEPOOL]
    test rax, rax
    jnz .free_close

    mov rdi, [ext_buf]
    xor eax, eax
    mov ecx, 131072
    rep stosq

    mov qword [ext_total], 0
.rd:
    mov qword [ext_sz], 65536
    mov rcx, [ext_h]
    lea rdx, [ext_sz]
    mov r8, [ext_buf]
    add r8, [ext_total]
    mov rax, [ext_h]
    call [rax + FILE_READ]
    test rax, rax
    jnz .free_close
    mov rax, [ext_sz]
    test rax, rax
    jz .loaded
    add [ext_total], rax
    cmp qword [ext_total], 0x100000
    jae .free_close
    jmp .rd

.loaded:
    mov rcx, [ext_h]
    mov rax, [ext_h]
    call [rax + FILE_CLOSE]
    mov qword [ext_h], 0

    mov rax, [ext_buf]
    cmp word [rax], 0x5A4D
    je .pe
    cmp dword [rax + 2], 0x31424441
    jne .bad_exec

    call con_cursor_disable
    lea rax, [fctx]
    mov rcx, [sys_table]
    mov [rax + FCTX_SYSTAB], rcx
    mov rcx, [image_handle]
    mov [rax + FCTX_IMAGE], rcx
    mov rcx, [li_ptr]
    xor edx, edx
    test rcx, rcx
    jz .nodev
    mov rdx, [rcx + LI_DEVICEHANDLE]
.nodev:
    mov [rax + FCTX_DEVICE], rdx
    lea rcx, [cwd_w]
    mov [rax + FCTX_CWD], rcx
    mov rcx, [argp]
    mov [rax + FCTX_ARGS], rcx
    mov cl, [root_mode]
    mov [rax + FCTX_ROOT], cl

    lea rax, [fb_putc]
    mov [fctx + FCTX_PUTC], rax
    lea rax, [fb_clear]
    mov [fctx + FCTX_CLEAR], rax
    lea rax, [con_set_cursor]
    mov [fctx + FCTX_SETCURSOR], rax
    mov rax, [text_cols]
    mov [fctx + FCTX_COLS], rax
    mov rax, [text_rows]
    mov [fctx + FCTX_ROWS], rax

    call con_cursor_disable
    lea rcx, [fctx]
    mov rax, [ext_buf]
    call rax
    call con_cursor_enable

    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    mov eax, 1
    add rsp, 40
    ret

.pe:
    call con_cursor_disable
    call load_pe
    push rax
    call con_cursor_enable
    pop rax
    add rsp, 40
    ret

.bad_exec:
    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    lea rsi, [s_badexec]
    call puts
    mov eax, 1
    add rsp, 40
    ret

.free_close:
    mov rcx, [ext_h]
    mov rax, [ext_h]
    call [rax + FILE_CLOSE]
    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    xor eax, eax
    add rsp, 40
    ret

.not_found:
    lea rsi, [s_execfail]
    call puts
    mov eax, 1
    add rsp, 40
    ret

run_external:
    sub rsp, 40

    lea rsi, [s_bin_w]
    lea rdi, [extpath]
.cpbin:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .cpbin
    sub rdi, 2

    lea rsi, [linebuf]
.cpname:
    mov ax, [rsi]
    test ax, ax
    jz .ext
    cmp ax, 32
    je .ext
    cmp ax, 'A'
    jb .put
    cmp ax, 'Z'
    ja .put
    add ax, 32
.put:
    mov [rdi], ax
    add rdi, 2
    add rsi, 2
    jmp .cpname
.ext:
    lea rsi, [s_bin_ext]
.cpext:
    mov ax, [rsi]
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    test ax, ax
    jnz .cpext

    lea rcx, [extpath]
    mov rdx, 1
    call fs_open
    test rax, rax
    jz .notfound
    mov [ext_h], rax

    mov rax, [bs]
    mov ecx, 2
    mov edx, 0x100000
    lea r8, [ext_buf]
    call [rax + BS_ALLOCATEPOOL]
    test rax, rax
    jnz .close_notfound

    mov rdi, [ext_buf]
    xor eax, eax
    mov ecx, 131072
    rep stosq

    mov qword [ext_total], 0
.rd:
    mov qword [ext_sz], 65536
    mov rcx, [ext_h]
    lea rdx, [ext_sz]
    mov r8, [ext_buf]
    add r8, [ext_total]
    mov rax, [ext_h]
    call [rax + FILE_READ]
    test rax, rax
    jnz .free_close
    mov rax, [ext_sz]
    test rax, rax
    jz .loaded
    add [ext_total], rax
    cmp qword [ext_total], 0x100000
    jae .free_close
    jmp .rd

.loaded:
    mov rcx, [ext_h]
    mov rax, [ext_h]
    call [rax + FILE_CLOSE]
    mov qword [ext_h], 0

    mov rax, [ext_buf]
    cmp word [rax], 0x5A4D
    je .pe
    cmp dword [rax + 2], 0x31424441
    jne .bad_exec

    lea rax, [fctx]
    mov rcx, [sys_table]
    mov [rax + FCTX_SYSTAB], rcx
    mov rcx, [image_handle]
    mov [rax + FCTX_IMAGE], rcx
    mov rcx, [li_ptr]
    xor edx, edx
    test rcx, rcx
    jz .nodev
    mov rdx, [rcx + LI_DEVICEHANDLE]
.nodev:
    mov [rax + FCTX_DEVICE], rdx
    lea rcx, [cwd_w]
    mov [rax + FCTX_CWD], rcx
    mov rcx, [argp]
    mov [rax + FCTX_ARGS], rcx
    mov cl, [root_mode]
    mov [rax + FCTX_ROOT], cl

    lea rax, [fb_putc]
    mov [fctx + FCTX_PUTC], rax
    lea rax, [fb_clear]
    mov [fctx + FCTX_CLEAR], rax
    lea rax, [con_set_cursor]
    mov [fctx + FCTX_SETCURSOR], rax
    mov rax, [text_cols]
    mov [fctx + FCTX_COLS], rax
    mov rax, [text_rows]
    mov [fctx + FCTX_ROWS], rax

    call con_cursor_disable
    lea rcx, [fctx]
    mov rax, [ext_buf]
    call rax
    call con_cursor_enable

    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    mov eax, 1
    add rsp, 40
    ret

.pe:
    call con_cursor_disable
    call load_pe
    push rax
    call con_cursor_enable
    pop rax
    add rsp, 40
    ret

.bad_exec:
    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    lea rsi, [s_badexec]
    call puts
    mov eax, 1
    add rsp, 40
    ret

.free_close:
    mov rcx, [ext_h]
    mov rax, [ext_h]
    call [rax + FILE_CLOSE]
    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    xor eax, eax
    add rsp, 40
    ret

.close_notfound:
    mov rcx, [ext_h]
    mov rax, [ext_h]
    call [rax + FILE_CLOSE]
.notfound:
    xor eax, eax
    add rsp, 40
    ret

load_pe:
    sub rsp, 56

    lea rdi, [ext_opts]
    lea rsi, [cwd_w]
.cp_cwd:
    mov ax, [rsi]
    test ax, ax
    jz .cwd_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .cp_cwd
.cwd_done:
    mov word [rdi], 10
    add rdi, 2
    mov al, [root_mode]
    add al, '0'
    mov [rdi], al
    add rdi, 2
    mov word [rdi], 10
    add rdi, 2
    mov rsi, [argp]
    test rsi, rsi
    jz .args_done
.cp_args:
    mov ax, [rsi]
    test ax, ax
    jz .args_done
    mov [rdi], ax
    add rsi, 2
    add rdi, 2
    jmp .cp_args
.args_done:
    mov word [rdi], 0
    add rdi, 2
    mov word [rdi], 'C'
    mov word [rdi + 2], 'O'
    mov word [rdi + 4], 'N'
    mov word [rdi + 6], 'S'
    add rdi, 8
    lea rax, [fb_putc]
    mov [rdi], rax
    add rdi, 8
    lea rax, [fb_clear]
    mov [rdi], rax
    add rdi, 8
    lea rax, [con_set_cursor]
    mov [rdi], rax
    add rdi, 8
    mov word [rdi], 0
    add rdi, 2
    lea rax, [ext_opts]
    sub rdi, rax
    mov [ext_opts_len], rdi

    xor ecx, ecx
    mov rdx, [image_handle]
    xor r8d, r8d
    mov r9, [ext_buf]
    mov rax, [ext_total]
    mov [rsp + 32], rax
    lea rax, [new_h]
    mov [rsp + 40], rax
    mov rax, [bs]
    call [rax + BS_LOADIMAGE]
    test rax, rax
    jz .li_ok
    mov [ext_sz], rax
    lea rsi, [s_ld]
    call puts
    mov rax, [ext_sz]
    call print_dec
    lea rsi, [s_nl]
    call puts
    jmp .fail
.li_ok:

    mov rcx, [new_h]
    lea rdx, [guid_loaded]
    lea r8, [li_ptr2]
    mov rax, [bs]
    call [rax + BS_HANDLEPROTOCOL]
    test rax, rax
    jz .hp_ok
    mov [ext_sz], rax
    lea rsi, [s_hp]
    call puts
    mov rax, [ext_sz]
    call print_dec
    lea rsi, [s_nl]
    call puts
    jmp .fail_unload
.hp_ok:

    mov rax, [li_ptr2]
    mov ecx, [ext_opts_len]
    mov [rax + 48], ecx
    lea rcx, [ext_opts]
    mov [rax + 56], rcx

    mov rcx, [new_h]
    xor edx, edx
    xor r8d, r8d
    mov rax, [bs]
    call [rax + BS_STARTIMAGE]
    test rax, rax
    jz .si_ok
    jmp .si_fail
.si_ok:

    mov rcx, [new_h]
    mov rax, [bs]
    call [rax + BS_UNLOADIMAGE]
    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    mov eax, 1
    add rsp, 56
    ret

.si_fail:
    mov rcx, [new_h]
    mov rax, [bs]
    call [rax + BS_UNLOADIMAGE]
    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    mov eax, 1
    add rsp, 56
    ret

.fail_unload:
    mov rcx, [new_h]
    mov rax, [bs]
    call [rax + BS_UNLOADIMAGE]
.fail:
    mov rcx, [ext_buf]
    mov rax, [bs]
    call [rax + BS_FREEPOOL]
    lea rsi, [s_badpe]
    call puts
    mov eax, 1
    add rsp, 56
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

section .data

s_banner  db `\r\n  adachiOS 0.6 - a tiny os :3\r\n  type 'help' if you are lost\r\n\r\n`,0
s_prompt  db `:3 adachiOS:`,0
s_prompt2 db `> `,0
s_unknown db `adachiOS: command not found (rude)\r\n`,0
s_rodo_name db 'rodo',0
s_rodo_use  db `usage: rodo CMD   (you start with only /home, rodo is root)\r\n`,0
s_rodo_root db `rodo: you are already root for this command\r\n`,0
s_exec_name db 'exec',0
s_execusage db `usage: exec PATH [args]\r\n`,0
s_execfail db `exec: file not found\r\n`,0
s_bs      db 8,' ',8,0
s_bin_w   dw 0x5C, 'b', 'i', 'n', 0x5C, 0
s_bin_ext dw '.', 'b', 'i', 'n', 0
s_badexec db `adachiOS: /bin program is not a valid flat binary\r\n`,0
s_badpe   db `adachiOS: /bin program is not a valid PE image\r\n`,0
s_ld      db `loadimage status `,0
s_hp      db `handleprotocol status `,0

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
evts         resq 2
evidx        resq 1
timer_evt    resq 1
key          resd 1
echobuf      resw 2
linebuf      resw 256
livebuf      resw 256
argp         resq 1
extpath      resw 300
ext_h        resq 1
ext_buf      resq 1
ext_sz       resq 1
ext_total    resq 1
ext_opts     resw 1024
ext_opts_len resq 1
new_h        resq 1
li_ptr2      resq 1
fctx         resb FCTX_SIZE

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
fb_size      resq 1

section .data
guid_gop:
    dd 0x9042a9de
    dw 0x23dc
    dw 0x4a38
    db 0x96,0xfb,0x7a,0xde,0xd0,0x80,0x51,0x6a

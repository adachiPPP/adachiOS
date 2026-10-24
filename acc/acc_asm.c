#include "acc_os.h"
#include "acc_rt.h"

#define MAX_LABELS 2048
#define MAX_LABEL_NAME 128
#define OUT_MAX 262144

static char label_names[MAX_LABELS][MAX_LABEL_NAME];
static int label_offsets[MAX_LABELS];
static int label_is_data[MAX_LABELS];
static int label_count;

static unsigned char rtbuf[65536];
static int text_size;
static int data_size;
static char asm_error[256];

static void set_error(const char *line) {
    int i = 0;
    while (line[i] && i < 255) {
        asm_error[i] = line[i];
        i++;
    }
    asm_error[i] = 0;
}

static const char *skip_ws(const char *p) {
    while (*p == ' ' || *p == '\t') p++;
    return p;
}

static int starts(const char *p, const char *s) {
    while (*s) {
        if (*p++ != *s++) return 0;
    }
    return 1;
}

static int contains(const char *p, const char *s) {
    while (*p) {
        if (starts(p, s)) return 1;
        p++;
    }
    return 0;
}

static int label_index(const char *name) {
    for (int i = 0; i < label_count; i++) {
        if (!strcmp(label_names[i], name)) return i;
    }
    return -1;
}

static int add_label(const char *name, int off, int is_data) {
    if (label_count >= MAX_LABELS) return -1;
    int n = 0;
    while (name[n] && n < MAX_LABEL_NAME - 1) {
        label_names[label_count][n] = name[n];
        n++;
    }
    label_names[label_count][n] = 0;
    label_offsets[label_count] = off;
    label_is_data[label_count] = is_data;
    label_count++;
    return 0;
}

static int count_values(const char *p) {
    int n = 0;
    int any = 0;
    while (*p) {
        if (*p == ',') n++;
        else if (*p != ' ' && *p != '\t') any = 1;
        p++;
    }
    if (!any) return 0;
    return n + 1;
}

static int data_size_line(const char *line) {
    const char *p = skip_ws(line);
    if (starts(p, "times ")) {
        p += 6;
        long long n = strtol(p, (char **)0, 0);
        return (int)n;
    }
    if (starts(p, "db ")) return count_values(p + 3);
    if (starts(p, "dw ")) return count_values(p + 3) * 2;
    if (starts(p, "dq ")) return count_values(p + 3) * 8;
    return 0;
}

static int instr_size(const char *line) {
    const char *p = skip_ws(line);
    if (starts(p, "mov rax, [")) {
        if (contains(p, "[rel ")) return 7;
        if (contains(p, "[rbp")) return 7;
        return 3;
    }
    if (starts(p, "mov [rel ")) return 7;
    if (starts(p, "mov [rbp")) return 7;
    if (starts(p, "mov [rbx], rax")) return 3;
    if (starts(p, "mov [rbx], al")) return 2;
    if (starts(p, "mov rbp, rsp")) return 3;
    if (starts(p, "mov rsp, rbp")) return 3;
    if (starts(p, "mov rbx, rax")) return 3;
    if (starts(p, "mov rax, rbx")) return 3;
    if (starts(p, "mov rax, rdx")) return 3;
    if (starts(p, "mov rax, ")) return 10;
    if (starts(p, "movzx eax, byte [rax]")) return 3;
    if (starts(p, "movzx rax, al")) return 4;
    if (starts(p, "lea rax, [rel ")) return 7;
    if (starts(p, "lea rax, [rbp")) return 7;
    if (starts(p, "push ")) return 1;
    if (starts(p, "pop ")) return 1;
    if (starts(p, "add rax, rbx")) return 3;
    if (starts(p, "sub rax, rbx")) return 3;
    if (starts(p, "add rsp, ")) return 7;
    if (starts(p, "sub rsp, ")) return 7;
    if (starts(p, "imul rax, rbx")) return 4;
    if (starts(p, "imul rax, rax, ")) return 7;
    if (starts(p, "idiv rbx")) return 3;
    if (starts(p, "cqo")) return 2;
    if (starts(p, "and rax, rbx")) return 3;
    if (starts(p, "or rax, rbx")) return 3;
    if (starts(p, "xor rax, rax")) return 3;
    if (starts(p, "xor rax, rbx")) return 3;
    if (starts(p, "cmp rax, rbx")) return 3;
    if (starts(p, "test rax, rax")) return 3;
    if (starts(p, "set")) return 3;
    if (starts(p, "jmp ")) return 5;
    if (starts(p, "jz ")) return 6;
    if (starts(p, "jnz ")) return 6;
    if (starts(p, "call ")) return 5;
    if (starts(p, "neg rax")) return 3;
    if (starts(p, "not rax")) return 3;
    if (starts(p, "ret")) return 1;
    return 0;
}

static int sym_value(const char *name) {
    if (!strcmp(name, "c_putchar")) return SYM_c_putchar;
    if (!strcmp(name, "c_puts")) return SYM_c_puts;
    if (!strcmp(name, "c_print_int")) return SYM_c_print_int;
    if (!strcmp(name, "c_printf")) return SYM_c_printf;
    if (!strcmp(name, "c_strlen")) return SYM_c_strlen;
    if (!strcmp(name, "c_strcmp")) return SYM_c_strcmp;
    if (!strcmp(name, "c_strcpy")) return SYM_c_strcpy;
    if (!strcmp(name, "c_memcpy")) return SYM_c_memcpy;
    if (!strcmp(name, "c_memset")) return SYM_c_memset;
    if (!strcmp(name, "c_atoi")) return SYM_c_atoi;
    if (!strcmp(name, "c_malloc")) return SYM_c_malloc;
    if (!strcmp(name, "c_free")) return SYM_c_free;
    if (!strcmp(name, "c_exit")) return SYM_c_exit;
    return -1;
}

static int resolve_label(const char *name) {
    int s = sym_value(name);
    if (s >= 0) return s;
    int i = label_index(name);
    if (i < 0) return -1;
    if (label_is_data[i]) return RT_MEM_SIZE + text_size + label_offsets[i];
    return RT_MEM_SIZE + label_offsets[i];
}

static void put32(unsigned char *p, int v) {
    p[0] = (unsigned char)v;
    p[1] = (unsigned char)(v >> 8);
    p[2] = (unsigned char)(v >> 16);
    p[3] = (unsigned char)(v >> 24);
}

static void put64(unsigned char *p, unsigned long long v) {
    for (int i = 0; i < 8; i++) p[i] = (unsigned char)(v >> (i * 8));
}

static int parse_label_name(const char *line, char *name) {
    const char *p = skip_ws(line);
    int n = 0;
    while (*p && *p != ':' && *p != ' ' && *p != '\t' && n < MAX_LABEL_NAME - 1) {
        name[n++] = *p++;
    }
    name[n] = 0;
    if (*p != ':') return 0;
    return n > 0;
}

static int line_is_label(const char *line) {
    char name[MAX_LABEL_NAME];
    if (!parse_label_name(line, name)) return 0;
    const char *p = skip_ws(line);
    while (*p && *p != ':') p++;
    p++;
    p = skip_ws(p);
    return *p == 0 || *p == ';';
}

static int pass1(const char *text) {
    const char *p = text;
    int section_data = 0;
    text_size = 0;
    data_size = 0;
    label_count = 0;
    while (*p) {
        const char *e = p;
        while (*e && *e != '\n') e++;
        char line[512];
        int n = (int)(e - p);
        if (n > 511) n = 511;
        for (int i = 0; i < n; i++) line[i] = p[i];
        line[n] = 0;
        p = *e ? e + 1 : e;

        const char *q = skip_ws(line);
        if (!*q || *q == ';') continue;
        if (starts(q, "bits ") || starts(q, "default ") || starts(q, "global ") || starts(q, "extern ")) continue;
        if (starts(q, "section ")) {
            section_data = contains(q, ".data");
            continue;
        }
        if (line_is_label(q)) {
            char name[MAX_LABEL_NAME];
            parse_label_name(q, name);
            if (add_label(name, section_data ? data_size : text_size, section_data) < 0) return -1;
            continue;
        }
        if (section_data || starts(q, "db ") || starts(q, "dw ") || starts(q, "dq ") || starts(q, "times ")) {
            data_size += data_size_line(q);
        } else {
            int sz = instr_size(q);
            if (sz <= 0) {
                set_error(q);
                return -1;
            }
            text_size += sz;
        }
    }
    return 0;
}

static void emit_data_line(unsigned char *out, const char *line) {
    const char *p = skip_ws(line);
    int width = 1;
    int times = 1;
    if (starts(p, "times ")) {
        p += 6;
        times = (int)strtol(p, (char **)0, 0);
        while (*p && *p != ' ') p++;
        p = skip_ws(p);
    }
    if (starts(p, "db ")) {
        width = 1;
        p += 3;
    } else if (starts(p, "dw ")) {
        width = 2;
        p += 3;
    } else if (starts(p, "dq ")) {
        width = 8;
        p += 3;
    }
    while (*p) {
        p = skip_ws(p);
        if (!*p) break;
        long long v = strtol(p, (char **)&p, 0);
        for (int t = 0; t < times; t++) {
            for (int b = 0; b < width; b++) {
                *out++ = (unsigned char)((unsigned long long)v >> (b * 8));
            }
        }
        p = skip_ws(p);
        if (*p == ',') p++;
        else break;
    }
}

static int pass2(const char *text, unsigned char *out) {
    const char *p = text;
    int section_data = 0;
    int toff = 0;
    int doff = 0;
    unsigned char *text_base = out + RT_MEM_SIZE;
    unsigned char *data_base = out + RT_MEM_SIZE + text_size;
    while (*p) {
        const char *e = p;
        while (*e && *e != '\n') e++;
        char line[512];
        int n = (int)(e - p);
        if (n > 511) n = 511;
        for (int i = 0; i < n; i++) line[i] = p[i];
        line[n] = 0;
        p = *e ? e + 1 : e;

        const char *q = skip_ws(line);
        if (!*q || *q == ';') continue;
        if (starts(q, "bits ") || starts(q, "default ") || starts(q, "global ") || starts(q, "extern ")) continue;
        if (starts(q, "section ")) {
            section_data = contains(q, ".data");
            continue;
        }
        if (line_is_label(q)) continue;
        if (section_data || starts(q, "db ") || starts(q, "dw ") || starts(q, "dq ") || starts(q, "times ")) {
            emit_data_line(data_base + doff, q);
            doff += data_size_line(q);
            continue;
        }

        unsigned char *o = text_base + toff;
        int here = RT_MEM_SIZE + toff;
        if (starts(q, "mov rax, [")) {
            if (contains(q, "[rel ")) {
                const char *l = q + 14;
                char name[MAX_LABEL_NAME];
                int k = 0;
                while (l[k] && l[k] != ']' && k < MAX_LABEL_NAME - 1) {
                    name[k] = l[k];
                    k++;
                }
                name[k] = 0;
                int t = resolve_label(name);
                if (t < 0) {
                    set_error(q);
                    return -1;
                }
                o[0] = 0x48; o[1] = 0x8B; o[2] = 0x05;
                put32(o + 3, t - (here + 7));
                toff += 7;
            } else if (contains(q, "[rbp")) {
                const char *l = q + 13;
                long long d = strtol(l, (char **)0, 0);
                o[0] = 0x48; o[1] = 0x8B; o[2] = 0x85;
                put32(o + 3, (int)d);
                toff += 7;
            } else {
                o[0] = 0x48; o[1] = 0x8B; o[2] = 0x00;
                toff += 3;
            }
        } else if (starts(q, "mov [rel ")) {
            const char *l = q + 9;
            char name[MAX_LABEL_NAME];
            int k = 0;
            while (l[k] && l[k] != ']' && k < MAX_LABEL_NAME - 1) {
                name[k] = l[k];
                k++;
            }
            name[k] = 0;
            int t = resolve_label(name);
            if (t < 0) {
                set_error(q);
                return -1;
            }
            o[0] = 0x48; o[1] = 0x89; o[2] = 0x05;
            put32(o + 3, t - (here + 7));
            toff += 7;
        } else if (starts(q, "mov [rbp")) {
            const char *l = q + 8;
            long long d = strtol(l, (char **)0, 0);
            o[0] = 0x48; o[1] = 0x89; o[2] = 0x85;
            put32(o + 3, (int)d);
            toff += 7;
        } else if (starts(q, "mov [rbx], rax")) {
            o[0] = 0x48; o[1] = 0x89; o[2] = 0x03;
            toff += 3;
        } else if (starts(q, "mov [rbx], al")) {
            o[0] = 0x88; o[1] = 0x03;
            toff += 2;
        } else if (starts(q, "mov rbp, rsp")) {
            o[0] = 0x48; o[1] = 0x89; o[2] = 0xE5;
            toff += 3;
        } else if (starts(q, "mov rsp, rbp")) {
            o[0] = 0x48; o[1] = 0x89; o[2] = 0xEC;
            toff += 3;
        } else if (starts(q, "mov rbx, rax")) {
            o[0] = 0x48; o[1] = 0x89; o[2] = 0xC3;
            toff += 3;
        } else if (starts(q, "mov rax, rbx")) {
            o[0] = 0x48; o[1] = 0x89; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "mov rax, rdx")) {
            o[0] = 0x48; o[1] = 0x89; o[2] = 0xD0;
            toff += 3;
        } else if (starts(q, "mov rax, ")) {
            const char *l = q + 9;
            long long v = strtol(l, (char **)0, 0);
            o[0] = 0x48; o[1] = 0xB8;
            put64(o + 2, (unsigned long long)v);
            toff += 10;
        } else if (starts(q, "movzx eax, byte [rax]")) {
            o[0] = 0x0F; o[1] = 0xB6; o[2] = 0x00;
            toff += 3;
        } else if (starts(q, "movzx rax, al")) {
            o[0] = 0x48; o[1] = 0x0F; o[2] = 0xB6; o[3] = 0xC0;
            toff += 4;
        } else if (starts(q, "lea rax, [rel ")) {
            const char *l = q + 14;
            char name[MAX_LABEL_NAME];
            int k = 0;
            while (l[k] && l[k] != ']' && k < MAX_LABEL_NAME - 1) {
                name[k] = l[k];
                k++;
            }
            name[k] = 0;
            int t = resolve_label(name);
            if (t < 0) {
                set_error(q);
                return -1;
            }
            o[0] = 0x48; o[1] = 0x8D; o[2] = 0x05;
            put32(o + 3, t - (here + 7));
            toff += 7;
        } else if (starts(q, "lea rax, [rbp")) {
            const char *l = q + 13;
            long long d = strtol(l, (char **)0, 0);
            o[0] = 0x48; o[1] = 0x8D; o[2] = 0x85;
            put32(o + 3, (int)d);
            toff += 7;
        } else if (starts(q, "push rax")) {
            o[0] = 0x50;
            toff += 1;
        } else if (starts(q, "push rbp")) {
            o[0] = 0x55;
            toff += 1;
        } else if (starts(q, "pop rax")) {
            o[0] = 0x58;
            toff += 1;
        } else if (starts(q, "pop rbx")) {
            o[0] = 0x5B;
            toff += 1;
        } else if (starts(q, "pop rbp")) {
            o[0] = 0x5D;
            toff += 1;
        } else if (starts(q, "add rax, rbx")) {
            o[0] = 0x48; o[1] = 0x01; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "sub rax, rbx")) {
            o[0] = 0x48; o[1] = 0x29; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "add rsp, ")) {
            long long v = strtol(q + 9, (char **)0, 0);
            o[0] = 0x48; o[1] = 0x81; o[2] = 0xC4;
            put32(o + 3, (int)v);
            toff += 7;
        } else if (starts(q, "sub rsp, ")) {
            long long v = strtol(q + 9, (char **)0, 0);
            o[0] = 0x48; o[1] = 0x81; o[2] = 0xEC;
            put32(o + 3, (int)v);
            toff += 7;
        } else if (starts(q, "imul rax, rbx")) {
            o[0] = 0x48; o[1] = 0x0F; o[2] = 0xAF; o[3] = 0xC3;
            toff += 4;
        } else if (starts(q, "imul rax, rax, ")) {
            long long v = strtol(q + 15, (char **)0, 0);
            o[0] = 0x48; o[1] = 0x69; o[2] = 0xC0;
            put32(o + 3, (int)v);
            toff += 7;
        } else if (starts(q, "idiv rbx")) {
            o[0] = 0x48; o[1] = 0xF7; o[2] = 0xFB;
            toff += 3;
        } else if (starts(q, "cqo")) {
            o[0] = 0x48; o[1] = 0x99;
            toff += 2;
        } else if (starts(q, "and rax, rbx")) {
            o[0] = 0x48; o[1] = 0x21; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "or rax, rbx")) {
            o[0] = 0x48; o[1] = 0x09; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "xor rax, rax")) {
            o[0] = 0x48; o[1] = 0x31; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "xor rax, rbx")) {
            o[0] = 0x48; o[1] = 0x31; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "cmp rax, rbx")) {
            o[0] = 0x48; o[1] = 0x39; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "test rax, rax")) {
            o[0] = 0x48; o[1] = 0x85; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "sete al")) {
            o[0] = 0x0F; o[1] = 0x94; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "setne al")) {
            o[0] = 0x0F; o[1] = 0x95; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "setl al")) {
            o[0] = 0x0F; o[1] = 0x9C; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "setle al")) {
            o[0] = 0x0F; o[1] = 0x9E; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "setg al")) {
            o[0] = 0x0F; o[1] = 0x9F; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "setge al")) {
            o[0] = 0x0F; o[1] = 0x9D; o[2] = 0xC0;
            toff += 3;
        } else if (starts(q, "jmp ")) {
            const char *l = skip_ws(q + 4);
            char name[MAX_LABEL_NAME];
            int k = 0;
            while (l[k] && l[k] != ' ' && l[k] != '\t' && k < MAX_LABEL_NAME - 1) {
                name[k] = l[k];
                k++;
            }
            name[k] = 0;
            int t = resolve_label(name);
            if (t < 0) {
                set_error(q);
                return -1;
            }
            o[0] = 0xE9;
            put32(o + 1, t - (here + 5));
            toff += 5;
        } else if (starts(q, "jz ")) {
            const char *l = skip_ws(q + 3);
            char name[MAX_LABEL_NAME];
            int k = 0;
            while (l[k] && l[k] != ' ' && l[k] != '\t' && k < MAX_LABEL_NAME - 1) {
                name[k] = l[k];
                k++;
            }
            name[k] = 0;
            int t = resolve_label(name);
            if (t < 0) {
                set_error(q);
                return -1;
            }
            o[0] = 0x0F; o[1] = 0x84;
            put32(o + 2, t - (here + 6));
            toff += 6;
        } else if (starts(q, "jnz ")) {
            const char *l = skip_ws(q + 4);
            char name[MAX_LABEL_NAME];
            int k = 0;
            while (l[k] && l[k] != ' ' && l[k] != '\t' && k < MAX_LABEL_NAME - 1) {
                name[k] = l[k];
                k++;
            }
            name[k] = 0;
            int t = resolve_label(name);
            if (t < 0) {
                set_error(q);
                return -1;
            }
            o[0] = 0x0F; o[1] = 0x85;
            put32(o + 2, t - (here + 6));
            toff += 6;
        } else if (starts(q, "call ")) {
            const char *l = skip_ws(q + 5);
            char name[MAX_LABEL_NAME];
            int k = 0;
            while (l[k] && l[k] != ' ' && l[k] != '\t' && k < MAX_LABEL_NAME - 1) {
                name[k] = l[k];
                k++;
            }
            name[k] = 0;
            int t = resolve_label(name);
            if (t < 0) {
                set_error(q);
                return -1;
            }
            o[0] = 0xE8;
            put32(o + 1, t - (here + 5));
            toff += 5;
        } else if (starts(q, "neg rax")) {
            o[0] = 0x48; o[1] = 0xF7; o[2] = 0xD8;
            toff += 3;
        } else if (starts(q, "not rax")) {
            o[0] = 0x48; o[1] = 0xF7; o[2] = 0xD0;
            toff += 3;
        } else if (starts(q, "ret")) {
            o[0] = 0xC3;
            toff += 1;
        } else {
            set_error(q);
            return -1;
        }
    }
    return 0;
}

int assemble(const char *text, char *out, int *outlen) {
    int n = c_read_file("/lib/ACCRT.BIN", (char *)rtbuf, (int)sizeof(rtbuf));
    if (n < 0 || n != RT_FILE_SIZE) return -1;
    if (pass1(text) != 0) {
        printf("acc: asm1 [%s]\r\n", asm_error);
        return -1;
    }
    if (RT_MEM_SIZE + text_size + data_size > OUT_MAX) return -1;
    memset(out, 0, RT_MEM_SIZE + text_size + data_size);
    memcpy(out, rtbuf, RT_FILE_SIZE);
    if (pass2(text, (unsigned char *)out) != 0) {
        printf("acc: asm2 [%s]\r\n", asm_error);
        return -1;
    }

    int cmd = label_index("cmd_main");
    if (cmd < 0) return -1;
    int target = RT_MEM_SIZE + label_offsets[cmd];
    int rel = target - (RT_CMD_CALL_OFF + 5);
    out[RT_CMD_CALL_OFF] = (char)0xE8;
    put32((unsigned char *)out + RT_CMD_CALL_OFF + 1, rel);
    *outlen = RT_MEM_SIZE + text_size + data_size;
    return 0;
}

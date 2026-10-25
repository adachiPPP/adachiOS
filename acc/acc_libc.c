#include "acc_os.h"

extern void *c_fs_open(unsigned short *path, unsigned long long mode, unsigned long long attr);
extern void *c_fs_open_x(unsigned short *path, unsigned long long mode, unsigned long long attr);
extern int c_need_write(void);

static void con_write(const char *s) {
    char buf[4096];
    int n = 0;
    while (*s && n < 4095) {
        if (*s == '\n' && n < 4094)
            buf[n++] = '\r';
        buf[n++] = *s++;
    }
    buf[n] = 0;
    puts_c(buf);
}

static unsigned char heap[4 * 1024 * 1024];
static size_t heap_pos;

static size_t align16(size_t n) {
    return (n + 15) & ~(size_t)15;
}

void *malloc(int n) {
    if (n <= 0) n = 1;
    size_t need = align16((size_t)n) + 16;
    if (heap_pos + need > sizeof(heap)) return NULL;
    unsigned char *p = heap + heap_pos;
    *(size_t *)p = (size_t)n;
    heap_pos += need;
    return p + 16;
}

void free(void *p) {
    (void)p;
}

void *calloc(int n, int size) {
    int total = n * size;
    void *p = malloc(total);
    if (p) memset(p, 0, total);
    return p;
}

void *realloc(void *p, int n) {
    if (!p) return malloc(n);
    unsigned char *b = (unsigned char *)p - 16;
    size_t old = *(size_t *)b;
    void *q = malloc(n);
    if (!q) return NULL;
    size_t copy = old < (size_t)n ? old : (size_t)n;
    memcpy(q, p, (int)copy);
    return q;
}

int strlen(const char *s) {
    int n = 0;
    while (s[n]) n++;
    return n;
}

int strcmp(const char *a, const char *b) {
    while (*a && *a == *b) {
        a++;
        b++;
    }
    return (unsigned char)*a - (unsigned char)*b;
}

int strncmp(const char *a, const char *b, int n) {
    while (n && *a && *a == *b) {
        a++;
        b++;
        n--;
    }
    if (n == 0) return 0;
    return (unsigned char)*a - (unsigned char)*b;
}

char *strcpy(char *d, const char *s) {
    char *r = d;
    while ((*d++ = *s++) != 0)
        ;
    return r;
}

void *memcpy(void *d, const void *s, int n) {
    unsigned char *dd = (unsigned char *)d;
    const unsigned char *ss = (const unsigned char *)s;
    for (int i = 0; i < n; i++) dd[i] = ss[i];
    return d;
}

void *memset(void *d, int c, int n) {
    unsigned char *dd = (unsigned char *)d;
    for (int i = 0; i < n; i++) dd[i] = (unsigned char)c;
    return d;
}

long long strtol(const char *s, char **end, int base) {
    const char *p = s;
    while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
    int neg = 0;
    if (*p == '-') {
        neg = 1;
        p++;
    } else if (*p == '+') {
        p++;
    }
    if (base == 0) {
        if (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) {
            base = 16;
            p += 2;
        } else if (p[0] == '0') {
            base = 8;
            p++;
        } else {
            base = 10;
        }
    } else if (base == 16 && p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) {
        p += 2;
    }
    long long v = 0;
    int any = 0;
    for (;;) {
        int c = (unsigned char)*p;
        int d = -1;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
        if (d < 0 || d >= base) break;
        v = v * base + d;
        any = 1;
        p++;
    }
    if (end) *end = (char *)(any ? p : s);
    return neg ? -v : v;
}

int isalpha(int c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

int isdigit(int c) {
    return c >= '0' && c <= '9';
}

int isalnum(int c) {
    return isalpha(c) || isdigit(c);
}

int isspace(int c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\f' || c == '\v';
}

static char *utoa(unsigned long long v, char *end, int base, int upper) {
    const char *digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char tmp[32];
    int n = 0;
    if (v == 0) tmp[n++] = '0';
    while (v) {
        tmp[n++] = digits[v % base];
        v /= base;
    }
    for (int i = 0; i < n; i++) *--end = tmp[i];
    return end;
}

int vsnprintf(char *buf, int n, const char *fmt, va_list ap) {
    int pos = 0;
    if (n > 0) buf[0] = 0;
    while (*fmt) {
        if (*fmt != '%') {
            if (pos + 1 < n) buf[pos] = *fmt;
            pos++;
            fmt++;
            continue;
        }
        fmt++;
        if (*fmt == '%') {
            if (pos + 1 < n) buf[pos] = '%';
            pos++;
            fmt++;
            continue;
        }
        int zero = 0;
        int width = 0;
        if (*fmt == '0') {
            zero = 1;
            fmt++;
        }
        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }
        int lng = 0;
        while (*fmt == 'l') {
            lng++;
            fmt++;
        }
        char spec = *fmt ? *fmt++ : 0;
        char tmp[64];
        char *s = tmp + sizeof(tmp);
        *--s = 0;
        if (spec == 's') {
            char *str = va_arg(ap, char *);
            if (!str) str = "(null)";
            int len = strlen(str);
            while (len > 0) *--s = str[--len];
        } else if (spec == 'c') {
            *--s = (char)va_arg(ap, int);
        } else if (spec == 'd') {
            long long v = lng ? va_arg(ap, long long) : (long long)va_arg(ap, int);
            unsigned long long u;
            int neg = v < 0;
            if (neg) u = (unsigned long long)(-v);
            else u = (unsigned long long)v;
            s = utoa(u, s, 10, 0);
            if (neg) *--s = '-';
        } else if (spec == 'u' || spec == 'x' || spec == 'X') {
            unsigned long long v = lng ? va_arg(ap, unsigned long long)
                                       : (unsigned long long)va_arg(ap, unsigned int);
            int base = (spec == 'u') ? 10 : 16;
            s = utoa(v, s, base, spec == 'X');
        } else {
            *--s = spec;
        }
        int len = (int)(tmp + sizeof(tmp) - 1 - s);
        int pad = width > len ? width - len : 0;
        if (zero && pad > 0) {
            if (*s == '-') {
                if (pos + 1 < n) buf[pos] = '-';
                pos++;
                s++;
            }
            while (pad-- > 0) {
                if (pos + 1 < n) buf[pos] = '0';
                pos++;
            }
        } else if (!zero) {
            while (pad-- > 0) {
                if (pos + 1 < n) buf[pos] = ' ';
                pos++;
            }
        }
        while (*s) {
            if (pos + 1 < n) buf[pos] = *s;
            pos++;
            s++;
        }
    }
    if (n > 0) {
        int end = pos < n - 1 ? pos : n - 1;
        buf[end] = 0;
    }
    return pos;
}

int snprintf(char *buf, int n, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int r = vsnprintf(buf, n, fmt, ap);
    va_end(ap);
    return r;
}

void putchar(int c) {
    char s[2];
    s[0] = (char)c;
    s[1] = 0;
    con_write(s);
}

void print_int(long long n) {
    char b[32];
    snprintf(b, sizeof(b), "%lld", n);
    con_write(b);
}

void printf(const char *fmt, ...) {
    char buf[2048];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    con_write(buf);
}

void exit(int code) {
    typedef unsigned long long (*exit_fn)(void *, unsigned long long, unsigned long long, void *);
    exit_fn fn = *(exit_fn *)((char *)bs + 216);
    fn(image_handle, (unsigned long long)code, 0, NULL);
    for (;;)
        ;
}

typedef struct {
    unsigned long long revision;
    void *open;
    unsigned long long (*close)(void *self);
    unsigned long long (*delete)(void *self);
    unsigned long long (*read)(void *self, unsigned long long *size, void *buf);
    unsigned long long (*write)(void *self, unsigned long long *size, const void *buf);
} efi_file;

static int make_wide_path(const char *path, unsigned short *out, int max) {
    int n = 0;
    if (path[0] != '/' && path[0] != '\\') {
        for (int i = 0; cwd_w[i] && n < max - 1; i++) out[n++] = cwd_w[i];
        if (n > 0 && out[n - 1] != '\\' && out[n - 1] != '/') {
            if (n < max - 1) out[n++] = '\\';
        }
    }
    for (int i = 0; path[i] && n < max - 1; i++) {
        unsigned short c = (unsigned char)path[i];
        if (c == '/') c = '\\';
        out[n++] = c;
    }
    out[n] = 0;
    return n;
}

static int copy_to_pathbuf(unsigned short *w) {
    int i = 0;
    for (; w[i] && i < 259; i++) pathbuf[i] = w[i];
    pathbuf[i] = 0;
    return i;
}

int c_read_file(const char *path, char *buf, int max) {
    unsigned short w[260];
    make_wide_path(path, w, 260);
    efi_file *f = (efi_file *)c_fs_open(w, 1, 0);
    if (!f) return -1;
    int total = 0;
    while (total < max) {
        unsigned long long sz = (unsigned long long)(max - total);
        unsigned long long st = f->read(f, &sz, buf + total);
        if (st != 0) {
            f->close(f);
            return -1;
        }
        if (sz == 0) break;
        total += (int)sz;
    }
    f->close(f);
    return total;
}

int c_write_file(const char *path, const char *buf, int len) {
    unsigned short w[260];
    make_wide_path(path, w, 260);
    copy_to_pathbuf(w);
    if (!c_need_write()) return -1;
    efi_file *f = (efi_file *)c_fs_open(w, 3, 0);
    if (f) f->delete(f);
    f = (efi_file *)c_fs_open_x(w, 0x8000000000000003ULL, 0);
    if (!f) return -1;
    unsigned long long sz = (unsigned long long)len;
    unsigned long long st = f->write(f, &sz, buf);
    f->close(f);
    return st == 0 ? 0 : -1;
}

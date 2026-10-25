#ifndef ACC_OS_H
#define ACC_OS_H

typedef unsigned long long size_t;
typedef __builtin_va_list va_list;

#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_end(ap) __builtin_va_end(ap)
#define va_arg(ap, type) __builtin_va_arg(ap, type)

#ifndef NULL
#define NULL 0
#endif

void *malloc(int n);
void *calloc(int n, int size);
void *realloc(void *p, int n);
void free(void *p);

int strlen(const char *s);
int strcmp(const char *a, const char *b);
int strncmp(const char *a, const char *b, int n);
char *strcpy(char *d, const char *s);
void *memcpy(void *d, const void *s, int n);
void *memset(void *d, int c, int n);
long long strtol(const char *s, char **end, int base);

int isalpha(int c);
int isdigit(int c);
int isalnum(int c);
int isspace(int c);

int snprintf(char *buf, int n, const char *fmt, ...);
int vsnprintf(char *buf, int n, const char *fmt, va_list ap);
void printf(const char *fmt, ...);
void puts(const char *s);
void puts_c(const char *s);
void putchar(int c);
void print_int(long long n);
void exit(int code);

int c_read_file(const char *path, char *buf, int max);
int c_write_file(const char *path, const char *buf, int len);
int assemble(const char *text, char *out, int *outlen);
int acc_main(int argc, char **argv);

extern unsigned short cwd_w[260];
extern unsigned char root_mode;
extern unsigned short pathbuf[260];
extern void *image_handle;
extern void *sys_table;
extern void *conout;
extern void *conin;
extern void *rt;
extern void *bs;
extern void *fs_device;
extern void *argp;
extern unsigned char guid_loaded[16];
extern void *con_putc_hook;
extern void *con_clear_hook;
extern void *con_set_cursor_hook;

extern void *fs_open(unsigned short *path, unsigned long long mode, unsigned long long attr);
extern void *fs_open_x(unsigned short *path, unsigned long long mode, unsigned long long attr);
extern int need_write(void);

#endif

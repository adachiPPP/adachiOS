
#ifndef ALIBC_H
#define ALIBC_H

#define NULL 0

typedef int word;

void putchar(int c);
void puts(char *s);
void print_int(int n);
void printf(char *fmt, ...);

int strlen(char *s);
int strcmp(char *a, char *b);
char *strcpy(char *dst, char *src);
void *memcpy(void *dst, void *src, int n);
void *memset(void *dst, int c, int n);
int atoi(char *s);

void *malloc(int n);
void free(void *p);
void exit(int code);

#endif

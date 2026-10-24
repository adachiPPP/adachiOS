#include "../alibc/alibc.h"

int g = 42;
char *msg = "global string";

int add(int a, int b) {
    return a + b;
}

int main(void) {
    int a[5];
    char buf[16];
    char *p;
    int i;

    for (i = 0; i < 5; i = i + 1) a[i] = i * i;
    printf("g=%d msg=%s\r\n", g, msg);
    printf("a=%d %d %d %d %d\r\n", a[0], a[1], a[2], a[3], a[4]);
    printf("add=%d\r\n", add(20, 22));

    p = malloc(32);
    strcpy(p, "heap");
    printf("p=%s len=%d\r\n", p, strlen(p));

    i = 0;
    while (i < 5) {
        buf[i] = 'a' + i;
        i = i + 1;
    }
    buf[5] = 0;
    printf("buf=%s cmp=%d\r\n", buf, strcmp(buf, "abcde"));

    if (a[3] == 9 && g > 40) puts("logic ok\r\n");
    else puts("logic bad\r\n");

    putchar('X');
    putchar('\r');
    putchar('\n');
    return 0;
}

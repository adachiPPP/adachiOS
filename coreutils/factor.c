int cur = 0;

char *next(void) {
    char *p;
    int n;
    int j;
    char *s;
    p = (char *)cur;
    if (p == 0) p = (char *)get_argp();
    while (p && p[0] != 0) {
        if (p[0] == ' ' || p[0] == '\t' || p[0] == '\r' || p[0] == '\n') {
            p = p + 2;
            continue;
        }
        break;
    }
    if (p == 0 || p[0] == 0) { cur = (int)p; return 0; }
    n = 0;
    while (p[n + n] != 0 && p[n + n] != ' ' && p[n + n] != '\t' && p[n + n] != '\r' && p[n + n] != '\n') n = n + 1;
    s = malloc(n + 1);
    for (j = 0; j < n; j = j + 1) s[j] = p[j + j];
    s[n] = '\0';
    p = p + n + n;
    cur = (int)p;
    return s;
}

int main(void) {
    char *a;
    int d;
    int f;
    int x;
    int m;
    a = next();
    if (a == 0) { puts("factor: usage: factor N...\r\n"); return 1; }
    while (a != 0) {
        x = atoi(a);
        print_int(x);
        puts(": ");
        if (x <= 1) { puts("none\r\n"); a = next(); continue; }
        m = x;
        f = 2;
        while (m > 1) {
            if (m % f == 0) {
                print_int(f);
                puts(" ");
                m = m / f;
            } else {
                f = f + 1;
            }
        }
        puts("\r\n");
        a = next();
    }
    return 0;
}

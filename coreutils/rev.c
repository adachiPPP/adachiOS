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
    a = next();
    if (a == 0) { puts("rev: usage: rev TEXT...\r\n"); return 1; }
    while (a != 0) {
        int len = strlen(a);
        while (len > 0) { len = len - 1; putchar(a[len]); }
        puts("\r\n");
        a = next();
    }
    return 0;
}

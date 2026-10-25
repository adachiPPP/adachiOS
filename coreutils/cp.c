char buf[16384];
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
    char *b;
    int n;
    a = next();
    b = next();
    if (a == 0 || b == 0) { puts("cp: usage: cp SRC DST\r\n"); return 1; }
    n = read_file(a, buf, 16383);
    if (n < 0) {
        puts("cp: cannot read ");
        puts(a);
        puts("\r\n");
        return 1;
    }
    if (write_file(b, buf, n) < 0) {
        puts("cp: cannot write ");
        puts(b);
        puts("\r\n");
        return 1;
    }
    return 0;
}

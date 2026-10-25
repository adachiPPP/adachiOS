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
    int n;
    int c;
    int lines = 0;
    int words = 0;
    int bytes = 0;
    int inword = 0;
    a = next();
    if (a == 0) { puts("wc: usage: wc FILE [FILE...]\r\n"); return 1; }
    while (a != 0) {
        n = read_file(a, buf, 16383);
        if (n < 0) {
            puts("wc: cannot read ");
            puts(a);
            puts("\r\n");
        } else {
            for (c = 0; c < n; c = c + 1) {
                bytes = bytes + 1;
                if (buf[c] == '\n') lines = lines + 1;
                if (buf[c] == ' ' || buf[c] == '\t' || buf[c] == '\n' || buf[c] == '\r') {
                    inword = 0;
                } else if (inword == 0) {
                    inword = 1;
                    words = words + 1;
                }
            }
            printf("%d %d %d %s\r\n", bytes, words, lines, a);
        }
        a = next();
        lines = 0;
        words = 0;
        bytes = 0;
        inword = 0;
    }
    return 0;
}

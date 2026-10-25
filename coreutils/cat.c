char buf[16384];
char path[256];

int main(void) {
    char *p;
    int n;
    int i;
    int pathi = 0;
    p = (char *)get_argp();
    if (p == 0) { puts("cat: usage: cat FILE...\r\n"); return 1; }
    while (p && p[0] != 0) {
        if (p[0] == ' ' || p[0] == '\t' || p[0] == '\r' || p[0] == '\n') {
            p = p + 2;
            continue;
        }
        pathi = 0;
        while (p[0] != 0 && p[0] != ' ' && p[0] != '\t' && p[0] != '\r' && p[0] != '\n' && pathi < 255) {
            path[pathi] = p[0];
            pathi = pathi + 1;
            p = p + 2;
        }
        path[pathi] = '\0';
        n = read_file(path, buf, 16383);
        if (n < 0) {
            puts("cat: cannot read ");
            puts(path);
            puts("\r\n");
        } else {
            buf[n] = '\0';
            puts(buf);
        }
    }
    return 0;
}

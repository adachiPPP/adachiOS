int main(void) {
    char *p = (char *)get_argp();
    int space = 0;
    int saw = 0;
    if (p == 0) { puts("\r\n"); return 0; }
    while (*p != 0) {
        if (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') {
            space = 1;
            p = p + 2;
            continue;
        }
        if (space && saw) {
            putchar(' ');
            space = 0;
        }
        putchar(*p);
        saw = 1;
        p = p + 2;
    }
    puts("\r\n");
    return 0;
}

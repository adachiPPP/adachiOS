
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <unistd.h>

enum { TY_INT, TY_CHAR, TY_VOID, TY_PTR, TY_ARRAY };

static int word_size = 8;
static int target_bios = 0;

typedef struct Type Type;
struct Type {
    int kind;
    Type *base;
    int len;
};

static Type *ty_int, *ty_char, *ty_void;

static Type *mktype(int kind, Type *base, int len) {
    Type *t = calloc(1, sizeof(Type));
    t->kind = kind;
    t->base = base;
    t->len = len;
    return t;
}

static int type_size(Type *t) {
    switch (t->kind) {
    case TY_INT: return word_size;
    case TY_CHAR: return 1;
    case TY_VOID: return 0;
    case TY_PTR: return word_size;
    case TY_ARRAY: return t->len * type_size(t->base);
    }
    return 0;
}

enum { TK_EOF, TK_ID, TK_NUM, TK_STR, TK_PUNCT };

typedef struct {
    int kind;
    char *text;
    long val;
} Token;

static Token *toks;
static int ntoks, toks_cap;
static int tok_i;

static char *xstrdup(const char *s) {
    char *p = malloc(strlen(s) + 1);
    strcpy(p, s);
    return p;
}

static void add_tok(int kind, const char *text, long val) {
    if (ntoks == toks_cap) {
        toks_cap = toks_cap ? toks_cap * 2 : 256;
        toks = realloc(toks, toks_cap * sizeof(Token));
    }
    toks[ntoks].kind = kind;
    toks[ntoks].text = text ? xstrdup(text) : NULL;
    toks[ntoks].val = val;
    ntoks++;
}

typedef struct Macro {
    char *name;
    long val;
    int is_num;
    struct Macro *next;
} Macro;

static Macro *macros;

static Macro *find_macro(const char *name) {
    for (Macro *m = macros; m; m = m->next)
        if (!strcmp(m->name, name)) return m;
    return NULL;
}

static void add_macro(const char *name, const char *value) {
    Macro *m = calloc(1, sizeof(Macro));
    m->name = xstrdup(name);
    m->is_num = 0;
    if (value) {
        char *end;
        long v = strtol(value, &end, 0);
        while (*end == ' ' || *end == '\t') end++;
        if (end != value && *end == 0) {
            m->val = v;
            m->is_num = 1;
        }
    }
    m->next = macros;
    macros = m;
}

static void fatal(const char *msg) {
    fprintf(stderr, "acc: %s\n", msg);
    exit(1);
}

static const char *src;
static int src_len, src_pos;
static int line_no = 1;
static int bol = 1;

static int peekc(int off) {
    if (src_pos + off >= src_len) return -1;
    return (unsigned char)src[src_pos + off];
}

static int getc_src(void) {
    if (src_pos >= src_len) return -1;
    int c = (unsigned char)src[src_pos++];
    if (c == '\n') line_no++;
    return c;
}

static void skip_line(void) {
    int c;
    while ((c = getc_src()) != -1 && c != '\n')
        ;
    bol = 1;
}

static void do_directive(void) {
    getc_src();
    while (peekc(0) == ' ' || peekc(0) == '\t') getc_src();
    char word[64];
    int n = 0;
    while (isalpha(peekc(0)) || peekc(0) == '_') {
        if (n < 63) word[n++] = (char)getc_src();
        else getc_src();
    }
    word[n] = 0;
    if (!strcmp(word, "include")) {
        skip_line();
    } else if (!strcmp(word, "define")) {
        while (peekc(0) == ' ' || peekc(0) == '\t') getc_src();
        char name[128];
        n = 0;
        while (isalnum(peekc(0)) || peekc(0) == '_') {
            if (n < 127) name[n++] = (char)getc_src();
            else getc_src();
        }
        name[n] = 0;
        while (peekc(0) == ' ' || peekc(0) == '\t') getc_src();
        char val[256];
        n = 0;
        while (peekc(0) != -1 && peekc(0) != '\n') {
            int c = getc_src();
            if (n < 255) val[n++] = (char)c;
        }
        val[n] = 0;
        if (n) add_macro(name, val);
        bol = 1;
    } else {
        skip_line();
    }
}

static void skip_ws(void) {
    for (;;) {
        int c = peekc(0);
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            if (c == '\n') bol = 1;
            getc_src();
            continue;
        }
        if (bol && c == '#') {
            do_directive();
            continue;
        }
        if (c == '/' && peekc(1) == '/') {
            skip_line();
            continue;
        }
        if (c == '/' && peekc(1) == '*') {
            getc_src();
            getc_src();
            while (peekc(0) != -1 && !(peekc(0) == '*' && peekc(1) == '/')) {
                if (peekc(0) == '\n') bol = 1;
                getc_src();
            }
            if (peekc(0) != -1) {
                getc_src();
                getc_src();
            }
            continue;
        }
        break;
    }
    if (peekc(0) != ' ' && peekc(0) != '\t' && peekc(0) != '\n' && peekc(0) != '\r')
        bol = 0;
}

static void lex_ident(void) {
    char buf[256];
    int n = 0;
    while (isalnum(peekc(0)) || peekc(0) == '_') {
        if (n < 255) buf[n++] = (char)getc_src();
        else getc_src();
    }
    buf[n] = 0;
    Macro *m = find_macro(buf);
    if (m && m->is_num) add_tok(TK_NUM, NULL, m->val);
    else add_tok(TK_ID, buf, 0);
}

static int hexval(int c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static void lex_number(void) {
    char buf[64];
    int n = 0;
    if (peekc(0) == '0' && (peekc(1) == 'x' || peekc(1) == 'X')) {
        buf[n++] = (char)getc_src();
        buf[n++] = (char)getc_src();
        while (hexval(peekc(0)) >= 0) {
            if (n < 63) buf[n++] = (char)getc_src();
            else getc_src();
        }
    } else {
        while (isdigit(peekc(0))) {
            if (n < 63) buf[n++] = (char)getc_src();
            else getc_src();
        }
    }
    buf[n] = 0;
    add_tok(TK_NUM, NULL, strtol(buf, NULL, 0));
}

static int read_escape(void) {
    int c = getc_src();
    switch (c) {
    case 'n': return '\n';
    case 'r': return '\r';
    case 't': return '\t';
    case '0': return 0;
    case '\\': return '\\';
    case '\'': return '\'';
    case '"': return '"';
    default: return c;
    }
}

static void lex_char(void) {
    getc_src();
    int v;
    if (peekc(0) == '\\') {
        getc_src();
        v = read_escape();
    } else {
        v = getc_src();
    }
    if (peekc(0) == '\'') getc_src();
    add_tok(TK_NUM, NULL, v);
}

static void lex_string(void) {
    getc_src();
    char buf[4096];
    int n = 0;
    while (peekc(0) != -1 && peekc(0) != '"') {
        int c;
        if (peekc(0) == '\\') {
            getc_src();
            c = read_escape();
        } else {
            c = getc_src();
        }
        if (n < 4095) buf[n++] = (char)c;
    }
    if (peekc(0) == '"') getc_src();
    buf[n] = 0;
    add_tok(TK_STR, buf, 0);
}

static void lex_punct(void) {
    static const char *two[] = {
        "==", "!=", "<=", ">=", "&&", "||", "++", "--",
        "+=", "-=", "->", "<<", ">>", NULL
    };
    for (int i = 0; two[i]; i++) {
        if (peekc(0) == two[i][0] && peekc(1) == two[i][1]) {
            getc_src();
            getc_src();
            add_tok(TK_PUNCT, two[i], 0);
            return;
        }
    }
    char buf[2];
    buf[0] = (char)getc_src();
    buf[1] = 0;
    add_tok(TK_PUNCT, buf, 0);
}

static void tokenize(const char *text) {
    src = text;
    src_len = (int)strlen(text);
    src_pos = 0;
    line_no = 1;
    bol = 1;
    for (;;) {
        skip_ws();
        int c = peekc(0);
        if (c == -1) break;
        if (isalpha(c) || c == '_') lex_ident();
        else if (isdigit(c)) lex_number();
        else if (c == '\'') lex_char();
        else if (c == '"') lex_string();
        else lex_punct();
    }
    add_tok(TK_EOF, NULL, 0);
}

static Token *cur(void) { return &toks[tok_i]; }

static const char *tok_text(int off) {
    if (off < 0 || off >= ntoks) return NULL;
    return toks[off].text;
}

static int at(const char *s) {
    Token *t = cur();
    return (t->kind == TK_ID || t->kind == TK_PUNCT) && t->text && !strcmp(t->text, s);
}

static int accept(const char *s) {
    if (at(s)) {
        tok_i++;
        return 1;
    }
    return 0;
}

static void expect(const char *s) {
    if (!accept(s)) {
        fprintf(stderr, "acc: line %d: expected '%s' near '%s'\n",
                line_no, s, cur()->text ? cur()->text : "<eof>");
        exit(1);
    }
}

static char *expect_id(void) {
    if (cur()->kind != TK_ID) {
        fprintf(stderr, "acc: line %d: expected identifier\n", line_no);
        exit(1);
    }
    char *s = xstrdup(cur()->text);
    tok_i++;
    return s;
}

enum {
    NK_NUM, NK_STR, NK_VAR, NK_CALL, NK_BIN, NK_UN,
    NK_ASSIGN, NK_INDEX, NK_ADDR, NK_DEREF, NK_CAST
};

typedef struct Node Node;
struct Node {
    int kind;
    int op;
    long val;
    char *name;
    Type *type;
    Node *a, *b, *c;
    Node *args;
    Node *next;
    void *sym;
};

static Node *mknode(int kind) {
    Node *n = calloc(1, sizeof(Node));
    n->kind = kind;
    return n;
}

static Node *mknum(long v) {
    Node *n = mknode(NK_NUM);
    n->val = v;
    n->type = ty_int;
    return n;
}

enum {
    SK_BLOCK, SK_IF, SK_WHILE, SK_FOR, SK_RETURN,
    SK_EXPR, SK_DECL, SK_BREAK, SK_CONTINUE
};

typedef struct Stmt Stmt;
struct Stmt {
    int kind;
    Node *e1, *e2, *e3;
    Stmt *body, *els, *next;
    void *sym;
};

static Stmt *mkstmt(int kind) {
    Stmt *s = calloc(1, sizeof(Stmt));
    s->kind = kind;
    return s;
}

typedef struct Var Var;
struct Var {
    char *name;
    Type *type;
    int is_global;
    int is_param;
    int offset;
    Node *init;
    Node *init_list;
    int init_count;
    Var *next;
};

typedef struct Func Func;
struct Func {
    char *name;
    Type *ret;
    Var *params;
    Var *locals;
    int nparams;
    int local_size;
    int frame;
    Stmt *body;
    Func *next;
};

static Var *globals;
static Func *funcs;
static Func *cur_func;

static Var *find_var(const char *name) {
    if (cur_func) {
        for (Var *v = cur_func->locals; v; v = v->next)
            if (!strcmp(v->name, name)) return v;
        for (Var *v = cur_func->params; v; v = v->next)
            if (!strcmp(v->name, name)) return v;
    }
    for (Var *v = globals; v; v = v->next)
        if (!strcmp(v->name, name)) return v;
    return NULL;
}

static Func *find_func(const char *name) {
    for (Func *f = funcs; f; f = f->next)
        if (!strcmp(f->name, name)) return f;
    return NULL;
}

static Var *add_global(const char *name, Type *t) {
    Var *v = calloc(1, sizeof(Var));
    v->name = xstrdup(name);
    v->type = t;
    v->is_global = 1;
    v->next = globals;
    globals = v;
    return v;
}

static Var *add_local(const char *name, Type *t) {
    Var *v = calloc(1, sizeof(Var));
    v->name = xstrdup(name);
    v->type = t;
    int sz = type_size(t);
    if (sz < 1) sz = 1;
    cur_func->local_size += sz;
    cur_func->local_size = (cur_func->local_size + (word_size - 1)) & ~(word_size - 1);
    v->offset = cur_func->local_size;
    v->next = cur_func->locals;
    cur_func->locals = v;
    return v;
}

static Func *add_func(const char *name, Type *ret) {
    Func *f = calloc(1, sizeof(Func));
    f->name = xstrdup(name);
    f->ret = ret;
    f->next = funcs;
    funcs = f;
    return f;
}

static int str_count = 0;
static Node **strs;
static int strs_cap;

static int is_type_start(void) {
    return at("int") || at("char") || at("void");
}

static Type *parse_type(void) {
    Type *t;
    if (accept("int")) t = ty_int;
    else if (accept("char")) t = ty_char;
    else if (accept("void")) t = ty_void;
    else fatal("type expected");
    while (accept("*")) t = mktype(TY_PTR, t, 0);
    return t;
}

static Node *parse_expr(void);
static Stmt *parse_block(void);
static Stmt *parse_stmt(void);
static void parse_decl(int global);
static Stmt *pending_decl;

static long const_expr(void) {
    int neg = 0;
    if (accept("-")) neg = 1;
    if (cur()->kind == TK_NUM) {
        long v = cur()->val;
        tok_i++;
        return neg ? -v : v;
    }
    fatal("constant expected");
    return 0;
}

static Node *add_str(const char *s) {
    if (str_count == strs_cap) {
        strs_cap = strs_cap ? strs_cap * 2 : 16;
        strs = realloc(strs, strs_cap * sizeof(Node *));
    }
    Node *n = mknode(NK_STR);
    n->name = xstrdup(s);
    n->val = str_count;
    n->type = mktype(TY_PTR, ty_char, 0);
    strs[str_count++] = n;
    return n;
}

static Node *parse_primary(void) {
    if (cur()->kind == TK_NUM) {
        Node *n = mknum(cur()->val);
        tok_i++;
        return n;
    }
    if (cur()->kind == TK_STR) {
        Node *n = add_str(cur()->text);
        tok_i++;
        return n;
    }
    if (accept("(")) {
        Node *n = parse_expr();
        expect(")");
        return n;
    }
    if (cur()->kind == TK_ID) {
        char *name = xstrdup(cur()->text);
        tok_i++;
        Var *v = find_var(name);
        if (v) {
            Node *n = mknode(NK_VAR);
            n->name = name;
            n->type = v->type;
            n->sym = v;
            return n;
        }

        Node *n = mknode(NK_VAR);
        n->name = name;
        n->type = ty_int;
        n->sym = NULL;
        return n;
    }
    fprintf(stderr, "acc: line %d: expression expected near '%s'\n",
            line_no, cur()->text ? cur()->text : "<eof>");
    exit(1);
}

static Node *parse_postfix(void) {
    Node *n = parse_primary();
    for (;;) {
        if (accept("(")) {
            Node *call = mknode(NK_CALL);
            call->a = n;
            Node *head = NULL, **tail = &head;
            if (!accept(")")) {
                do {
                    Node *arg = parse_expr();
                    *tail = arg;
                    tail = &arg->next;
                } while (accept(","));
                expect(")");
            }
            call->args = head;
            call->type = ty_int;
            n = call;
        } else if (accept("[")) {
            Node *idx = mknode(NK_INDEX);
            idx->a = n;
            idx->b = parse_expr();
            expect("]");
            Type *bt = n->type;
            if (bt && (bt->kind == TY_PTR || bt->kind == TY_ARRAY))
                idx->type = bt->base;
            else
                idx->type = ty_int;
            n = idx;
        } else {
            break;
        }
    }
    return n;
}

static Node *parse_unary(void) {
    if (accept("-")) {
        Node *n = mknode(NK_UN);
        n->op = '-';
        n->a = parse_unary();
        n->type = n->a->type;
        return n;
    }
    if (accept("+")) return parse_unary();
    if (accept("!")) {
        Node *n = mknode(NK_UN);
        n->op = '!';
        n->a = parse_unary();
        n->type = ty_int;
        return n;
    }
    if (accept("~")) {
        Node *n = mknode(NK_UN);
        n->op = '~';
        n->a = parse_unary();
        n->type = n->a->type;
        return n;
    }
    if (accept("&")) {
        Node *n = mknode(NK_ADDR);
        n->a = parse_unary();
        n->type = mktype(TY_PTR, n->a->type, 0);
        return n;
    }
    if (accept("*")) {
        Node *n = mknode(NK_DEREF);
        n->a = parse_unary();
        Type *bt = n->a->type;
        n->type = (bt && bt->kind == TY_PTR) ? bt->base : ty_int;
        return n;
    }
    if (accept("sizeof")) {
        if (accept("(")) {
            if (is_type_start()) {
                Type *t = parse_type();
                expect(")");
                return mknum(type_size(t));
            }
            Node *e = parse_expr();
            expect(")");
            return mknum(type_size(e->type ? e->type : ty_int));
        }
        Node *e = parse_unary();
        return mknum(type_size(e->type ? e->type : ty_int));
    }

    if (at("(") && tok_text(tok_i + 1) &&
        (!strcmp(tok_text(tok_i + 1), "int") ||
         !strcmp(tok_text(tok_i + 1), "char") ||
         !strcmp(tok_text(tok_i + 1), "void"))) {
        accept("(");
        Type *t = parse_type();
        expect(")");
        Node *n = mknode(NK_CAST);
        n->type = t;
        n->a = parse_unary();
        return n;
    }
    return parse_postfix();
}

static Node *mkbin(int op, Node *a, Node *b) {
    Node *n = mknode(NK_BIN);
    n->op = op;
    n->a = a;
    n->b = b;
    n->type = ty_int;
    return n;
}

static Node *parse_mul(void) {
    Node *n = parse_unary();
    for (;;) {
        if (accept("*")) n = mkbin('*', n, parse_unary());
        else if (accept("/")) n = mkbin('/', n, parse_unary());
        else if (accept("%")) n = mkbin('%', n, parse_unary());
        else return n;
    }
}

static Node *parse_add(void) {
    Node *n = parse_mul();
    for (;;) {
        if (accept("+")) n = mkbin('+', n, parse_mul());
        else if (accept("-")) n = mkbin('-', n, parse_mul());
        else return n;
    }
}

static Node *parse_rel(void) {
    Node *n = parse_add();
    for (;;) {
        if (accept("<")) n = mkbin('<', n, parse_add());
        else if (accept("<=")) n = mkbin(1, n, parse_add());
        else if (accept(">")) n = mkbin('>', n, parse_add());
        else if (accept(">=")) n = mkbin(2, n, parse_add());
        else return n;
    }
}

static Node *parse_eq(void) {
    Node *n = parse_rel();
    for (;;) {
        if (accept("==")) n = mkbin(3, n, parse_rel());
        else if (accept("!=")) n = mkbin(4, n, parse_rel());
        else return n;
    }
}

static Node *parse_land(void) {
    Node *n = parse_eq();
    while (accept("&&")) n = mkbin(5, n, parse_eq());
    return n;
}

static Node *parse_lor(void) {
    Node *n = parse_land();
    while (accept("||")) n = mkbin(6, n, parse_land());
    return n;
}

static Node *parse_assign(void) {
    Node *n = parse_lor();
    if (accept("=")) {
        Node *a = mknode(NK_ASSIGN);
        a->a = n;
        a->b = parse_assign();
        a->type = n->type;
        return a;
    }
    if (accept("+=")) {
        Node *a = mknode(NK_ASSIGN);
        a->a = n;
        a->b = mkbin('+', n, parse_assign());
        a->type = n->type;
        return a;
    }
    if (accept("-=")) {
        Node *a = mknode(NK_ASSIGN);
        a->a = n;
        a->b = mkbin('-', n, parse_assign());
        a->type = n->type;
        return a;
    }
    return n;
}

static Node *parse_expr(void) {
    return parse_assign();
}

static void parse_global_init(Var *v) {
    if (accept("{")) {
        Node *head = NULL, **tail = &head;
        int count = 0;
        if (!accept("}")) {
            do {
                Node *e = parse_assign();
                *tail = e;
                tail = &e->next;
                count++;
            } while (accept(","));
            expect("}");
        }
        v->init_list = head;
        v->init_count = count;
    } else {
        v->init = parse_assign();
    }
}

static void parse_function(Type *ret, const char *name) {
    Func *f = add_func(name, ret);
    Func *old = cur_func;
    cur_func = f;
    expect("(");
    if (accept(")")) {

    } else if (at("void") && tok_text(tok_i + 1) &&
               !strcmp(tok_text(tok_i + 1), ")")) {
        tok_i++;
        expect(")");
    } else {
        int i = 0;
        do {
            Type *pt = parse_type();
            char *pn = expect_id();
            Var *v = calloc(1, sizeof(Var));
            v->name = pn;
            v->type = pt;
            v->is_param = 1;
            v->offset = target_bios ? (4 + 2 * i) : (16 + 8 * i);
            v->next = f->params;
            f->params = v;
            i++;
        } while (accept(","));
        expect(")");
        f->nparams = i;
    }
    if (accept(";")) {
        cur_func = old;
        return;
    }
    f->body = parse_block();
    f->frame = (f->local_size + (target_bios ? 1 : 15)) &
               ~(target_bios ? 1 : 15);
    cur_func = old;
}

static void parse_decl(int global) {
    Type *t = parse_type();
    char *name = expect_id();
    if (at("(")) {
        if (!global) fatal("nested function");
        parse_function(t, name);
        return;
    }
    if (accept("[")) {
        int len = (int)const_expr();
        expect("]");
        t = mktype(TY_ARRAY, t, len);
    }
    if (global) {
        Var *v = add_global(name, t);
        if (accept("=")) parse_global_init(v);
        expect(";");
    } else {
        Var *v = add_local(name, t);
        Node *init = NULL;
        if (accept("=")) init = parse_expr();
        expect(";");
        Stmt *s = mkstmt(SK_DECL);
        s->sym = v;
        s->e1 = init;

        pending_decl = s;
    }
}

static Stmt *parse_block(void) {
    expect("{");
    Stmt *head = NULL, **tail = &head;
    while (!accept("}")) {
        if (cur()->kind == TK_EOF) fatal("unterminated block");
        Stmt *s = parse_stmt();
        if (s) {
            *tail = s;
            tail = &s->next;
        }
    }
    Stmt *b = mkstmt(SK_BLOCK);
    b->body = head;
    return b;
}

static Stmt *parse_stmt(void) {
    if (at("{")) return parse_block();
    if (accept("if")) {
        Stmt *s = mkstmt(SK_IF);
        expect("(");
        s->e1 = parse_expr();
        expect(")");
        s->body = parse_stmt();
        if (accept("else")) s->els = parse_stmt();
        return s;
    }
    if (accept("while")) {
        Stmt *s = mkstmt(SK_WHILE);
        expect("(");
        s->e1 = parse_expr();
        expect(")");
        s->body = parse_stmt();
        return s;
    }
    if (accept("for")) {
        Stmt *s = mkstmt(SK_FOR);
        expect("(");
        if (accept(";")) {
            s->body = NULL;
        } else if (is_type_start()) {
            pending_decl = NULL;
            parse_decl(0);
            s->body = pending_decl;
        } else {
            Node *e = parse_expr();
            expect(";");
            Stmt *init = mkstmt(SK_EXPR);
            init->e1 = e;
            s->body = init;
        }
        if (!accept(";")) {
            s->e1 = parse_expr();
            expect(";");
        }
        if (!accept(")")) {
            s->e2 = parse_expr();
            expect(")");
        }
        s->e3 = NULL;
        Stmt *body = parse_stmt();

        s->els = body;
        return s;
    }
    if (accept("return")) {
        Stmt *s = mkstmt(SK_RETURN);
        if (!accept(";")) {
            s->e1 = parse_expr();
            expect(";");
        }
        return s;
    }
    if (accept("break")) {
        expect(";");
        return mkstmt(SK_BREAK);
    }
    if (accept("continue")) {
        expect(";");
        return mkstmt(SK_CONTINUE);
    }
    if (accept(";")) return NULL;
    if (is_type_start()) {
        pending_decl = NULL;
        parse_decl(0);
        return pending_decl;
    }
    Stmt *s = mkstmt(SK_EXPR);
    s->e1 = parse_expr();
    expect(";");
    return s;
}

static FILE *out;
static int label_no = 0;
static const char *cur_ret_label;

static int new_label(void) { return label_no++; }

static void emit(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(out, fmt, ap);
    va_end(ap);
    fputc('\n', out);
}

static const char *func_label(const char *name) {
    static char buf[256];
    static const char *builtins[] = {
        "putchar", "puts", "print_int", "printf", "strlen", "strcmp",
        "strcpy", "memcpy", "memset", "atoi", "clear", "malloc", "free", "exit",
        "read_file", "write_file", "delete_file", "sleep_seconds", "get_argp",
        "fs_open", "fs_open_x", "need_write", NULL
    };
    for (int i = 0; builtins[i]; i++) {
        if (!strcmp(name, builtins[i])) {
            snprintf(buf, sizeof(buf), "c_%s", name);
            return buf;
        }
    }
    snprintf(buf, sizeof(buf), "u_%s", name);
    return buf;
}

static void gen_addr(Node *n);
static void gen_expr(Node *n);

static void push_rax(void) {
    if (target_bios) emit("    push ax");
    else emit("    push rax");
}

static void gen_addr(Node *n) {
    if (n->kind == NK_VAR) {
        Var *v = n->sym;
        if (!v) fatal("unknown variable");
        if (v->is_global) {
            if (target_bios) emit("    mov ax, g_%s", v->name);
            else emit("    lea rax, [rel g_%s]", v->name);
        } else if (v->is_param) {
            if (target_bios) emit("    lea ax, [bp+%d]", v->offset);
            else emit("    lea rax, [rbp+%d]", v->offset);
        } else {
            if (target_bios) emit("    lea ax, [bp-%d]", v->offset);
            else emit("    lea rax, [rbp-%d]", v->offset);
        }
        return;
    }
    if (n->kind == NK_STR) {
        if (target_bios) emit("    mov ax, s_%ld", n->val);
        else emit("    lea rax, [rel s_%ld]", n->val);
        return;
    }
    if (n->kind == NK_INDEX) {
        gen_addr(n->a);
        push_rax();
        gen_expr(n->b);
        int sz = n->type ? type_size(n->type) : word_size;
        if (sz != 1) {
            if (target_bios) emit("    imul ax, ax, %d", sz);
            else emit("    imul rax, rax, %d", sz);
        }
        if (target_bios) emit("    pop bx");
        else emit("    pop rbx");
        if (target_bios) emit("    add ax, bx");
        else emit("    add rax, rbx");
        return;
    }
    if (n->kind == NK_DEREF) {
        gen_expr(n->a);
        return;
    }
    fatal("not an lvalue");
}

static void gen_load(Type *t) {
    if (!t) t = ty_int;
    if (t->kind == TY_ARRAY) return;
    if (t->kind == TY_CHAR) {
        if (target_bios) {
            emit("    mov bx, ax");
            emit("    mov al, [bx]");
            emit("    movzx ax, al");
        } else {
            emit("    movzx eax, byte [rax]");
        }
        return;
    }
    if (target_bios) {
        emit("    mov bx, ax");
        emit("    mov ax, [bx]");
    } else {
        emit("    mov rax, [rax]");
    }
}

static void gen_store(Type *t) {
    if (!t) t = ty_int;
    if (t->kind == TY_CHAR) {
        if (target_bios) emit("    mov [bx], al");
        else emit("    mov [rbx], al");
        return;
    }
    if (target_bios) emit("    mov [bx], ax");
    else emit("    mov [rbx], rax");
}

static void gen_expr(Node *n) {
    switch (n->kind) {
    case NK_NUM:
        if (target_bios) emit("    mov ax, %ld", n->val);
        else emit("    mov rax, %ld", n->val);
        return;
    case NK_STR:
        gen_addr(n);
        return;
    case NK_VAR:
        gen_addr(n);
        gen_load(n->type);
        return;
    case NK_INDEX:
        gen_addr(n);
        gen_load(n->type);
        return;
    case NK_DEREF:
        gen_expr(n->a);
        gen_load(n->type);
        return;
    case NK_ADDR:
        gen_addr(n->a);
        return;
    case NK_CAST:
        gen_expr(n->a);
        return;
    case NK_ASSIGN:
        gen_addr(n->a);
        push_rax();
        gen_expr(n->b);
        if (target_bios) emit("    pop bx");
        else emit("    pop rbx");
        gen_store(n->a->type);
        return;
    case NK_UN:
        gen_expr(n->a);
        if (n->op == '-') {
            if (target_bios) emit("    neg ax");
            else emit("    neg rax");
        } else if (n->op == '!') {
            if (target_bios) {
                emit("    test ax, ax");
                emit("    setz al");
                emit("    movzx ax, al");
            } else {
                emit("    test rax, rax");
                emit("    setz al");
                emit("    movzx rax, al");
            }
        } else if (n->op == '~') {
            if (target_bios) emit("    not ax");
            else emit("    not rax");
        }
        return;
    case NK_BIN: {
        if (n->op == 5) {
            int lf = new_label(), le = new_label();
            gen_expr(n->a);
            if (target_bios) emit("    test ax, ax");
            else emit("    test rax, rax");
            emit("    jz .L%d", lf);
            gen_expr(n->b);
            if (target_bios) emit("    test ax, ax");
            else emit("    test rax, rax");
            emit("    jz .L%d", lf);
            if (target_bios) emit("    mov ax, 1");
            else emit("    mov rax, 1");
            emit("    jmp .L%d", le);
            emit(".L%d:", lf);
            if (target_bios) emit("    xor ax, ax");
            else emit("    xor rax, rax");
            emit(".L%d:", le);
            return;
        }
        if (n->op == 6) {
            int lt = new_label(), le = new_label();
            gen_expr(n->a);
            if (target_bios) emit("    test ax, ax");
            else emit("    test rax, rax");
            emit("    jnz .L%d", lt);
            gen_expr(n->b);
            if (target_bios) emit("    test ax, ax");
            else emit("    test rax, rax");
            emit("    jnz .L%d", lt);
            if (target_bios) emit("    xor ax, ax");
            else emit("    xor rax, rax");
            emit("    jmp .L%d", le);
            emit(".L%d:", lt);
            if (target_bios) emit("    mov ax, 1");
            else emit("    mov rax, 1");
            emit(".L%d:", le);
            return;
        }
        gen_expr(n->a);
        push_rax();
        gen_expr(n->b);
        if (target_bios) emit("    mov bx, ax");
        else emit("    mov rbx, rax");
        if (target_bios) emit("    pop ax");
        else emit("    pop rax");
        switch (n->op) {
        case '+':
            if (target_bios) emit("    add ax, bx");
            else emit("    add rax, rbx");
            break;
        case '-':
            if (target_bios) emit("    sub ax, bx");
            else emit("    sub rax, rbx");
            break;
        case '*':
            if (target_bios) emit("    imul bx");
            else emit("    imul rax, rbx");
            break;
        case '/':
            if (target_bios) { emit("    cwd"); emit("    idiv bx"); }
            else { emit("    cqo"); emit("    idiv rbx"); }
            break;
        case '%':
            if (target_bios) { emit("    cwd"); emit("    idiv bx"); emit("    mov ax, dx"); }
            else { emit("    cqo"); emit("    idiv rbx"); emit("    mov rax, rdx"); }
            break;
        case '&':
            if (target_bios) emit("    and ax, bx");
            else emit("    and rax, rbx");
            break;
        case '|':
            if (target_bios) emit("    or ax, bx");
            else emit("    or rax, rbx");
            break;
        case '^':
            if (target_bios) emit("    xor ax, bx");
            else emit("    xor rax, rbx");
            break;
        case 1:
            if (target_bios) { emit("    cmp ax, bx"); emit("    setle al"); emit("    movzx ax, al"); }
            else { emit("    cmp rax, rbx"); emit("    setle al"); emit("    movzx rax, al"); }
            break;
        case 2:
            if (target_bios) { emit("    cmp ax, bx"); emit("    setge al"); emit("    movzx ax, al"); }
            else { emit("    cmp rax, rbx"); emit("    setge al"); emit("    movzx rax, al"); }
            break;
        case 3:
            if (target_bios) { emit("    cmp ax, bx"); emit("    sete al"); emit("    movzx ax, al"); }
            else { emit("    cmp rax, rbx"); emit("    sete al"); emit("    movzx rax, al"); }
            break;
        case 4:
            if (target_bios) { emit("    cmp ax, bx"); emit("    setne al"); emit("    movzx ax, al"); }
            else { emit("    cmp rax, rbx"); emit("    setne al"); emit("    movzx rax, al"); }
            break;
        case '<':
            if (target_bios) { emit("    cmp ax, bx"); emit("    setl al"); emit("    movzx ax, al"); }
            else { emit("    cmp rax, rbx"); emit("    setl al"); emit("    movzx rax, al"); }
            break;
        case '>':
            if (target_bios) { emit("    cmp ax, bx"); emit("    setg al"); emit("    movzx ax, al"); }
            else { emit("    cmp rax, rbx"); emit("    setg al"); emit("    movzx rax, al"); }
            break;
        default:
            fatal("bad binary operator");
        }
        return;
    }
    case NK_CALL: {

        Node *args[64];
        int nargs = 0;
        for (Node *a = n->args; a && nargs < 64; a = a->next)
            args[nargs++] = a;
        for (int i = nargs - 1; i >= 0; i--) {
            gen_expr(args[i]);
            push_rax();
        }
        const char *name = n->a->name;
        emit("    call %s", func_label(name));
        if (nargs) {
            if (target_bios) emit("    add sp, %d", nargs * 2);
            else emit("    add rsp, %d", nargs * 8);
        }
        return;
    }
    default:
        fatal("bad expression");
    }
}

static int break_labels[64], cont_labels[64];
static int loop_depth;

static void gen_stmt(Stmt *s);

static void gen_block(Stmt *s) {
    for (Stmt *p = s->body; p; p = p->next) gen_stmt(p);
}

static void gen_stmt(Stmt *s) {
    if (!s) return;
    switch (s->kind) {
    case SK_BLOCK:
        gen_block(s);
        return;
    case SK_EXPR:
        gen_expr(s->e1);
        return;
    case SK_DECL: {
        Var *v = s->sym;
        if (!s->e1) return;
        if (v->is_global) {
            if (target_bios) emit("    mov ax, g_%s", v->name);
            else emit("    lea rax, [rel g_%s]", v->name);
        } else {
            if (target_bios) emit("    lea ax, [bp-%d]", v->offset);
            else emit("    lea rax, [rbp-%d]", v->offset);
        }
        push_rax();
        gen_expr(s->e1);
        if (target_bios) emit("    pop bx");
        else emit("    pop rbx");
        gen_store(v->type);
        return;
    }
    case SK_IF: {
        int le = new_label(), lend = new_label();
        gen_expr(s->e1);
        if (target_bios) emit("    test ax, ax");
        else emit("    test rax, rax");
        emit("    jz .L%d", le);
        gen_stmt(s->body);
        emit("    jmp .L%d", lend);
        emit(".L%d:", le);
        if (s->els) gen_stmt(s->els);
        emit(".L%d:", lend);
        return;
    }
    case SK_WHILE: {
        int ls = new_label(), le = new_label();
        emit(".L%d:", ls);
        gen_expr(s->e1);
        if (target_bios) emit("    test ax, ax");
        else emit("    test rax, rax");
        emit("    jz .L%d", le);
        break_labels[loop_depth] = le;
        cont_labels[loop_depth] = ls;
        loop_depth++;
        gen_stmt(s->body);
        loop_depth--;
        emit("    jmp .L%d", ls);
        emit(".L%d:", le);
        return;
    }
    case SK_FOR: {
        int ls = new_label(), lc = new_label(), le = new_label();
        gen_stmt(s->body);
        emit(".L%d:", ls);
        if (s->e1) {
            gen_expr(s->e1);
            if (target_bios) emit("    test ax, ax");
            else emit("    test rax, rax");
            emit("    jz .L%d", le);
        }
        break_labels[loop_depth] = le;
        cont_labels[loop_depth] = lc;
        loop_depth++;
        gen_stmt(s->els);
        loop_depth--;
        emit(".L%d:", lc);
        if (s->e2) gen_expr(s->e2);
        emit("    jmp .L%d", ls);
        emit(".L%d:", le);
        return;
    }
    case SK_RETURN:
        if (s->e1) gen_expr(s->e1);
        else {
            if (target_bios) emit("    xor ax, ax");
            else emit("    xor rax, rax");
        }
        emit("    jmp %s", cur_ret_label);
        return;
    case SK_BREAK:
        if (!loop_depth) fatal("break outside loop");
        emit("    jmp .L%d", break_labels[loop_depth - 1]);
        return;
    case SK_CONTINUE:
        if (!loop_depth) fatal("continue outside loop");
        emit("    jmp .L%d", cont_labels[loop_depth - 1]);
        return;
    default:
        fatal("bad statement");
    }
}

static void emit_function(Func *f) {
    if (!f->body) return;
    char retlab[300];
    snprintf(retlab, sizeof(retlab), ".Lret_%s", f->name);
    cur_ret_label = retlab;
    loop_depth = 0;
    emit("");
    emit("u_%s:", f->name);
    if (target_bios) {
        emit("    push bp");
        emit("    mov bp, sp");
        if (f->frame) emit("    sub sp, %d", f->frame);
    } else {
        emit("    push rbp");
        emit("    mov rbp, rsp");
        if (f->frame) emit("    sub rsp, %d", f->frame);
    }
    gen_stmt(f->body);
    emit("%s:", retlab);
    if (target_bios) {
        emit("    mov sp, bp");
        emit("    pop bp");
        emit("    ret");
    } else {
        emit("    mov rsp, rbp");
        emit("    pop rbp");
        emit("    ret");
    }
}

static void emit_data(void) {
    emit("");
    emit("section .data");
    for (Var *v = globals; v; v = v->next) {
        emit("g_%s:", v->name);
        Type *t = v->type;
        if (t->kind == TY_ARRAY) {
            int elem = type_size(t->base);
            int len = t->len;
            if (v->init_list) {
                Node *e = v->init_list;
                for (int i = 0; i < len; i++) {
                    long val = 0;
                    if (e) {
                        if (e->kind == NK_NUM) val = e->val;
                        else if (e->kind == NK_STR) val = e->val;
                        e = e->next;
                    }
                    if (elem == 1) emit("    db %ld", val);
                    else emit("    %s %ld", target_bios ? "dw" : "dq", val);
                }
            } else {
                emit("    times %d db 0", len * elem);
            }
        } else if (t->kind == TY_PTR && v->init && v->init->kind == NK_STR) {

            if (target_bios) emit("    dw 0");
            else emit("    dq 0");
        } else if (t->kind == TY_CHAR) {
            long val = (v->init && v->init->kind == NK_NUM) ? v->init->val : 0;
            emit("    db %ld", val);
        } else {
            long val = 0;
            if (v->init && v->init->kind == NK_NUM) val = v->init->val;
            else if (v->init && v->init->kind == NK_UN && v->init->a->kind == NK_NUM)
                val = -v->init->a->val;
            if (target_bios) emit("    dw %ld", val);
            else emit("    dq %ld", val);
        }
    }
    for (int i = 0; i < str_count; i++) {
        emit("s_%d:", i);
        const unsigned char *p = (const unsigned char *)strs[i]->name;
        fprintf(out, "    db ");
        for (int j = 0; p[j]; j++) {
            if (j) fprintf(out, ",");
            fprintf(out, "0x%02x", p[j]);
        }
        if (!p[0]) fprintf(out, "0");
        fprintf(out, ",0\n");
    }
}

static void emit_global_inits(void) {
    for (Var *v = globals; v; v = v->next) {
        if (v->type->kind == TY_PTR && v->init && v->init->kind == NK_STR) {
            if (target_bios) {
                emit("    mov ax, s_%ld", v->init->val);
                emit("    mov [g_%s], ax", v->name);
            } else {
                emit("    lea rax, [rel s_%ld]", v->init->val);
                emit("    mov [rel g_%s], rax", v->name);
            }
        }
    }
}

static void emit_program(void) {
    emit("; generated by acc");
    emit("bits %d", target_bios ? 16 : 64);
    if (!target_bios) emit("default rel");
    emit("section .text");
    emit("");
    emit("cmd_main:");
    if (target_bios) {
        emit_global_inits();
        emit("    call u_main");
        emit("    ret");
    } else {
        emit("    push rbp");
        emit("    mov rbp, rsp");
        emit_global_inits();
        emit("    call u_main");
        emit("    mov rsp, rbp");
        emit("    pop rbp");
        emit("    ret");
    }
    for (Func *f = funcs; f; f = f->next) emit_function(f);
    emit_data();
}

static char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "acc: cannot open %s\n", path);
        exit(1);
    }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = malloc(n + 1);
    if (fread(buf, 1, n, f) != (size_t)n) {
        fprintf(stderr, "acc: read error %s\n", path);
        exit(1);
    }
    buf[n] = 0;
    fclose(f);
    return buf;
}

static void append_stripped(FILE *dst, const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "acc: cannot open runtime %s\n", path);
        exit(1);
    }
    char line[4096];
    while (fgets(line, sizeof(line), f)) {
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (!strncmp(p, "global", 6) && (p[6] == ' ' || p[6] == '\t')) continue;
        if (!strncmp(p, "extern", 6) && (p[6] == ' ' || p[6] == '\t')) continue;
        fputs(line, dst);
    }
    fclose(f);
}

int main(int argc, char **argv) {
    const char *input = NULL, *output = NULL;
    int target = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-t") && i + 1 < argc) {
            i++;
            if (!strcmp(argv[i], "bios")) target = 1;
            else if (!strcmp(argv[i], "uefi")) target = 0;
            else fatal("bad target");
        } else if (!strcmp(argv[i], "-o") && i + 1 < argc) {
            output = argv[++i];
        } else if (argv[i][0] == '-') {
            fatal("bad option");
        } else {
            input = argv[i];
        }
    }
    if (!input || !output) {
        fprintf(stderr, "usage: acc [-t uefi|bios] input.c -o output.bin\n");
        return 1;
    }
    target_bios = target;
    word_size = target_bios ? 2 : 8;
    ty_int = mktype(TY_INT, NULL, 0);
    ty_char = mktype(TY_CHAR, NULL, 0);
    ty_void = mktype(TY_VOID, NULL, 0);

    char *text = read_file(input);
    tokenize(text);

    while (cur()->kind != TK_EOF) {
        if (is_type_start()) parse_decl(1);
        else {
            fprintf(stderr, "acc: line %d: declaration expected near '%s'\n",
                    line_no, cur()->text ? cur()->text : "<eof>");
            return 1;
        }
    }
    if (!find_func("main")) fatal("no main()");

    char tmp[512], all[512];
    snprintf(tmp, sizeof(tmp), "/tmp/acc_%d.asm", (int)getpid());
    snprintf(all, sizeof(all), "/tmp/acc_%d_all.asm", (int)getpid());
    out = fopen(tmp, "w");
    if (!out) fatal("cannot create temp file");
    emit_program();
    fclose(out);

    FILE *dst = fopen(all, "w");
    if (!dst) fatal("cannot create combined file");
    if (target_bios) {
        append_stripped(dst, "bios/prog.inc");
        append_stripped(dst, "cmd/bios/cmd_strings.inc");
        append_stripped(dst, "bios/lib.asm");
        append_stripped(dst, "alibc/bios.asm");
    } else {
        append_stripped(dst, "uefi/bin_runtime_flat.asm");
        append_stripped(dst, "uefi/lib.asm");
        append_stripped(dst, "uefi/fs.asm");
        append_stripped(dst, "alibc/uefi.asm");
    }
    append_stripped(dst, tmp);
    fclose(dst);

    char cmd[2048];
    if (target_bios)
        snprintf(cmd, sizeof(cmd), "nasm -f bin -Wno-other -i. '%s' -o '%s'", all, output);
    else
        snprintf(cmd, sizeof(cmd), "nasm -f bin -Wno-other -i. -iuefi -DCMD=cmd_main '%s' -o '%s'", all, output);
    int rc = system(cmd);
    unlink(tmp);
    unlink(all);
    if (rc != 0) {
        fprintf(stderr, "acc: assembler failed\n");
        return 1;
    }
    return 0;
}

#include "acc_os.h"

#define ST_CONIN 48
#define ST_CONOUT 64
#define ST_RUNTIME 88
#define ST_BOOTSERVICES 96
#define BS_HANDLEPROTOCOL 152

unsigned short cwd_w[260];
unsigned char root_mode;
void *image_handle;
void *sys_table;
void *conout;
void *conin;
void *rt;
void *bs;
void *argp;

static unsigned short args_w[512];
static char argbuf[1024];
static char *argv[16];

static void set_default_cwd(void) {
    const unsigned short d[] = { '\\', 'h', 'o', 'm', 'e', 0 };
    int i = 0;
    while (d[i] && i < 259) {
        cwd_w[i] = d[i];
        i++;
    }
    cwd_w[i] = 0;
}

static int parse_load_options(unsigned short *opt, unsigned int size) {
    if (!opt || size == 0) {
        set_default_cwd();
        root_mode = 0;
        argp = args_w;
        args_w[0] = 0;
        return 0;
    }
    int i = 0;
    int n = 0;
    while (opt[i] && opt[i] != '\n' && n < 259) cwd_w[n++] = opt[i++];
    cwd_w[n] = 0;
    if (n == 0) set_default_cwd();
    if (opt[i] == '\n') i++;
    root_mode = (opt[i] == '1') ? 1 : 0;
    while (opt[i] && opt[i] != '\n') i++;
    if (opt[i] == '\n') i++;
    n = 0;
    while (opt[i] && n < 511) args_w[n++] = opt[i++];
    args_w[n] = 0;
    argp = args_w;
    n = 0;
    int a = 0;
    int off = 0;
    argv[a++] = "acc";
    while (args_w[n]) {
        while (args_w[n] == ' ' || args_w[n] == '\t') n++;
        if (!args_w[n]) break;
        int start = off;
        int k = 0;
        while (args_w[n] && args_w[n] != ' ' && args_w[n] != '\t' && k < 255 && off < 1023) {
            argbuf[off++] = (char)(args_w[n] & 0xff);
            k++;
            n++;
        }
        argbuf[off++] = 0;
        if (a < 15) {
            argv[a] = argbuf + start;
            a++;
        }
    }
    return a;
}

unsigned long long efi_main(void *image, void *st) {
    image_handle = image;
    sys_table = st;
    conout = *(void **)((char *)st + ST_CONOUT);
    conin = *(void **)((char *)st + ST_CONIN);
    rt = *(void **)((char *)st + ST_RUNTIME);
    bs = *(void **)((char *)st + ST_BOOTSERVICES);
    fs_device = 0;

    typedef unsigned long long (*handle_protocol_fn)(void *, void *, void **);
    handle_protocol_fn hp = *(handle_protocol_fn *)((char *)bs + BS_HANDLEPROTOCOL);
    void *li = 0;
    unsigned long long status = hp(image, guid_loaded, &li);
    unsigned int size = 0;
    unsigned short *opt = 0;
    if (status == 0 && li) {
        size = *(unsigned int *)((char *)li + 48);
        opt = *(unsigned short **)((char *)li + 56);
        void *dev = *(void **)((char *)li + 24);
        if (!dev) {
            void *parent = *(void **)((char *)li + 8);
            if (parent) {
                void *pli = 0;
                if (hp(parent, guid_loaded, &pli) == 0 && pli)
                    dev = *(void **)((char *)pli + 24);
            }
        }
        fs_device = dev;
    }
    int argc = parse_load_options(opt, size);
    return (unsigned long long)acc_main(argc, argv);
}

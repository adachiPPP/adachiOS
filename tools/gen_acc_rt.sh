#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
mkdir -p "$BUILD"

strip_globals() {
    sed -E '/^[[:space:]]*(global|extern)[[:space:]]/d'
}

{
    strip_globals < "$ROOT/uefi/bin_runtime_flat.asm"
    strip_globals < "$ROOT/uefi/lib.asm"
    strip_globals < "$ROOT/uefi/fs.asm"
    printf '\nsection .text\ncmd_main:\n    ret\n'
    strip_globals < "$ROOT/alibc/uefi.asm"
} > "$BUILD/accrt.asm"

nasm -f bin -Wno-other -i"$ROOT" -i"$ROOT/uefi" -DCMD=cmd_main -l "$BUILD/accrt.lst" -o "$BUILD/ACCRT.BIN" "$BUILD/accrt.asm"

filesize=$(wc -c < "$BUILD/ACCRT.BIN")

awk -v filesize="$filesize" '
BEGIN {
    n = 0
}
{
    lines[++n] = $0
}
END {
    syms["c_putchar"] = ""
    syms["c_puts"] = ""
    syms["c_print_int"] = ""
    syms["c_printf"] = ""
    syms["c_strlen"] = ""
    syms["c_strcmp"] = ""
    syms["c_strcpy"] = ""
    syms["c_memcpy"] = ""
    syms["c_memset"] = ""
    syms["c_atoi"] = ""
    syms["c_malloc"] = ""
    syms["c_free"] = ""
    syms["c_exit"] = ""
    for (i=1; i<=n; i++) {
        for (name in syms) {
            if (syms[name] == "" && lines[i] ~ (name ":$")) {
                for (j=i+1; j<=i+8 && j<=n; j++) {
                    if (match(lines[j], /^[[:space:]]*[0-9]+[[:space:]]+([0-9A-Fa-f]{8})/, m)) {
                        syms[name] = strtonum("0x" m[1]); break
                    }
                }
            }
        }
        if (cmd_main == 0 && lines[i] ~ /cmd_main:$/) {
            for (j=i+1; j<=i+8 && j<=n; j++) {
                if (match(lines[j], /^[[:space:]]*[0-9]+[[:space:]]+([0-9A-Fa-f]{8})/, m)) {
                    cmd_main = strtonum("0x" m[1]); break
                }
            }
        }
        if (call_off == 0 && lines[i] ~ /call[[:space:]]+CMD/) {
            if (match(lines[i], /^[[:space:]]*[0-9]+[[:space:]]+([0-9A-Fa-f]{8})[[:space:]]+E/, m)) {
                call_off = strtonum("0x" m[1])
            }
        }
        if (heap_idx == 0 && lines[i] ~ /lea[[:space:]]+rax,[[:space:]]*\[heap\]/) {
            if (match(lines[i], /^[[:space:]]*[0-9]+[[:space:]]+([0-9A-Fa-f]{8})[[:space:]]+488D05\(([0-9A-Fa-f]{8})\)/, m)) {
                heap_addr = strtonum("0x" m[1])
                disp = strtonum("0x" substr(m[2],7,2) substr(m[2],5,2) substr(m[2],3,2) substr(m[2],1,2))
                heap_target = heap_addr + 7 + disp
                heap_idx = i
            }
        }
    }
    mem_size = int((heap_target + 0x10000 + 15) / 16) * 16

    print "#ifndef ACC_RT_H"
    print "#define ACC_RT_H"
    print ""
    printf "#define RT_FILE_SIZE %d\n", filesize
    printf "#define RT_MEM_SIZE %d\n", mem_size
    printf "#define RT_CMD_CALL_OFF %d\n", call_off
    printf "#define RT_CMD_MAIN_OFF %d\n", cmd_main
    for (name in syms) {
        if (syms[name] == "") { print "missing " name > "/dev/stderr"; exit 1 }
        printf "#define SYM_%s %d\n", name, syms[name]
    }
    print ""
    print "#endif"
}
' "$BUILD/accrt.lst" > "$ROOT/acc/acc_rt.h"

echo "ACCRT.BIN $(wc -c < "$BUILD/ACCRT.BIN") bytes"
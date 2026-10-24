#!/usr/bin/env python3
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")


def read(path):
    with open(os.path.join(ROOT, path), "r") as f:
        return f.read()


def strip_globals(text):
    out = []
    for line in text.splitlines():
        s = line.lstrip()
        if s.startswith("global ") or s.startswith("extern "):
            continue
        out.append(line)
    return "\n".join(out) + "\n"


def main():
    os.makedirs(BUILD, exist_ok=True)
    parts = []
    parts.append(read("uefi/bin_runtime_flat.asm"))
    parts.append(strip_globals(read("uefi/lib.asm")))
    parts.append(strip_globals(read("uefi/fs.asm")))
    parts.append("\nsection .text\ncmd_main:\n    ret\n")
    parts.append(strip_globals(read("alibc/uefi.asm")))
    asm_path = os.path.join(BUILD, "accrt.asm")
    lst_path = os.path.join(BUILD, "accrt.lst")
    bin_path = os.path.join(BUILD, "ACCRT.BIN")
    with open(asm_path, "w") as f:
        f.write("\n".join(parts))

    subprocess.check_call([
        "nasm", "-f", "bin", "-i.", "-iuefi", "-DCMD=cmd_main",
        "-l", lst_path, "-o", bin_path, asm_path
    ], cwd=ROOT)

    lines = open(lst_path, "r").read().splitlines()

    def symbol_addr(name):
        for i, line in enumerate(lines):
            if line.rstrip().endswith(name + ":"):
                for j in range(i + 1, min(i + 8, len(lines))):
                    m = re.match(r"^\s*\d+\s+([0-9A-Fa-f]{8})\s", lines[j])
                    if m:
                        return int(m.group(1), 16)
        return None

    syms = {}
    for name in [
        "c_putchar", "c_puts", "c_print_int", "c_printf", "c_strlen",
        "c_strcmp", "c_strcpy", "c_memcpy", "c_memset", "c_atoi",
        "c_malloc", "c_free", "c_exit",
    ]:
        a = symbol_addr(name)
        if a is None:
            raise SystemExit("missing symbol " + name)
        syms[name] = a

    cmd_main = symbol_addr("cmd_main")
    if cmd_main is None:
        raise SystemExit("missing cmd_main")

    call_off = None
    heap_target = None
    for line in lines:
        if "call CMD" in line:
            m = re.match(r"^\s*\d+\s+([0-9A-Fa-f]{8})\s+E8", line)
            if m:
                call_off = int(m.group(1), 16)
        if "lea rax, [heap]" in line:
            m = re.match(r"^\s*\d+\s+([0-9A-Fa-f]{8})\s+488D05\(([0-9A-Fa-f]{8})\)", line)
            if m:
                addr = int(m.group(1), 16)
                disp = int.from_bytes(bytes.fromhex(m.group(2)), "little")
                heap_target = addr + 7 + disp

    if call_off is None or heap_target is None:
        raise SystemExit("missing call/heap")

    mem_size = (heap_target + 0x10000 + 15) & ~15
    file_size = os.path.getsize(bin_path)

    hdr = []
    hdr.append("#ifndef ACC_RT_H")
    hdr.append("#define ACC_RT_H")
    hdr.append("")
    hdr.append("#define RT_FILE_SIZE %d" % file_size)
    hdr.append("#define RT_MEM_SIZE %d" % mem_size)
    hdr.append("#define RT_CMD_CALL_OFF %d" % call_off)
    hdr.append("#define RT_CMD_MAIN_OFF %d" % cmd_main)
    for name, a in syms.items():
        hdr.append("#define SYM_%s %d" % (name, a))
    hdr.append("")
    hdr.append("#endif")
    hdr.append("")
    with open(os.path.join(ROOT, "acc/acc_rt.h"), "w") as f:
        f.write("\n".join(hdr))

    print("ACCRT.BIN %d bytes, mem %d, call %d, heap %d" %
          (file_size, mem_size, call_off, heap_target))


if __name__ == "__main__":
    main()

#!/bin/sh
set -eu

cd "$(dirname "$0")"

usage() {
    printf 'usage: %s [uefi|bios|both]\n' "$0" >&2
    exit 1
}

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'error: %s is not installed\n' "$1" >&2
        exit 1
    fi
}

build_acc() {
    need cc
    cc -O2 -o acc/acc acc/acc.c
}

build_c_programs() {
    target=$1
    for src in acc/examples/*.c; do
        [ -e "$src" ] || continue
        name=$(basename "$src" .c)
        out=$(printf '%s' "$name" | tr 'a-z' 'A-Z')
        ./acc/acc -t "$target" "$src" -o "build/bin/$out.BIN"
    done
}

build_acc_os() {
    need python3
    need clang
    need nasm

    linker=$1
    shift

    python3 tools/gen_acc_rt.py
    mkdir -p build/acc
    for f in acc/acc_os.c acc/acc_asm.c acc/acc_libc.c acc/acc_entry.c; do
        clang --target=x86_64-unknown-windows-msvc -ffreestanding -fno-builtin \
            -fno-stack-protector -O2 -Iacc -c "$f" \
            -o "build/acc/$(basename "$f" .c).obj"
    done
    nasm -f win64 acc/acc_chkstk.asm -o build/acc/acc_chkstk.obj
    nasm -f win64 acc/acc_glue.asm -o build/acc/acc_glue.obj
    nasm -f win64 -iuefi uefi/lib.asm -o build/acc/lib.obj
    nasm -f win64 -iuefi uefi/fs.asm -o build/acc/fs.obj
    "$linker" "$@" /subsystem:efi_application /entry:efi_main /nodefaultlib \
        /out:build/bin/ACC.BIN \
        build/acc/acc_os.obj build/acc/acc_asm.obj build/acc/acc_libc.obj \
        build/acc/acc_entry.obj build/acc/acc_chkstk.obj build/acc/acc_glue.obj \
        build/acc/lib.obj build/acc/fs.obj
}

uefi_build() {
    need nasm
    need mkfs.fat
    need mmd
    need mcopy

    if command -v lld-link >/dev/null 2>&1; then
        set -- lld-link
    elif command -v lld >/dev/null 2>&1; then
        set -- lld -flavor link
    else
        printf 'error: lld-link (or lld) is not installed\n' >&2
        exit 1
    fi

    mkdir -p build
    rm -rf build/bin
    mkdir -p build/bin

    nasm -f win64 -iuefi uefi/kernel.asm -o build/kernel.obj
    nasm -f win64 -iuefi uefi/lib.asm -o build/lib.obj
    nasm -f win64 -iuefi uefi/fs.asm -o build/fs.obj

    "$@" /subsystem:efi_application /entry:efi_main /nodefaultlib \
        /out:BOOTX64.EFI \
        build/kernel.obj build/lib.obj build/fs.obj

    mkdir -p build/bin

    for spec in \
        HELP:cmd/uefi/cmd_help:cmd_help \
        ECHO:cmd/uefi/cmd_echo:cmd_echo \
        CLEAR:cmd/uefi/cmd_clear:cmd_clear \
        FETCH:cmd/uefi/cmd_fetch:cmd_fetch \
        PWD:cmd/uefi/cmd_pwd:cmd_pwd \
        CD:cmd/uefi/cmd_cd:cmd_cd \
        LS:cmd/uefi/cmd_ls:cmd_ls \
        CAT:cmd/uefi/cmd_cat:cmd_cat \
        VI:cmd/uefi/vi:cmd_vi \
        TOUCH:cmd/uefi/cmd_touch:cmd_touch \
        MKDIR:cmd/uefi/cmd_mkdir:cmd_mkdir \
        RM:cmd/uefi/cmd_rm:cmd_rm \
        CP:cmd/uefi/cmd_cp:cmd_cp \
        MV:cmd/uefi/cmd_mv:cmd_mv \
        UNAME:cmd/uefi/cmd_uname:cmd_uname \
        MEOW:cmd/uefi/cmd_meow:cmd_meow \
        TRUE:cmd/uefi/cmd_true:cmd_true \
        FALSE:cmd/uefi/cmd_false:cmd_false \
        FACTOR:cmd/uefi/cmd_factor:cmd_factor \
        REV:cmd/uefi/cmd_rev:cmd_rev \
        WHOAMI:cmd/uefi/cmd_whoami:cmd_whoami \
        HOSTNAME:cmd/uefi/cmd_hostname:cmd_hostname \
        YES:cmd/uefi/cmd_yes:cmd_yes \
        SEQ:cmd/uefi/cmd_seq:cmd_seq \
        SLEEP:cmd/uefi/cmd_sleep:cmd_sleep \
        FLAPPY:cmd/uefi/flappy:cmd_flappy \
        REBOOT:cmd/uefi/cmd_reboot:cmd_reboot \
        POWEROFF:cmd/uefi/cmd_poweroff:cmd_poweroff
    do
        out=${spec%%:*}
        rest=${spec#*:}
        src=${rest%%:*}
        sym=${rest##*:}
        {
            cat uefi/bin_runtime_flat.asm
            sed -E '/^[[:space:]]*(global|extern)[[:space:]]/d' uefi/lib.asm uefi/fs.asm "$src.asm"
        } > "build/flat_$out.asm"
        nasm -f bin -i. -iuefi -DCMD="$sym" "build/flat_$out.asm" -o "build/bin/$out.BIN"
    done

    build_acc_os "$@"
    build_c_programs uefi

    mkdir -p assets
    [ -f assets/HELLO.TXT ] || printf 'hi from the boot partition\n' > assets/HELLO.TXT

    rm -f adachiOS.img
    mkfs.fat -C adachiOS.img 16384
    mmd -i adachiOS.img ::/EFI ::/EFI/BOOT ::/home ::/bin ::/lib
    mcopy -i adachiOS.img BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i adachiOS.img build/bin/*.BIN ::/bin/
    mcopy -i adachiOS.img build/ACCRT.BIN ::/lib/ACCRT.BIN
    mcopy -i adachiOS.img acc/examples/*.c ::/home/
    mcopy -i adachiOS.img assets/HELLO.TXT ::/

    printf 'built adachiOS.img (uefi)\n'
}

bios_build() {
    need nasm
    need mkfs.fat
    need mcopy
    need dd

    mkdir -p build
    rm -rf build/bin
    mkdir -p build/bin

    nasm -f bin -i. bios/boot.asm -o build/boot.bin
    nasm -f bin -i. bios/kernel.asm -o build/KERNEL.BIN

    for src in cmd/bios/cmd_*.asm; do
        name=$(basename "$src" .asm)
        name=${name#cmd_}
        out=$(printf '%s' "$name" | tr 'a-z' 'A-Z')
        nasm -f bin -i. "$src" -o "build/bin/$out.BIN"
    done

    build_c_programs bios

    boot_size=$(wc -c < build/boot.bin)
    if [ "$boot_size" -ne 450 ]; then
        printf 'error: boot.bin is %s bytes, expected 450\n' "$boot_size" >&2
        exit 1
    fi
    kernel_size=$(wc -c < build/KERNEL.BIN)
    if [ "$kernel_size" -gt 32768 ]; then
        printf 'error: KERNEL.BIN is %s bytes, the loader caps it at 32768\n' "$kernel_size" >&2
        exit 1
    fi

    mkdir -p assets
    [ -f assets/HELLO.TXT ] || printf 'hi from the boot partition\n' > assets/HELLO.TXT

    rm -f adachiOS_bios.img
    mkfs.fat -C -F 12 -f 2 -s 1 -r 224 -S 512 adachiOS_bios.img 1440
    mcopy -i adachiOS_bios.img build/KERNEL.BIN ::/KERNEL.BIN
    mcopy -i adachiOS_bios.img assets/HELLO.TXT ::/HELLO.TXT
    mmd -i adachiOS_bios.img ::/home ::/bin
    mcopy -i adachiOS_bios.img build/bin/*.BIN ::/bin/
    dd if=build/boot.bin of=adachiOS_bios.img bs=1 seek=62 conv=notrunc status=none

    printf 'built adachiOS_bios.img (bios)\n'
}

target="${1:-}"
if [ -z "$target" ]; then
    printf 'build for [uefi/bios/both] (uefi): '
    read -r target || true
    [ -n "$target" ] || target=uefi
fi

build_acc

case "$target" in
    u|uefi) uefi_build ;;
    b|bios) bios_build ;;
    both) uefi_build; bios_build ;;
    *) usage ;;
esac

rm -rf build

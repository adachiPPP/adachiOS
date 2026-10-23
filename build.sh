#!/bin/sh
set -eu

cd "$(dirname "$0")"

usage() {
    printf 'usage: %s [uefi|bios]\n' "$0" >&2
    exit 1
}

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'error: %s is not installed\n' "$1" >&2
        exit 1
    fi
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

    for src in adachiOS coreutils flappy vi; do
        nasm -f win64 -i. "$src.asm" -o "build/$src.obj"
    done

    # this KILLED me
    "$@" /subsystem:efi_application /entry:efi_main /nodefaultlib \
        /out:BOOTX64.EFI \
        build/adachiOS.obj build/coreutils.obj build/flappy.obj build/vi.obj

    [ -f HELLO.TXT ] || printf 'hi from the boot partition\n' > HELLO.TXT

    rm -f adachiOS.img
    mkfs.fat -C adachiOS.img 16384
    mmd -i adachiOS.img ::/EFI ::/EFI/BOOT
    mcopy -i adachiOS.img BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i adachiOS.img HELLO.TXT ::/

    printf 'built adachiOS.img (uefi)\n'
}

bios_build() {
    need nasm
    need mkfs.fat
    need mcopy
    need dd

    mkdir -p build

    nasm -f bin bios/boot.asm -o build/boot.bin
    nasm -f bin bios/kernel.asm -o build/KERNEL.BIN

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

    [ -f HELLO.TXT ] || printf 'hi from the boot partition\n' > HELLO.TXT

    # gfdesbjdbshbhbhj
    rm -f adachiOS_bios.img
    mkfs.fat -C -F 12 -f 2 -s 1 -r 224 -S 512 adachiOS_bios.img 1440
    mcopy -i adachiOS_bios.img build/KERNEL.BIN ::/KERNEL.BIN
    mcopy -i adachiOS_bios.img HELLO.TXT ::/HELLO.TXT
    dd if=build/boot.bin of=adachiOS_bios.img bs=1 seek=62 conv=notrunc status=none

    printf 'built adachiOS_bios.img (bios)\n'
}

target="${1:-}"
if [ -z "$target" ]; then
    printf 'build for [uefi/bios] (uefi): '
    read -r target || true
    [ -n "$target" ] || target=uefi
fi

case "$target" in
    u|uefi) uefi_build ;;
    b|bios) bios_build ;;
    *) usage ;;
esac

rm -rf build

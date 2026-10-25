#!/bin/sh
set -eu

cd "$(dirname "$0")"

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'error: %s is not installed\n' "$1" >&2
        exit 1
    fi
}

build_font() {
    need sh
    sh tools/gen_font.sh
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

build_coreutils() {
    target=$1
    [ "$target" = "uefi" ] || return 0
    [ -d coreutils ] || return 0
    for src in coreutils/*.c; do
        [ -e "$src" ] || continue
        name=$(basename "$src" .c)
        out=$(printf '%s' "$name" | tr 'a-z' 'A-Z')
        ./acc/acc -t "$target" "$src" -o "build/bin/CORE_$out.BIN"
    done
}

build_extras() {
    [ -d extras ] || return 0
    for src in extras/*.c; do
        [ -e "$src" ] || continue
        name=$(basename "$src" .c)
        out=$(printf '%s' "$name" | tr 'a-z' 'A-Z')
        ./acc/acc -t uefi "$src" -o "build/bin/$out.BIN"
    done
}

build_acc_os() {
    need clang
    need nasm
    linker=$1
    shift
    [ -f build/font_glyphs.bin ] || build_font
    sh tools/gen_acc_rt.sh
    mkdir -p build/acc
    for f in acc/acc_os.c acc/acc_asm.c acc/acc_libc.c acc/acc_entry.c; do
        clang --target=x86_64-unknown-windows-msvc -ffreestanding -fno-builtin \
            -fno-stack-protector -O2 -Iacc -c "$f" \
            -o "build/acc/$(basename "$f" .c).obj"
    done
    nasm -Wno-error=label-redef-late -f win64 -Wno-other acc/acc_chkstk.asm -o build/acc/acc_chkstk.obj
    nasm -Wno-error=label-redef-late -f win64 -Wno-other -iuefi acc/acc_glue.asm -o build/acc/acc_glue.obj
    nasm -Wno-error=label-redef-late -f win64 -Wno-other -iuefi uefi/lib.asm -o build/acc/lib.obj
    nasm -Wno-error=label-redef-late -f win64 -Wno-other -iuefi uefi/fs.asm -o build/acc/fs.obj
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
    build_font
    rm -rf build/bin
    mkdir -p build/bin

    nasm -Wno-error=label-redef-late -f win64 -Wno-other -iuefi uefi/kernel.asm -o build/kernel.obj
    nasm -Wno-error=label-redef-late -f win64 -Wno-other -iuefi uefi/lib.asm -o build/lib.obj
    nasm -Wno-error=label-redef-late -f win64 -Wno-other -iuefi uefi/fs.asm -o build/fs.obj
    "$@" /subsystem:efi_application /entry:efi_main /nodefaultlib \
        /out:BOOTX64.EFI \
        build/kernel.obj build/lib.obj build/fs.obj

    mkdir -p build/bin
    for spec in \
        ECHO:oldutils/uefi/cmd_echo:cmd_echo \
        CLEAR:oldutils/uefi/cmd_clear:cmd_clear \
        FETCH:cmd/uefi/cmd_fetch:cmd_fetch \
        PWD:cmd/uefi/cmd_pwd:cmd_pwd \
        CD:cmd/uefi/cmd_cd:cmd_cd \
        LS:cmd/uefi/cmd_ls:cmd_ls \
        CAT:oldutils/uefi/cmd_cat:cmd_cat \
        VI:cmd/uefi/vi:cmd_vi \
        TOUCH:oldutils/uefi/cmd_touch:cmd_touch \
        MKDIR:cmd/uefi/cmd_mkdir:cmd_mkdir \
        RM:oldutils/uefi/cmd_rm:cmd_rm \
        CP:oldutils/uefi/cmd_cp:cmd_cp \
        MV:oldutils/uefi/cmd_mv:cmd_mv \
        UNAME:oldutils/uefi/cmd_uname:cmd_uname \
        MEOW:oldutils/uefi/cmd_meow:cmd_meow \
        TRUE:oldutils/uefi/cmd_true:cmd_true \
        FALSE:oldutils/uefi/cmd_false:cmd_false \
        FACTOR:oldutils/uefi/cmd_factor:cmd_factor \
        REV:oldutils/uefi/cmd_rev:cmd_rev \
        WHOAMI:oldutils/uefi/cmd_whoami:cmd_whoami \
        HOSTNAME:oldutils/uefi/cmd_hostname:cmd_hostname \
        YES:oldutils/uefi/cmd_yes:cmd_yes \
        SEQ:oldutils/uefi/cmd_seq:cmd_seq \
        SLEEP:oldutils/uefi/cmd_sleep:cmd_sleep \
        ADCTL:cmd/uefi/cmd_adctl:cmd_adctl \
        ADINIT:cmd/uefi/cmd_adinit:cmd_adinit \
        FLAPPY:cmd/uefi/flappy:cmd_flappy \
        HELP:cmd/uefi/cmd_help:cmd_help
    do
        out=${spec%%:*}
        rest=${spec#*:}
        src=${rest%%:*}
        sym=${rest##*:}
        {
            cat uefi/bin_runtime_flat.asm
            sed -E '/^[[:space:]]*(global|extern)[[:space:]]/d' uefi/lib.asm uefi/fs.asm "$src.asm"
        } > "build/flat_$out.asm"
        nasm -f bin -Wno-other -Wno-error=label-redef-late -Wno-label-redef-late -i. -iuefi -DCMD="$sym" "build/flat_$out.asm" -o "build/bin/$out.BIN"
    done

    build_acc_os "$@"
    build_c_programs uefi
    build_coreutils uefi
    build_extras

    mkdir -p assets
    [ -f assets/HELLO.TXT ] || printf 'hi from the boot partition\n' > assets/HELLO.TXT
    [ -f assets/MOTD.TXT ] || printf 'welcome to adachiOS 0.6 :3\r\n' > assets/MOTD.TXT

    rm -f adachiOS.img
    mkfs.fat -C adachiOS.img 16384
    mmd -i adachiOS.img ::/EFI ::/EFI/BOOT ::/home ::/bin ::/lib ::/etc ::/adinit ::/adinit/services
    mcopy -i adachiOS.img BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
    mcopy -i adachiOS.img build/bin/*.BIN ::/bin/
    mcopy -i adachiOS.img build/ACCRT.BIN ::/lib/ACCRT.BIN
    mcopy -i adachiOS.img acc/examples/*.c ::/home/
    mcopy -i adachiOS.img assets/HELLO.TXT ::/
    mcopy -i adachiOS.img assets/MOTD.TXT ::/etc/motd

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

    nasm -Wno-error=label-redef-late -f bin -Wno-other -i. bios/boot.asm -o build/boot.bin
    nasm -Wno-error=label-redef-late -f bin -Wno-other -i. bios/kernel.asm -o build/KERNEL.BIN
    for src in oldutils/bios/cmd_*.asm cmd/bios/cmd_*.asm; do
        [ -e "$src" ] || continue
        name=$(basename "$src" .asm)
        name=${name#cmd_}
        out=$(printf '%s' "$name" | tr 'a-z' 'A-Z')
        nasm -Wno-error=label-redef-late -f bin -Wno-other -i. "$src" -o "build/bin/$out.BIN"
    done

    build_c_programs bios

    mkdir -p assets
    [ -f assets/HELLO.TXT ] || printf 'hi from the boot partition\n' > assets/HELLO.TXT
    [ -f assets/MOTD.TXT ] || printf 'welcome to adachiOS 0.6 :3\r\n' > assets/MOTD.TXT
    rm -f adachiOS_bios.img
    mkfs.fat -C -F 12 -f 2 -s 1 -r 224 -S 512 adachiOS_bios.img 1440
    mcopy -i adachiOS_bios.img build/KERNEL.BIN ::/KERNEL.BIN
    mcopy -i adachiOS_bios.img assets/HELLO.TXT ::/HELLO.TXT
    mmd -i adachiOS_bios.img ::/home ::/bin
    mcopy -i adachiOS_bios.img build/bin/*.BIN ::/bin/

    printf 'built adachiOS_bios.img (bios)\n'
}

build_acc
target="${1:-}"
if [ -z "$target" ]; then
    printf 'build for [uefi/bios/both] (uefi): '
    read -r target || true
    [ -n "$target" ] || target=uefi
fi

case "$target" in
    u|uefi) uefi_build ;;
    b|bios) bios_build ;;
    both) uefi_build; bios_build ;;
    *) usage ;;
esac

rm -rf build
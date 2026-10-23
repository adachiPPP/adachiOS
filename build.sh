#!/bin/sh
set -e
cd "$(dirname "$0")"

nasm -f win64 -i. adachiOS.asm -o adachiOS.obj
nasm -f win64 -i. coreutils.asm -o coreutils.obj
nasm -f win64 -i. flappy.asm -o flappy.obj
nasm -f win64 -i. vi.asm -o vi.obj

lld-link /subsystem:efi_application /entry:efi_main /nodefaultlib \
         /out:BOOTX64.EFI adachiOS.obj coreutils.obj flappy.obj vi.obj

printf 'hi from the boot partition\n' > HELLO.TXT

rm -f adachiOS.img
mkfs.fat -C adachiOS.img 16384
mmd   -i adachiOS.img ::/EFI ::/EFI/BOOT
mcopy -i adachiOS.img BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
mcopy -i adachiOS.img HELLO.TXT ::/

echo "built adachiOS.img"

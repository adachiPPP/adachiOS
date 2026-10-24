# adachiOS

a basic tiny OS written in assembly, with a UEFI build and a legacy BIOS build because some ppl apperently still use bios

## build

```
./build.sh          # it will prompt u to choose between uefi or bios
./build.sh uefi     # basically adachiOS.img + BOOTX64.EFI
./build.sh bios     # magic and boom adachiOS_bios.img
```

needs `nasm`, `lld-link` (or `lld`), `mkfs.fat` and mtools (`mmd`, `mcopy`); the
BIOS image also uses `dd` because of obvious reasons.

## uefi

- 16 MB FAT image with `EFI/BOOT/BOOTX64.EFI`, `HELLO.TXT` and `home/`
- shell: `help`, `echo`, `clear`, `fetch`, `pwd`, `cd`, `ls`, `cat`, `touch`,
  `mkdir`, `rm`, `cp`, `mv`, `vi`, `uname`, `meow`, `sudo`, `flappy`,
  `reboot`, `poweroff`, plus command history
- the shell starts in `/home` and paths work (`cd ..`, `ls /`, `cp /HELLO.TXT x`)
- reading is allowed anywhere; anything that writes outside `/home` needs `sudo`
  for that one command (`sudo rm /HELLO.TXT`)
- `fetch` reports firmware, CPU model, core/thread counts and RAM
- `vi` keeps up to 16 KiB in memory

boot it with OVMF, for example:

```
qemu-system-x86_64 -machine q35 -m 512 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.4m.fd \
  -drive format=raw,file=adachiOS.img
```

## bios

- 1.44 MB FAT12 floppy with a 16-bit real-mode boot sector, `KERNEL.BIN` and
  a `home/` directory
- shell: `help`, `echo`, `clear`, `fetch`, `pwd`, `cd`, `ls`, `cat`, `touch`,
  `mkdir`, `rm`, `cp`, `mv`, `vi`, `flappy`, `uname`, `meow`, `sudo`,
  `reboot`, `poweroff`
- the shell starts in `/home`, with real subdirectories and path support; the
  same `/home` rule applies, so writing elsewhere needs `sudo CMD`
- `vi` keeps up to 4 KiB in memory
- `fetch` reports the CPU vendor/model, core counts and total RAM from the
  BIOS memory probes
- `ls`, `cat`, `touch`, `mkdir`, `rm`, `cp`, `mv` and `vi` all operate on the
  real FAT12 floppy, creating and deleting directory entries and clusters

```
qemu-system-x86_64 -fda adachiOS_bios.img
```

`HELLO.TXT` is copied into both images because... i felt like it, and `/home`
is there so the shell has somewhere it is allowed to write

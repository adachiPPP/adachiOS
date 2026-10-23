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

- 16 MB FAT image with `EFI/BOOT/BOOTX64.EFI` and `HELLO.TXT`
- shell: `help`, `echo`, `clear`, `fetch`, `ls`, `cat`, `vi`, `uname`, `meow`,
  `sudo`, `flappy`, `reboot`, `poweroff`, plus command history
- `vi` keeps up to 16 KiB in memory

boot it with OVMF, for example:

```
qemu-system-x86_64 -machine q35 -m 512 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.4m.fd \
  -drive format=raw,file=adachiOS.img
```

## bios

- 1.44 MB FAT12 floppy with a 16-bit real-mode boot sector and `KERNEL.BIN`
- shell: `help`, `echo`, `clear`, `fetch`, `ls`, `cat`, `vi`, `flappy`,
  `uname`, `meow`, `sudo`, `reboot`, `poweroff`
- `vi` keeps up to 4 KiB in memory
- `fetch` reports total RAM from the BIOS memory probes
- `ls` and `cat` read the real FAT12 floppy; `vi` writes back to it

```
qemu-system-x86_64 -fda adachiOS_bios.img
```

`HELLO.TXT` is copied into both images because... i felt like it

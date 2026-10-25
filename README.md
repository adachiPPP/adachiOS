# adachiOS 0.6

a basic tiny OS written in assembly, with a UEFI build and a legacy BIOS build because some ppl apperently still use bios

## layout

```
uefi/        UEFI kernel, runtime and flat-binary entry stub
bios/        BIOS boot sector, kernel and runtime
cmd/uefi/    UEFI /bin commands
cmd/bios/    BIOS /bin commands
alibc/       tiny C library for both targets
acc/         C compiler and its examples
assets/      files copied into the boot images
```

## build

```
./build.sh          # it will prompt u to choose between uefi or bios
./build.sh uefi     # basically adachiOS.img + BOOTX64.EFI
./build.sh bios     # magic and boom adachiOS_bios.img
```

needs `nasm`, `lld-link` (or `lld`), `mkfs.fat` and mtools (`mmd`, `mcopy`); the
BIOS image also uses `dd` because of obvious reasons.  the UEFI build also needs
`clang`, `python3` and an 8x16 console font from the `kbd` package; the host
`acc` itself needs a host C compiler (`cc`).

## userland

the shell is only a shell. every command except `rodo` (a shell built-in) is a
separate program in `/bin` on the boot image:

- uefi: flat position-independent `ADB1` binaries. the shell loads one into a
  pool buffer and calls offset 0 with a context pointer (`fctx`) carrying the
  system table, device handle, cwd, arguments and rodo state. each program
  statically includes the mini-libc (`uefi/lib.asm` and `uefi/fs.asm`), so it
  has no relocations and does not need a loader beyond a flat read.
- bios: flat 16-bit binaries with `bios/lib.asm` statically linked in. the
  kernel loads one at `0x2000:0000`, writes a state block at `0x2000:0xFE00`
  (drive, cwd cluster and path, arguments) and far-calls it. the program
  returns with `retf`.

to add a command, write `cmd/uefi/cmd_foo.asm` or `cmd/bios/cmd_foo.asm` and
add it to the list/loop in `build.sh`.

## c toolchain

`alibc` is the tiny C library in `alibc/` and `acc` is the C compiler in `acc/`.
`acc` is a host bootstrap compiler: it runs on Linux and emits a flat `/bin`
program for either target, using the same runtime layout as the assembly
commands.

```
./acc/acc -t uefi acc/examples/hello.c -o build/bin/HELLO.BIN
./acc/acc -t bios acc/examples/hello.c -o build/bin/HELLO.BIN
```

run `acc` from the repo root; it reads the runtime files by relative path.
`./build.sh` builds `acc/acc` with the host `cc`, then compiles every
`acc/examples/*.c` into `build/bin/<NAME>.BIN` for the target being built, so the
C demos land in `/bin` next to the assembly coreutils:

- `hello` - strings and `printf`
- `fib` - recursion, loops and function calls
- `test` - globals, arrays, `malloc`, `str*` and `putchar`
- `test2` - pointers, `sizeof`, global arrays, `for` declarations and
  `break`/`continue`

the language is a practical C subset: `int`, `char`, `void`, pointers, arrays,
functions with parameters and locals, globals, `if`/`else`, `while`, `for`,
`return`, `break`, `continue`, assignment (`=`, `+=`, `-=`), the usual
arithmetic/comparison/logical operators, casts, `sizeof`, string and character
literals, and numeric `#define`s.  `#include` is accepted and ignored; the
`alibc` prototypes are built in.

not implemented yet: structs, typedefs, enums, `switch`, `do`/`while`, function
pointers, variadic function definitions, and preprocessor conditionals.

### in-OS compiler (UEFI)

the UEFI image also ships `acc` itself as `/bin/ACC.BIN`, a PE32+ EFI
application. it uses the flat runtime in `/lib/ACCRT.BIN`, assembles in memory
and writes a normal `ADB1` program, so the result runs exactly like any other
`/bin` command:

```
acc hello.c -o /home/HELLO.BIN
rodo acc hello.c -o /bin/HELLO.BIN
```

writing outside `/home` still needs `rodo`, hence the second form.  use
`exec /home/HELLO.BIN` (or `exec /bin/HELLO.BIN`) to run the result.  the in-OS
compiler accepts `-t uefi`; `-t bios` is rejected.  the BIOS image has no in-OS
compiler because 16-bit real mode cannot comfortably host one.  use the host
`./acc/acc -t bios ...` to build BIOS programs.

## uefi

- 16 MB FAT image with `EFI/BOOT/BOOTX64.EFI`, `HELLO.TXT`, `home/` and `bin/`
- direct GOP framebuffer console with automatic font scaling, falling back to
  firmware ConOut when GOP is unavailable
- shell: `help`, `echo`, `clear`, `fetch`, `pwd`, `cd`, `ls`, `cat`, `touch`,
  `mkdir`, `rm`, `cp`, `mv`, `vi`, `uname`, `meow`, `whoami`, `hostname`,
  `true`, `false`, `yes`, `seq`, `sleep`, `factor`, `rev`, `rodo`, `exec`,
  `acc`, `adctl`, `adinit`, `flappy`, plus command history
- the shell starts in `/home` and paths work (`cd ..`, `ls /`, `cp /HELLO.TXT x`)
- reading is allowed anywhere; anything that writes outside `/home` needs `rodo`
  for that one command (`rodo rm /HELLO.TXT`)
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

- 1.44 MB FAT12 floppy with a 16-bit real-mode boot sector, `KERNEL.BIN`,
  `home/` and `bin/`
- shell: `help`, `echo`, `clear`, `fetch`, `pwd`, `cd`, `ls`, `cat`, `touch`,
  `mkdir`, `rm`, `cp`, `mv`, `vi`, `flappy`, `uname`, `meow`, `whoami`,
  `hostname`, `true`, `false`, `yes`, `seq`, `sleep`, `factor`, `rev`, `rodo`,
  `reboot`, `poweroff`
- the shell starts in `/home`, with real subdirectories and path support; the
  same `/home` rule applies, so writing elsewhere needs `rodo CMD`
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

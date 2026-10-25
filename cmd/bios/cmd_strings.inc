
s_help      db 'commands:',13,10
            db '  help      show this list',13,10
            db '  echo      echo your words back',13,10
            db '  clear     clear the screen',13,10
            db '  fetch     system, cpu and memory info',13,10
            db '  pwd       print the current directory',13,10
            db '  cd        change directory (cd DIR, cd to go home)',13,10
            db '  ls        list a directory (ls [DIR])',13,10
            db '  cat       print a file (cat FILE)',13,10
            db '  vi        edit a file (vi FILE, needs rodo outside /home)',13,10
            db '  touch     create an empty file (touch FILE)',13,10
            db '  mkdir     create a directory (mkdir DIR)',13,10
            db '  rm        delete a file or empty directory (rm PATH)',13,10
            db '  cp        copy a file (cp SRC DST)',13,10
            db '  mv        move a file (mv SRC DST)',13,10
            db '  flappy    play flappy bird (space/w flap, q quit)',13,10
            db '  uname     kernel info',13,10
            db '  meow      :3',13,10
            db '  true      do nothing',13,10
            db '  false     do nothing',13,10
            db '  factor N  factor a number',13,10
            db '  rev TEXT  reverse text',13,10
            db '  whoami    show user',13,10
            db '  hostname  show host',13,10
            db '  yes       repeat text',13,10
            db '  seq N     print 1..N',13,10
            db '  sleep N   wait seconds',13,10
            db '  rodo      run one command as root (rodo CMD)',13,10
            db '  reboot    reboot',13,10
            db '  poweroff  power off',13,10
            db 0

s_uname     db 'adachiOS 0.6 i386 BIOS (16-bit real mode)',13,10,0
s_meow      db 'meow :3',13,10,0
s_bwhoami   db 'adachi',13,10,0
s_bhostname db 'adachios',13,10,0
s_byes      db 'y',13,10,0
s_off       db 'poweroff failed, halting.',13,10,0

s_ls_err    db 'ls: could not read that directory',13,10,0
s_cd_nf     db 'cd: no such directory',13,10,0
s_cd_nd     db 'cd: not a directory',13,10,0
s_cat_use   db 'usage: cat FILE',13,10,0
s_cat_nf    db 'cat: no such file',13,10,0
s_no_dir    db 'no such directory',13,10,0
s_rm_use    db 'usage: rm PATH',13,10,0
s_rm_nf     db 'rm: no such file or directory',13,10,0
s_rm_busy   db 'rm: directory not empty',13,10,0
s_touch_use db 'usage: touch FILE',13,10,0
s_mk_use    db 'usage: mkdir DIR',13,10,0
s_mk_ex     db 'mkdir: already exists',13,10,0
s_cp_use    db 'usage: cp SRC DST',13,10,0
s_cp_nf     db 'cp: no such file',13,10,0
s_cp_same   db 'cp: source and destination are the same',13,10,0
s_mv_use    db 'usage: mv SRC DST',13,10,0
s_mv_nf     db 'mv: no such file',13,10,0
s_mv_ex     db 'mv: destination exists',13,10,0
s_mv_same   db 'mv: source and destination are the same',13,10,0
s_mv_dir    db 'mv: cannot move a directory to another directory',13,10,0
s_is_dir    db 'that is a directory',13,10,0
s_no_space  db 'no space left on the floppy',13,10,0

s_f_head    db 13,10,'  adachiOS fetch',13,10,'  --------------',13,10,0
s_f_cpu     db '  cpu:      ',0
s_f_cores   db '  cores:    ',0
s_f_threads db '  threads:  ',0
s_f_arch    db '  arch:     i386 (16-bit real mode)',13,10,0
s_f_mem     db '  memory:   ',0
s_f_mib     db ' MiB total',13,10,0
s_f_low     db '  low:      ',0
s_f_kib     db ' KiB',13,10,0
s_f_boot    db '  boot:     drive 0x',0

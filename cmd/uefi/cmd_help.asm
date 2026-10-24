%include "uefi.inc"

bits 64
default rel

global cmd_help

extern puts

section .text

cmd_help:
    sub rsp, 40
    lea rsi, [s_help]
    call puts
    add rsp, 40
    ret

section .data

s_help db `commands:\r\n  help      show this list\r\n  echo      echo your words back\r\n  clear     clear the screen\r\n  fetch     system, cpu and memory info\r\n  pwd       print the current directory\r\n  cd        change directory (cd DIR, cd to go home)\r\n  ls        list a directory (ls [DIR])\r\n  cat       print a file (cat FILE)\r\n  vi        edit a file (vi FILE, needs rodo outside /home)\r\n  touch     create an empty file (touch FILE)\r\n  mkdir     create a directory (mkdir DIR)\r\n  rm        delete a file or empty directory (rm PATH)\r\n  cp        copy a file (cp SRC DST)\r\n  mv        move a file (mv SRC DST)\r\n  uname     kernel info\r\n  meow      :3\r\n  true      do nothing\r\n  false     do nothing\r\n  factor N  factor a number\r\n  rev TEXT  reverse text\r\n  whoami    show user\r\n  hostname  show host\r\n  yes       repeat text\r\n  seq N     print 1..N\r\n  sleep N   wait seconds\r\n  rodo      run one command as root (rodo CMD)\r\n  acc       compile a C file (acc SRC [-o OUT], needs rodo outside /home)\r\n  flappy    play flappy bird (space/w flap, q quit)\r\n  reboot    cold reboot\r\n  poweroff  power off\r\n  up/down   recall previous commands\r\n`,0

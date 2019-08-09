# -*- gdb-script -*-

set architecture riscv:rv32
set remotetimeout 5000
set remotelogfile logs/gdb-remote.log
set logging overwrite
set logging file logs/gdb-client.log
set logging on
set pagination off

target remote | openocd --file openocd.cfg --log_output logs/openocd.log --debug

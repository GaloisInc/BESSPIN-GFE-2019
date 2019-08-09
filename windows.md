# Windows RISCV Toolchain Install

## WSL

If you install Windows Subsystem for Linux and Ubuntu support through the Windows store you can just follow the Ubuntu instructions and have a working system.

There are some down-sides to this though as the compiled binaries can't be called from outside the WSL environment making it difficult to use with other tools and IDEs outside of WSL.

## MSYS2

MSYS2 is an evolution of Cygwin and MSYS and provides the user with a POSIX environment with a fully featured package manager called **pacman** which was originally developed for Arch Linux.

All is required is installing MSYS2 via binary from https://www.msys2.org/

Next open an MSYS2 terminal and install the required dependencies.

    pacman -S base-devel gcc vim git zlib-devel libexpat-devel --needed

Now clone the RISCV toolchain. Got get a cup of coffee, breakfast, take the dog for a walk, this takes a while

    git clone --recursive https://github.com/riscv/riscv-gnu-toolchain

Now you should be able to compile and install the RISCV tools

    cd riscv-gnu-toolchain
    ./configure --prefix=/opt/riscv --with-arch=rv32gc --with-abi=ilp32d
    make

Running make installs all of the GNU tool chain into ```/opt/riscv``` inside of MSYS which is accessable outside the MSYS environment from windows as ```C:\mssys\opt```.  You may optionally add ```C:\msys64\opt\riscv\bin``` to your environment PATH.
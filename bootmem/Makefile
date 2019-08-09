
CROSS_COMPILE?=riscv64-unknown-linux-gnu-

CP=cp
MKDIR=mkdir

CC=$(CROSS_COMPILE)gcc
LD=$(CROSS_COMPILE)ld
OBJCOPY=$(CROSS_COMPILE)objcopy
OBJDUMP=$(CROSS_COMPILE)objdump

BUSYBOX_CONFIG?=$(CURDIR)/busybox.config
KCONFIG_CONFIG?=$(CURDIR)/linux.config

export CROSS_COMPILE KCONFIG_CONFIG

BBL_SRC=../../riscv-pk

TARGET=bb
default: build-bbl/bbl.text bootmem.bin
debian: override TARGET=deb
debian: build-bbl/bbl.text bootmem.bin

%.text: %
	$(OBJDUMP) -dS $< > $@

build-linux/vmlinux: FORCE
	$(MAKE) -f Makefile.${TARGET}

build-bbl/bbl: build-linux/vmlinux
	$(MKDIR) -p $(@D)
	cd $(@D) && $(BBL_SRC)/configure --host=riscv64-unknown-elf --with-payload=../build-linux/vmlinux
	$(MAKE) -C $(@D)

bbl.bin: build-bbl/bbl
	$(OBJCOPY) -O binary $< $@

bootmem: bootmem.S linker.ld bbl.bin
	$(CC) -Tlinker.ld $< -nostdlib -static -Wl,--no-gc-sections -o $@

bootmem.bin: bootmem
	$(OBJCOPY) -O binary $< $@

clean:
	@rm -f bootmem bootmem.bin bbl.bin
	@rm -rf build-bbl
	@make -f Makefile.deb clean
	@make -f Makefile.bb clean
FORCE:
	
.PHONY: default debian

CROSS_COMPILE?=riscv64-unknown-linux-gnu-

MKDIR?=mkdir
CP?=cp

CC?=$(CROSS_COMPILE)gcc
LD?=$(CROSS_COMPILE)ld
OBJCOPY?=$(CROSS_COMPILE)objcopy
OBJDUMP?=$(CROSS_COMPILE)objdump

BUSYBOX_CONFIG?=$(CURDIR)/busybox.config
KCONFIG_CONFIG?=$(CURDIR)/linux.config

export CROSS_COMPILE KCONFIG_CONFIG

BUSYBOX_SRC=../busybox
LINUX_SRC=../riscv-linux

default: build-busybox/busybox_unstripped.text build-linux/vmlinux.text

%.text: %
	$(OBJDUMP) -dS $< > $@

build-busybox/.config: $(BUSYBOX_CONFIG)
	$(MKDIR) -p $(@D)
	$(MAKE) -C $(BUSYBOX_SRC) O=$(CURDIR)/build-busybox defconfig
	$(CP) $< $@
	$(MAKE) -C $(@D) oldconfig

build-busybox/busybox_unstripped: build-busybox/.config
	$(MAKE) -C $(@D) all
	$(MAKE) -C $(@D) install

build-linux/.config: $(KCONFIG_CONFIG)
	$(MAKE) -C $(LINUX_SRC) ARCH=riscv O=$(CURDIR)/build-linux olddefconfig

build-linux/vmlinux: build-linux/.config build-busybox/busybox_unstripped
	@echo "Building Linux with config: $$KCONFIG_CONFIG and $(PAYLOAD)"
	$(MAKE) -C $(@D) ARCH=riscv O=$(CURDIR)/build-linux $(@F)

clean:
	@rm -rf build-linux build-busybox

.PHONY: default clean

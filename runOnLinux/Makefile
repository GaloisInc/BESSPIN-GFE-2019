
XLEN ?= 32

ifeq ($(XLEN),32)
RISCV_LIB = elf
else ifeq ($(XLEN),64)
RISCV_LIB  = linux-gnu
else
$(error Invalid XLEN)
endif

TARGET=riscv${XLEN}-unknown-${RISCV_LIB}
GCC		= $(TARGET)-gcc
GCC_FLAGS = -DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf
OBJCOPY	= $(TARGET)-objcopy
OBJDUMP	= $(TARGET)-objdump

.PHONY:
	clean default

default: binary.dump

#Note: If you change the name of "binary2run", then the name has to be changed in testing/scripts/runOnLinux.py
binary2run: $(PROG)
	$(GCC) $(GCC_FLAGS) $< -o $@

binary.dump: binary2run
	$(OBJDUMP) -dS $< > $@

clean:
	rm -rf binary*
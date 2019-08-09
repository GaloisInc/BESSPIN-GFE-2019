###  -*-Makefile-*-

# called by (e.g.): make compile PROC=bluespec_p1

REPO = ..

# ================================================================
# Definitions specific to the particular processor

INCLUDED_FILE = procs/$(PROC)/Include.mk

ifneq ($(strip $(PROC)),)
include $(INCLUDED_FILE)
endif

ARCH ?= RV$(XLEN)$(ISA)

SIM_EXE_FILE = run/exe_HW_$(PROC)_sim

# ================================================================

# Top-level module
TOPMODULE ?= mkTop_HW_Side

# ================================================================
# Compile and link Verilog RTL sources into an verilator executable

# Verilator flags: notes
#    --stats            Dump stats on the design, in file {prefix}__stats.txt
#    --x-assign fast    Optimize X value
#    --x-initial fast   Optimize uninitialized value
#    --noassert         Disable all assertions
#    +define+PRINTF_COND=0 Disable debug messages (Chisel only)

VERILATOR_FLAGS = --stats --x-assign fast --x-initial fast --noassert src_C/sim_socket.c +define+PRINTF_COND=0

# Produce a static binary: (GLIBC_STATIC is set by Nix shell)
VERILATOR_FLAGS += -LDFLAGS "-static -L ${GLIBC_STATIC}/lib"

# Verilator flags: use the following to include code to generate VCDs
# Select trace-depth according to your module hierarchy
VERILATOR_FLAGS += --trace -CFLAGS -DVM_TRACE

VTOP                = V$(TOPMODULE)
VERILATOR_RESOURCES = Resources

.PHONY: simulator
simulator:
ifeq ($(strip $(PROC)),)
	@echo "ERROR: Must specify a processor (e.g. PROC=bluespec_p1)"
	exit 1
endif
	@echo "INFO: Verilating Verilog files (in newly created obj_dir)"
	cp Verilog_RTL/mkSoC_Top_orig.v Verilog_RTL/mkSoC_Top.v
	sed  -f $(VERILATOR_RESOURCES)/sed_script.txt  Verilog_RTL/$(TOPMODULE)_orig.v > tmp1.v
	cat  $(VERILATOR_RESOURCES)/verilator_config.vlt \
	     $(VERILATOR_RESOURCES)/import_DPI_C_decls.v \
	     tmp1.v                                     > Verilog_RTL/$(TOPMODULE).v
	rm   -f  tmp1.v
	sed  -f $(VERILATOR_RESOURCES)/sed_script2.txt  $(PROCESSOR_RTL)/$(TOPNAME).v > tmp2.v
	mv tmp2.v Verilog_RTL/mkP_Core.v
ifeq ($(PROC), chisel_p1XXX)
	sed  -f $(VERILATOR_RESOURCES)/sed_script3.txt  Verilog_RTL/mkSoC_Top_orig.v > Verilog_RTL/mkSoC_Top.v
endif
ifeq ($(PROC), chisel_p2XXX)
	sed  -f $(VERILATOR_RESOURCES)/sed_script3.txt  Verilog_RTL/mkSoC_Top_orig.v > Verilog_RTL/mkSoC_Top.v
endif
	verilator \
		-IVerilog_RTL \
		-Iprocs/$(PROC) \
		-I$(PROCESSOR_RTL) \
		--top-module mkTop_HW_Side \
		$(VERILATOR_FLAGS) \
		--cc  $(TOPMODULE).v \
		--exe  sim_main.cpp \
		src_C/sim_dmi.c \
		src_C/C_Imported_Functions.c
	@echo "INFO: Linking verilated files"
	cp  -p  src_C/sim_main.cpp  obj_dir/sim_main.cpp
	cd obj_dir; \
	   make -j -f V$(TOPMODULE).mk  $(VTOP); \
	   cp -p  $(VTOP)  ../$(SIM_EXE_FILE)
	rm Verilog_RTL/mkP_Core.v
	@echo "INFO: Created verilator executable:    $(SIM_EXE_FILE)"

.PHONY: jtag_simulator
jtag_simulator:
ifeq ($(strip $(PROC)),)
	@echo "ERROR: Must specify a processor (e.g. PROC=bluespec_p1)"
	exit 1
endif
	@echo "INFO: Verilating Verilog files (in newly created obj_dir)"
	cp Verilog_RTL/mkSoC_Top_orig.v Verilog_RTL/mkSoC_Top.v
	sed  -f $(VERILATOR_RESOURCES)/sed_script.txt  Verilog_RTL/$(TOPMODULE)_orig.v > tmp1.v
	cat  $(VERILATOR_RESOURCES)/verilator_config.vlt \
	     $(VERILATOR_RESOURCES)/import_DPI_C_decls.v \
	     tmp1.v                                     > Verilog_RTL/$(TOPMODULE).v
	rm   -f  tmp1.v
	sed  -f $(VERILATOR_RESOURCES)/sed_script2.txt  $(PROCESSOR_RTL)/$(TOPNAME).v > tmp2.v
	mv tmp2.v Verilog_RTL/mkP_Core.v
	verilator \
		-IProcessor/Boot_ROM \
		-I$(PROCESSOR_RTL) \
		-IVerilog_RTL \
		--top-module mkTop_HW_Side \
		$(VERILATOR_FLAGS) \
		--cc  $(TOPMODULE).v \
		--exe  sim_main.cpp \
		src_C/sim_dmi.c \
		src_C/C_Imported_Functions.c
	@echo "INFO: Linking verilated files"
	cp  -p  src_C/sim_main.cpp  obj_dir/sim_main.cpp
	cd obj_dir; \
	   make -j -f V$(TOPMODULE).mk  $(VTOP); \
	   cp -p  $(VTOP)  ../$(SIM_EXE_FILE)
	rm Verilog_RTL/mkP_Core.v
	@echo "INFO: Created verilator executable:    $(SIM_EXE_FILE)"

clean:
	rm -rf obj_dir

# ================================================================

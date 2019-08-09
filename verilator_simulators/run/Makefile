###  -*-Makefile-*-

# called by (e.g.): make compile PROC=bluespec_p1

REPO = ../..

# ================================================================
# Definitions specific to the particular processor

INCLUDED_FILE = ../procs/$(PROC)/Include.mk

ifneq ($(strip $(PROC)),)
include $(INCLUDED_FILE)
endif

ARCH ?= RV$(XLEN)$(ISA)

SIM_EXE_FILE = exe_HW_$(PROC)_sim

# ================================================================

.PHONY: help
help:
	@echo '    make  run_example  Runs simulation executable on ELF given by EXAMPLE'
	@echo ''
	@echo '    make  test         Runs simulation executable on rv32ui-p-add or rv64ui-p-add'
	@echo '    make  isa_tests    Runs simulation executable on all relevant standard RISC-V ISA tests'

# ----------------
# Top-level module

TOPMODULE ?= mkTop_HW_Side

# ================================================================
# Runs simulation executable on ELF given by EXAMPLE

EXAMPLE ?= PLEASE_DEFINE_EXAMPLE_PATH_TO_ELF

.PHONY: run_example
run_example:
	make -C  $(TESTS_DIR)/elf_to_hex
	$(TESTS_DIR)/elf_to_hex/elf_to_hex  $(EXAMPLE)  Mem.hex
	./$(SIM_EXE_FILE) $(VERBOSITY)  +tohost

.PHONY: run_example_waves
run_example_waves:
	make -C  $(TESTS_DIR)/elf_to_hex
	$(TESTS_DIR)/elf_to_hex/elf_to_hex  $(EXAMPLE)  Mem.hex
	./$(SIM_EXE_FILE) $(VERBOSITY)  +tohost +trace

# ================================================================
# Test: run the executable on the standard RISCV ISA test specified in TEST

TESTS_DIR ?= Tests
TEST ?= rv$(XLEN)ui-p-add

VERBOSITY ?= +v1

.PHONY: smoke_test
smoke_test:
	make -C  $(TESTS_DIR)/elf_to_hex
	$(TESTS_DIR)/elf_to_hex/elf_to_hex  $(TESTS_DIR)/isa/$(TEST)  Mem.hex
	./$(SIM_EXE_FILE)  $(VERBOSITY)  +tohost +trace

# ================================================================
# ISA Regression testing

.PHONY: isa_tests
isa_tests:
	mkdir -p Logs/$(PROC)
	rm -rf Logs/$(PROC)/*
	@echo "Running regressions on ISA tests; saving logs in Logs/$(PROC)/"
	./Run_regression.py  $(SIM_EXE_FILE)  .  ./Logs/$(PROC)  $(ARCH)
	@echo "Finished running regressions; saved logs in Logs/$(PROC)/"

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~  Makefile_*  symbol_table.txt  build_dir  obj_dir

.PHONY: full_clean
full_clean: clean
	rm -r -f  ./exe_HW*  *.log  *.vcd  *.hex  Logs/

# ================================================================

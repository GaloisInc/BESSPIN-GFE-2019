// Copyright (c) 2019 Bluespec, Inc.  All rights reserved.

// The first set or routines here are convenience routines
// that give access to read/write MSTATUS and MIE from C code.

// This is followed by 'mtvec_handler', the initial entry point for
// all traps and interrupts (see more comments below).

	// ================================================================
	// MSTATUS access from C
	// csrr_mstatus () => uint32_t/uint64_t    read
	// csrw_mstatus (uint32_t/uint64_t x)      write
	// csrs_mstatus (uint32_t/uint64_t x)      set bits
	// csrc_mstatus (uint32_t/uint64_t x)      clear bits

	.text
	.globl	csrr_mstatus
csrr_mstatus:
	csrr	a0, mstatus
	ret

	.globl	csrw_mstatus
csrw_mstatus:
	csrw	mstatus, a0
	ret

	.globl	csrs_mstatus
csrs_mstatus:
	csrs	mstatus, a0
	ret

	.globl	csrc_mstatus
csrc_mstatus:
	csrc	mstatus, a0
	ret

	// ================================================================
	// MIE access from C
	// csrr_mie => uint32_t/uint64_t     read
	// csrw_mie (uint32_t/uint64_t x)    write
	// csrs_mie (uint32_t/uint64_t x)    set bits
	// csrc_mie (uint32_t/uint64_t x)    clear bits

	.text
	.globl	csrr_mie
csrr_mie:
	csrr	a0, mie
	ret

	.globl	csrw_mie
csrw_mie:
	csrw	mie, a0
	ret

	.globl	csrs_mie
csrs_mie:
	csrs	mie, a0
	ret

	.globl	csrc_mie
csrc_mie:
	csrc	mie, a0
	ret

	// ================================================================
	// mtvec_handler
	// On startup, we set MTVEC to point at this routine.
	// Any trap or interrupt begins here.
	// It contains code to save/restore all integer registers,
	// surrounded by a call to 'exception_handler' (external).
	// 'exception_handler' can be written in C, and will receive
	// MSTATUS, MEPC, MCAUSE and MTVAL as arguments.

	// NOTE: this code needs enhancements:
	// - Save/restore floating-point registers (if they exist)
	// - Currently only handles 'DIRECT' MTVEC mode, where traps
	//     and interrupts both vector to the same location.
	//     Needs extension to handle 'VECTORED' MTVEC mode.

	.text
	.globl	mtvec_handler
mtvec_handler:
	// Save all integer regs
	// First save x31 in mscratch so we can use it as pointer to save area
	csrw	mscratch, x31
	la	x31, reg_save_area
#if __riscv_xlen == 64
	sd	x1,    8 (x31)
	sd	x2,   16 (x31)
	sd	x3,   24 (x31)
	sd	x4,   32 (x31)
	sd	x5,   40 (x31)
	sd	x6,   48 (x31)
	sd	x7,   56 (x31)
	sd	x8,   64 (x31)
	sd	x9,   72 (x31)
	sd	x10,  80 (x31)
	sd	x11,  88 (x31)
	sd	x12,  96 (x31)
	sd	x13, 104 (x31)
	sd	x14, 112 (x31)
	sd	x15, 120 (x31)
	sd	x16, 128 (x31)
	sd	x17, 136 (x31)
	sd	x18, 144 (x31)
	sd	x19, 152 (x31)
	sd	x20, 160 (x31)
	sd	x21, 168 (x31)
	sd	x22, 176 (x31)
	sd	x23, 184 (x31)
	sd	x24, 192 (x31)
	sd	x25, 200 (x31)
	sd	x26, 208 (x31)
	sd	x27, 216 (x31)
	sd	x28, 224 (x31)
	sd	x29, 232 (x31)
	sd	x30, 240 (x31)
	// Finally save original value of x31 (saved earlier in mscratch)
	csrr	x1, mscratch
	sd	x1, 248 (x31)
#else
	sw	x1,    4 (x31)
	sw	x2,    8 (x31)
	sw	x3,   12 (x31)
	sw	x4,   16 (x31)
	sw	x5,   20 (x31)
	sw	x6,   24 (x31)
	sw	x7,   28 (x31)
	sw	x8,   32 (x31)
	sw	x9,   36 (x31)
	sw	x10,  40 (x31)
	sw	x11,  44 (x31)
	sw	x12,  48 (x31)
	sw	x13,  52 (x31)
	sw	x14,  56 (x31)
	sw	x15,  60 (x31)
	sw	x16,  64 (x31)
	sw	x17,  68 (x31)
	sw	x18,  72 (x31)
	sw	x19,  76 (x31)
	sw	x20,  80 (x31)
	sw	x21,  84 (x31)
	sw	x22,  88 (x31)
	sw	x23,  92 (x31)
	sw	x24,  96 (x31)
	sw	x25, 100 (x31)
	sw	x26, 104 (x31)
	sw	x27, 108 (x31)
	sw	x28, 112 (x31)
	sw	x29, 116 (x31)
	sw	x30, 120 (x31)
	// Finally save original value of x31 (saved earlier in mscratch)
	csrr	x1, mscratch    // original value of x1
	sw	x1, 248 (x31)
#endif
	// Setup mstatus, mepc, mcause, mtval in argument regs
	csrr	a0, mstatus
	csrr	a1, mepc
	csrr	a2, mcause
	csrr	a3, mtval
	// Call handler (written in C)
	.extern	exception_handler
	jal	x1, exception_handler
	
	// Restore all integer registers
	la	x31, reg_save_area
#if __riscv_xlen == 64
	ld	x1,    8 (x31)
	ld	x2,   16 (x31)
	ld	x3,   24 (x31)
	ld	x4,   32 (x31)
	ld	x5,   40 (x31)
	ld	x6,   48 (x31)
	ld	x7,   56 (x31)
	ld	x8,   64 (x31)
	ld	x9,   72 (x31)
	ld	x10,  80 (x31)
	ld	x11,  88 (x31)
	ld	x12,  96 (x31)
	ld	x13, 104 (x31)
	ld	x14, 112 (x31)
	ld	x15, 120 (x31)
	ld	x16, 128 (x31)
	ld	x17, 136 (x31)
	ld	x18, 144 (x31)
	ld	x19, 152 (x31)
	ld	x20, 160 (x31)
	ld	x21, 168 (x31)
	ld	x22, 176 (x31)
	ld	x23, 184 (x31)
	ld	x24, 192 (x31)
	ld	x25, 200 (x31)
	ld	x26, 208 (x31)
	ld	x27, 216 (x31)
	ld	x28, 224 (x31)
	ld	x29, 232 (x31)
	ld	x30, 240 (x31)
	ld	x31, 248 (x31)
#else
	lw	x1,    4 (x31)
	lw	x2,    8 (x31)
	lw	x3,   12 (x31)
	lw	x4,   16 (x31)
	lw	x5,   20 (x31)
	lw	x6,   24 (x31)
	lw	x7,   28 (x31)
	lw	x8,   32 (x31)
	lw	x9,   36 (x31)
	lw	x10,  40 (x31)
	lw	x11,  44 (x31)
	lw	x12,  48 (x31)
	lw	x13,  52 (x31)
	lw	x14,  56 (x31)
	lw	x15,  60 (x31)
	lw	x16,  64 (x31)
	lw	x17,  68 (x31)
	lw	x18,  72 (x31)
	lw	x19,  76 (x31)
	lw	x20,  80 (x31)
	lw	x21,  84 (x31)
	lw	x22,  88 (x31)
	lw	x23,  92 (x31)
	lw	x24,  96 (x31)
	lw	x25, 100 (x31)
	lw	x26, 104 (x31)
	lw	x27, 108 (x31)
	lw	x28, 112 (x31)
	lw	x29, 116 (x31)
	lw	x30, 120 (x31)
	lw	x31, 124 (x31)
#endif
	// Return from trap/interrupt
	mret

	// Data area where registers are saved
	.data
	.align	8
reg_save_area:
	.fill	256

	// ================================================================

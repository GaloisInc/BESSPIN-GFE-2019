	.text
	.globl	_reset
_reset:
	li	sp, 0xC00f0000
	// Place an illegal instruction (0) at the stack pointer
	// so that the program ends if the value is used
#if __riscv_xlen == 64
	sd	zero, 0(sp)
	sd	zero, -8(sp)
#else
	sw	zero, 0(sp)
	sw	zero, -4(sp)
#endif

	// Set MSTATUS
	// Disable MSTATUS.MIE, MSTATUS.SIE, MSTATUS.UIE
	// Set MSTATUS.FS to 2 = Dirty
	li      s0, 0x6000
	csrw    mstatus, s0

	// Set MTVEC to point at mtvec_handler
	.extern	mtvec_handler
	la	s0, mtvec_handler
	csrw	mtvec, s0

#ifdef __riscv_float_abi_double
	// Set MSTATUS.FS to 1 = Initial
	li	s0, 0x2000
	csrs	mstatus, s0
#endif

	/* zero out the bss */
	.option push
	.option norelax
        la      t1, __bss_start
        la      t2, _end
#if __riscv_xlen == 64
zinit:  sd      zero, 0(t1)
        add     t1, t1, 0x8
        bne     t1, t2, zinit
#else
zinit:  sw      zero, 0(t1)
        add     t1, t1, 0x4
        bne     t1, t2, zinit
#endif
	.option pop

	j _start

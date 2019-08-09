
#define FLASH_BASE 0x44000000
#define RAM_BASE 0xc0000000

	.text
	.globl _start

_start:
	la t0, _payload
	li t1, RAM_BASE
	la t2, _payload_end

1:
#if __riscv_xlen == 32
	lw t3, 0(t0)
	sw t3, 0(t1)
	add t0, t0, 4
	add t1, t1, 4
#else
	ld t3, 0(t0)
	sd t3, 0(t1)
	add t0, t0, 8
	add t1, t1, 8
#endif
	blt t0, t2, 1b

	fence.i

	li t0, RAM_BASE
	jr t0

	.align 3
_payload:
	.incbin "bbl.bin"
_payload_end:

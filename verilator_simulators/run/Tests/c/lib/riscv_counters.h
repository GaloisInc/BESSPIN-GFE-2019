// Copyright (c) 2013-2019 Bluespec, Inc.  All Rights Reserved

#pragma once

// ================================================================
// The following are interfaces to inline RISC-V assembly instructions
//     RDCYCLE, RDTIME, RDINSTRET
// For all of them, the result is left in v0 (= x16) per calling convention

extern uint64_t  read_cycle    (void);    // RDCYCLE
extern uint64_t  read_time     (void);    // RDTIME
extern uint64_t  read_instret  (void);    // RDINSTRET

// ================================================================
// When reading/writing data needed by accelerators, we use 'fence' to
// ensure that caches are empty, i.e., memory contains definitive data
// and caches will be reloaded.

extern void fence (void);

// ================================================================
// Read/Write to IO addresses

extern uint32_t  io_read32  (uint64_t addr);
extern void      io_write32 (uint64_t addr, uint32_t x);
extern uint64_t  io_read64  (uint64_t addr);
extern void      io_write64 (uint64_t addr, uint64_t x);

// ================================================================
// Pass/Fail macros. This is a temporary place-holder. To be moved to an
// appropriate location under the env directory structure once we can converge
// on a unified build environment for all tests

#define TEST_PASS asm volatile ("li a0, 0x1"); \
                  asm volatile ("sw a0, tohost, t0");
#define TEST_FAIL asm volatile ("li a0, 0x3"); \
                  asm volatile ("sw a0, tohost, t0");

// ================================================================

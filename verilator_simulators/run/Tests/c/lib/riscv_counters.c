// Copyright (c) 2013-2019 Bluespec, Inc.  All Rights Reserved

#include <stdio.h>
#include <stdint.h>

// ================================================================
// The following are interfaces to inline RISC-V assembly instructions
//     RDCYCLE, RDTIME, RDINSTRET

// ================================================================
// RV32 versions

#ifdef RV32

uint64_t  read_cycle (void)
{
    uint64_t result;
    uint32_t resulth, resultl;

    asm volatile ("RDCYCLEH %0" : "=r" (resulth));
    asm volatile ("RDCYCLE  %0" : "=r" (resultl));

    result = resulth;
    result = ((result << 32) | resultl);
    return result;
}

uint64_t  read_time (void)
{
    uint64_t result;
    uint32_t resulth, resultl;

    asm volatile ("RDTIMEH %0" : "=r" (resulth));
    asm volatile ("RDTIME  %0" : "=r" (resultl));

    result = resulth;
    result = ((result << 32) | resultl);
    return result;
}

uint64_t  read_instret (void)
{
    uint64_t result;
    uint32_t resulth, resultl;

    asm volatile ("RDINSTRETH %0" : "=r" (resulth));
    asm volatile ("RDINSTRET  %0" : "=r" (resultl));

    result = resulth;
    result = ((result << 32) | resultl);
    return result;
}

#endif

// ================================================================
// RV64 versions

#ifdef RV64

uint64_t  read_cycle (void)
{
    uint64_t result;

    asm volatile ("RDCYCLE  %0" : "=r" (result));

    return result;
}

uint64_t  read_time (void)
{
    uint64_t result;

    asm volatile ("RDTIME  %0" : "=r" (result));

    return result;
}

uint64_t  read_instret (void)
{
    uint64_t result;

    asm volatile ("RDINSTRET  %0" : "=r" (result));

    return result;
}

#endif

// ================================================================
// When reading/writing data needed by accelerators, we use 'fence' to
// ensure that caches are empty, i.e., memory contains definitive data
// and caches will be reloaded.

void fence (void)
{
    asm volatile ("fence");
}

// ================================================================
// Read/Write to IO addresses

uint32_t  io_read32 (uint64_t addr)
{
    uint32_t *p = (uint32_t *) addr;
    return *p;
}

void  io_write32 (uint64_t addr, uint32_t x)
{
    uint32_t *p = (uint32_t *) addr;
    *p = x;
}

uint64_t  io_read64 (uint64_t addr)
{
    uint64_t *p = (uint64_t *) addr;
    return *p;
}

void  io_write64 (uint64_t addr, uint64_t x)
{
    uint64_t *p = (uint64_t *) addr;
    *p = x;
}

// ================================================================

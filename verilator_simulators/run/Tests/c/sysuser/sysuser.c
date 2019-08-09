#include <stdio.h>
#include "riscv_counters.h"

static void usermode(void)
{
    asm volatile ("csrci mstatus, 1");
}

static unsigned long rdcycle(void)
{
    unsigned long ret;

    asm volatile ("rdcycle %0" : "=r" (ret));

    return ret;
}

static unsigned long rdinstret(void)
{
    unsigned long ret;

    asm volatile ("rdinstret %0" : "=r" (ret));

    return ret;
}

static unsigned long rdtime(void)
{
    unsigned long ret;

    asm volatile ("rdtime %0" : "=r" (ret));

    return ret;
}

static unsigned long fcsr(void)
{
    unsigned long ret;

    asm volatile ("csrr %0, fcsr" : "=r" (ret));

    return ret;
}

int main (int argc, char *argv[])
{
    printf("rdcycle %ld\n", rdcycle());
    printf("rdinstret %ld\n", rdinstret());
    printf("rdtime %ld\n", rdinstret());
#if defined(__riscv_hard_float)
    printf("fcsr %ld\n", fcsr());
#endif

    usermode();

    rdcycle();
    rdinstret();
    rdinstret();
#if defined(__riscv_hard_float)
    fcsr();
#endif

    TEST_PASS
    return 0;
}

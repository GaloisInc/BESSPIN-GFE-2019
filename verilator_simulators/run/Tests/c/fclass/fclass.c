#include <stdint.h>
#include <assert.h>
#include <math.h>
#include "riscv_counters.h"

static inline unsigned int fclass_d(double a)
{
    unsigned int ret;
#if defined(__riscv_hard_float)
    __asm__ __volatile__ ("fclass.d %0, %1" : "=r" (ret) : "f" (a));
#endif
    return ret;
}

static inline unsigned int fclass_s(float a)
{
    unsigned int ret;
#if defined(__riscv_hard_float)
    __asm__ __volatile__ ("fclass.s %0, %1" : "=r" (ret) : "f" (a));
#endif
    return ret;
}

int main (int argc, char *argv[])
{
    double d;
    float f;

    d = nan("");
    assert(fclass_d(d) == 8);

    d = HUGE_VAL;
    assert(fclass_d(d) == 7);

    d = -d;
    assert(fclass_d(d) == 0);

    d = 0.0;
    assert(fclass_d(d) == 4);

    d = -d;
    assert(fclass_d(d) == 3);

    d = 1.0;
    assert(fclass_d(d) == 6);

    d = -d;
    assert(fclass_d(d) == 1);

    f = nanf("");
    assert(fclass_s(f) == 8);

    f = HUGE_VALF;
    assert(fclass_s(f) == 7);

    f = -f;
    assert(fclass_s(f) == 0);

    f = 0.0;
    assert(fclass_s(f) == 4);

    f = -f;
    assert(fclass_s(f) == 3);

    f = 1.0;
    assert(fclass_s(f) == 6);

    f = -f;
    assert(fclass_s(f) == 1);

    TEST_PASS

    return 0;
}

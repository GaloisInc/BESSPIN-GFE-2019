#include <stdio.h>
#include <stdint.h>
#include "riscv_counters.h"

union floatu {
  double    d;
  unsigned long long u;
};

int main (int argc, char *argv[])
{
  float x = 2.0;
  printf("float  f = %f\n",  x);

  union floatu f;
  f.d = 5.0;

  printf("double f = %f\n",  f.d);
  printf("u64    f = %lx\n", f.u);

  TEST_PASS

  return 0;
}

#ifndef __CLOCKING_H__
#define __CLOCKING_H__

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <getopt.h>
#include <string.h>
#include <libgen.h>
#include <dirent.h>
#include <time.h>
#include <stdbool.h>

#include "../drivers/bluenoc.h"

#define MIN(x, y)   ((x) < (y) ? (x) : (y))
#define MAX(x, y)   ((x) > (y) ? (x) : (y))
#define DIV_ROUND_UP(x, y)  (((x) + (y) - 1) / (y))
#define DIV_ROUND_CLOSEST(x, y) (unsigned long)(((double)(x) / (double)(y)) + 0.5)
#define CLAMP(val, min, max) ((val) < (min) ? (min) : ((val) > (max) ? (max) : (val)))
#define ABS(x)    ((x) < 0 ? -(x) : (x))

const unsigned long clkgen_reg_id            = 0x00;
const unsigned long clkgen_reg_update_enable = 0x01;
const unsigned long clkgen_reg_clkout0_1     = 0x02;
const unsigned long clkgen_reg_clkout0_2     = 0x03;
const unsigned long clkgen_reg_clkout1_1     = 0x04;
const unsigned long clkgen_reg_clkout1_2     = 0x05;
const unsigned long clkgen_reg_clkout2_1     = 0x06;
const unsigned long clkgen_reg_clkout2_2     = 0x07;
const unsigned long clkgen_reg_clkout3_1     = 0x08;
const unsigned long clkgen_reg_clkout3_2     = 0x09;
const unsigned long clkgen_reg_clkout4_1     = 0x0a;
const unsigned long clkgen_reg_clkout4_2     = 0x0b;
const unsigned long clkgen_reg_clkout5_1     = 0x0c;
const unsigned long clkgen_reg_clkout5_2     = 0x0d;
const unsigned long clkgen_reg_clkout6_1     = 0x0e;
const unsigned long clkgen_reg_clkout6_2     = 0x0f;
const unsigned long clkgen_reg_clk_div       = 0x10;
const unsigned long clkgen_reg_clk_fb_1      = 0x11;
const unsigned long clkgen_reg_clk_fb_2      = 0x12;
const unsigned long clkgen_reg_lock_1        = 0x13;
const unsigned long clkgen_reg_lock_2        = 0x14;
const unsigned long clkgen_reg_lock_3        = 0x15;
const unsigned long clkgen_reg_filter_1      = 0x16;
const unsigned long clkgen_reg_filter_2      = 0x17;
const unsigned long clkgen_reg_status        = 0x1f;

static const unsigned long clkgen_filter_table[] = {
  0x01001990, 0x01001190, 0x01009890, 0x01001890,
  0x01008890, 0x01009090, 0x01009090, 0x01009090,
  0x01009090, 0x01000890, 0x01000890, 0x01000890,
  0x08009090, 0x01001090, 0x01001090, 0x01001090,
  0x01001090, 0x01001090, 0x01001090, 0x01001090,
  0x01001090, 0x01001090, 0x01001090, 0x01008090,
  0x01008090, 0x01008090, 0x01008090, 0x01008090,
  0x01008090, 0x01008090, 0x01008090, 0x01008090,
  0x01008090, 0x01008090, 0x01008090, 0x01008090,
  0x01008090, 0x08001090, 0x08001090, 0x08001090,
  0x08001090, 0x08001090, 0x08001090, 0x08001090,
  0x08001090, 0x08001090, 0x08001090
};

static const unsigned long clkgen_lock_table[] = {
  0x060603e8, 0x060603e8, 0x080803e8, 0x0b0b03e8,
  0x0e0e03e8, 0x111103e8, 0x131303e8, 0x161603e8,
  0x191903e8, 0x1c1c03e8, 0x1f1f0384, 0x1f1f0339,
  0x1f1f02ee, 0x1f1f02bc, 0x1f1f028a, 0x1f1f0271,
  0x1f1f023f, 0x1f1f0226, 0x1f1f020d, 0x1f1f01f4,
  0x1f1f01db, 0x1f1f01c2, 0x1f1f01a9, 0x1f1f0190,
  0x1f1f0190, 0x1f1f0177, 0x1f1f015e, 0x1f1f015e,
  0x1f1f0145, 0x1f1f0145, 0x1f1f012c, 0x1f1f012c,
  0x1f1f012c, 0x1f1f0113, 0x1f1f0113, 0x1f1f0113
};

typedef struct __attribute__((packed, aligned(4))) {
  unsigned int data:16;
  unsigned int addr:15;
  unsigned int rnw:1;
} clock_request_t;

class ClockGenerator
{
private:
  int            m_fd;

private:
  unsigned long lookup_filter(unsigned long m);
  unsigned long lookup_lock(unsigned long m);
  void calc_params(unsigned long fin, unsigned long fout, 
		   unsigned long *best_d, unsigned long *best_m,
		   unsigned long *best_dout);
  void calc_clk_params(unsigned long divider, unsigned long *low,
		       unsigned long *high, unsigned long *edge,
		       unsigned long *nocount);
  void write(unsigned long reg, unsigned long val);
  void read(unsigned long reg, unsigned long *val);

  ClockGenerator();
  ClockGenerator( const ClockGenerator &);

public:
  ClockGenerator(int);
  ~ClockGenerator();
  bool InReset();
  bool IsLocked();
  int SetRate(unsigned long rate, unsigned long clknum = 0, unsigned long parent_rate = 125000000);
  unsigned long GetRate(unsigned int clknum = 0, unsigned long parent_rate = 125000000);
};


#endif // __CLOCKING_H__

#include "clocking.h"

unsigned long 
ClockGenerator::lookup_filter(unsigned long m)
{
  if (m < 47)
    return clkgen_filter_table[m];
  return 0x08008090;
}

unsigned long 
ClockGenerator::lookup_lock(unsigned long m)
{
  if (m < 36) 
    return clkgen_lock_table[m];
  return 0x1f1f00fa;
}

void 
ClockGenerator::calc_params(unsigned long fin, unsigned long fout, 
			    unsigned long *best_d, unsigned long *best_m,
			    unsigned long *best_dout)
{
  const unsigned long fpfd_min = 10000;
  const unsigned long fpfd_max = 300000;
  const unsigned long fvco_min = 600000;
  const unsigned long fvco_max = 1200000;

  unsigned long d = 0;
  unsigned long d_min = 0;
  unsigned long d_max = 0;
  unsigned long _d_min = 0;
  unsigned long _d_max = 0;
  unsigned long m = 0;
  unsigned long m_min = 0;
  unsigned long m_max = 0;
  unsigned long dout = 0;
  unsigned long fvco = 0;
  long f = 0;
  long best_f = 0;
  
  fin /= 1000;
  fout /= 1000;
  
  best_f = 0x7FFFFFFF;
  *best_d = 0;
  *best_m = 0;
  *best_dout = 0;
  
  d_min = MAX(DIV_ROUND_UP(fin, fpfd_max), 1);
  d_max = MIN(fin / fpfd_min, 80);
  
  m_min = MAX(DIV_ROUND_UP(fvco_min, fin) * d_min, 1);
  m_max = MIN(fvco_max * d_max / fin, 64);
  
  for(m = m_min; m <= m_max; m++) {
    _d_min = MAX(d_min, DIV_ROUND_UP(fin * m, fvco_max));
    _d_max = MIN(d_max, fin * m / fvco_min);
    
    for(d = _d_min; d <= _d_max; d++) {
      fvco = fin * m / d;
      
      dout = DIV_ROUND_CLOSEST(fvco, fout);
      dout = CLAMP(dout, 1, 128);
      f = fvco / dout;
      if (ABS(f - fout) < ABS(best_f - fout)) {
	best_f = f;
	*best_d = d;
	*best_m = m;
	*best_dout = dout;
	if (best_f == (long)fout) {
	  return;
	}
      }
    }
  }
}

void 
ClockGenerator::calc_clk_params(unsigned long divider, unsigned long *low,
				unsigned long *high, unsigned long *edge,
				unsigned long *nocount)
{
  if (divider == 1)
    *nocount = 1;
  else
    *nocount = 0;
  
  *high = divider / 2;
  *edge = divider % 2;
  *low = divider - *high;
}

void 
ClockGenerator::write(unsigned long reg, unsigned long val)
{
  int i = 5;
  if (m_fd == -1) {
    perror("clock_generator write");
    return;
  }

  clock_request_t request;
  request.rnw  = 0;
  request.addr = reg;
  request.data = val & 0xFFFF;
  unsigned long data;
  do {
    if (i != 5) {
      sleep(1);
    }
    int res = ioctl(m_fd, BNOC_CLK_GET_STATUS, (unsigned int*)&data);
    if (res == -1) {
      perror("clock_generator write status ioctl");
    }
  } while((!(data & 0x1)) && (i-- > 0));

  if (i < 0) {
    perror("clock_generator write status ioctl busy");
  }
  int res = ioctl(m_fd, BNOC_CLK_SEND_CTRL, (unsigned int*)&request);
  if (res == -1) {
    perror("clock_generator write ioctl");
  }
}

void 
ClockGenerator::read(unsigned long reg, unsigned long *val)
{
  int i = 5;
  if (m_fd == -1) {
    perror("clock_generator read");
    return;
  }

  clock_request_t request;
  request.rnw  = 1;
  request.addr = reg;
  unsigned long data;
  do {
    if (i != 5) {
      sleep(1);
    }
    int res = ioctl(m_fd, BNOC_CLK_GET_STATUS, (unsigned int*)&data);
    if (res == -1) {
      perror("clock_generator read status1 ioctl");
    }
  } while((!(data & 0x1)) && (i-- > 0));

  if (i < 0) {
    perror("clock_generator read status1 ioctl busy");
  }
  int res = ioctl(m_fd, BNOC_CLK_SEND_CTRL, (unsigned int*)&request);
  if (res == -1) {
    perror("clock_generator read ioctl");
  }

  do {
    if (i != 5) {
      sleep(1);
    }
    int res = ioctl(m_fd, BNOC_CLK_GET_STATUS, (unsigned long*)&data);
    if (res == -1) {
      perror("clock_generator read status2 ioctl");
    }
  } while ((!(data & 0x2)) && (i-- > 0));
  if (i < 0) {
    perror("clock_generator read status2 ioctl busy");
  }

  res = ioctl(m_fd, BNOC_CLK_RD_WORD, (unsigned long*)&data);
  if (res == -1) {
    perror("clock_generator read2 ioctl");
  }
  *val = data;
  res = ioctl(m_fd, BNOC_CLK_CLR_WORD, (unsigned long*)&data);
  if (res == -1) {
    perror("clock_generator read clear ioctl");
  }
}


ClockGenerator::ClockGenerator(int file_desc) 
  : m_fd(file_desc)
{
}

ClockGenerator::~ClockGenerator()
{
}

bool 
ClockGenerator::InReset()
{
  unsigned long reg;
  read(clkgen_reg_status, &reg);
  return (bool)((reg >> 1) & 0x1);
}

bool 
ClockGenerator::IsLocked()
{
  unsigned long reg;
  read(clkgen_reg_status, &reg);
  return (bool)((reg >> 0) & 0x1);
}

int 
ClockGenerator::SetRate(unsigned long rate, unsigned long clknum, unsigned long parent_rate)
{
  unsigned long d = 0;
  unsigned long m = 0;
  unsigned long dout = 0;
  unsigned long nocount = 0;
  unsigned long high = 0;
  unsigned long edge = 0;
  unsigned long low = 0;
  unsigned long filter = 0;
  unsigned long lock = 0;
  
  if (parent_rate == 0 || rate == 0)
    return 0;
  
  calc_params(parent_rate, rate, &d, &m, &dout);
  
  if (d == 0 || dout == 0 || m == 0) 
    return 0;
  
  filter = lookup_filter(m - 1);
  lock = lookup_lock(m - 1);
  
  write(clkgen_reg_update_enable, 0);
  
  calc_clk_params(dout, &low, &high, &edge, &nocount);
  write((clknum*2)+clkgen_reg_clkout0_1, (high << 6) | low);
  write((clknum*2)+clkgen_reg_clkout0_2, (edge << 7) | (nocount << 6));
  
  calc_clk_params(d, &low, &high, &edge, &nocount);
  write(clkgen_reg_clk_div, (edge << 13) | (nocount << 12) | (high << 6) | low);
  
  calc_clk_params(m, &low, &high, &edge, &nocount);
  write(clkgen_reg_clk_fb_1, (high << 6) | low);
  write(clkgen_reg_clk_fb_2, (edge << 7) | (nocount << 6));
  
  write(clkgen_reg_lock_1, lock & 0x3FF);
  write(clkgen_reg_lock_2, (((lock >> 16) & 0x1f) << 10) | 0x1);
  write(clkgen_reg_lock_3, (((lock >> 24) & 0x1f) << 10) | 0x3e9);
  write(clkgen_reg_filter_1, filter >> 16);
  write(clkgen_reg_filter_2, filter);
  write(clkgen_reg_update_enable, 1);
  
  return 0;
}

unsigned long 
ClockGenerator::GetRate(unsigned int clknum, unsigned long parent_rate)
{
  unsigned long d, m, dout;
  unsigned long reg;
  unsigned long long tmp;
  
  read((clknum*2)+clkgen_reg_clkout0_1, &reg);
  dout = (reg & 0x3f) + ((reg >> 6) & 0x3f);
  read(clkgen_reg_clk_div, &reg);
  d = (reg & 0x3f) + ((reg >> 6) & 0x3f);
  read(clkgen_reg_clk_fb_1, &reg);
  m = (reg & 0x3f) + ((reg >> 6) & 0x3f);
  
  if (d == 0 || dout == 0) 
    return 0;
  
  tmp = (unsigned long long)(parent_rate / d) * m;
  tmp = tmp / dout;
  
  if (tmp > 0xFFFFFFFFLL)
    return 0xFFFFFFFF;
  return (unsigned long)tmp;
}

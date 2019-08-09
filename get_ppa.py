#! /usr/bin/env python3

from pathlib import Path
from re import compile as regex


class NotFound(Exception):
    pass


def find(filename, *patterns):
    '''
    Search through the named file's lines, matching regex patterns.
    The patterns should occur in order on subsequent lines,
    and each should have one matching group.
    If successful, return a list containing matches in order.
    Otherwise return None.
    '''
    matched = []
    with open(filename) as lines:
        for line in lines:
            if patterns:
                match = patterns[0].match(line)
                if match:
                    matched.append(match.group(1))
                    patterns = patterns[1:]
            else:
                return matched


def get_power(power_rpt):
    '''
    Extract the estimated power used by CLB logic from a Vivado power report.
    This is a weak estimate, in part because it doesn't model realistic workloads.

...
1.1 On-Chip Components
----------------------

+--------------------------+-----------+----------+-----------+-----------------+
| On-Chip                  | Power (W) | Used     | Available | Utilization (%) |
+--------------------------+-----------+----------+-----------+-----------------+
| Clocks                   |     0.387 |       42 |       --- |             --- |
| CLB Logic                |     0.151 |   305881 |       --- |             --- |
...                              ^^^^^
                                 this number
    '''
    pattern = regex(r'^\| CLB Logic +\| +(\d+\.\d+) \|')
    found = find(power_rpt, pattern)
    if found:
        return {'power_W': float(found[0])}
    else:
        raise NotFound('CLB Logic in {}'.format(power_rpt))


def get_cpu_clock(timing_rpt):
    '''
    Extract the processor core clock frequency from a Vivado timing report.
    Assumes that the design uses the GFE clock tree.

...
----------------------------- ...
| Clock Summary
| -------------
----------------------------- ...

Clock                         ...  Waveform(ns)           Period(ns)      Frequency(MHz)
-----                         ...  ------------           ----------      --------------
dbg_hub/inst/BSCANID.u_xsdbm_i...  {0.000 25.000}         50.000          20.000          
default_250mhz_clk1_clk_p     ...  {0.000 2.000}          4.000           250.000         
  mmcm_clkout0                ...  {0.000 1.667}          3.333           300.000         
    pll_clk[0]                ...  {0.000 0.208}          0.417           2400.000        
      pll_clk[0]_DIV          ...  {0.000 1.667}          3.333           300.000         
    pll_clk[1]                ...  {0.000 0.208}          0.417           2400.000        
      pll_clk[1]_DIV          ...  {0.000 1.667}          3.333           300.000         
    pll_clk[2]                ...  {0.000 0.208}          0.417           2400.000        
      pll_clk[2]_DIV          ...  {0.000 1.667}          3.333           300.000         
  mmcm_clkout1                ...  {0.000 20.000}         40.000          25.000          
...                                                                       ^^^^^^
                                                                          this number
    '''
    pattern = regex(r'^  mmcm_clkout1 .* (\d+\.\d+) +$')
    found = find(timing_rpt, pattern)
    if found:
        return {'cpu_Mhz': float(found[0])}
    else:
        raise NotFound('mmcm_clkout1 in {}'.format(timing_rpt))


def get_utilization(util_rpt):
    '''
    Extract the number of CLB LUTs and CLB registers from a Vivado utilization report.
    They indicate design complexity, and are a rough proxy for the area of an ASIC.

...
1. CLB Logic
------------

+----------------------------+--------+-------+-----------+-------+
|          Site Type         |  Used  | Fixed | Available | Util% |
+----------------------------+--------+-------+-----------+-------+
| CLB LUTs                   | 146578 |     0 |   1182240 | 12.40 |
                               ^^^^^^
|   LUT as Logic             | 141704 |     0 |   1182240 | 11.99 |
|   LUT as Memory            |   4874 |     0 |    591840 |  0.82 |
|     LUT as Distributed RAM |   3524 |     0 |           |       |
|     LUT as Shift Register  |   1350 |     0 |           |       |
| CLB Registers              | 121495 |     2 |   2364480 |  5.14 |
...                            ^^^^^^
                               these two numbers
    '''
    lut_pat = regex(r'^\| CLB LUTs +\| +(\d+) \|')
    reg_pat = regex(r'^\| CLB Registers +\| +(\d+) \|')
    found = find(util_rpt, lut_pat, reg_pat)
    if found:
        return {"CLB_LUTs": int(found[0]),
                "CLB_regs": int(found[1])}
    else:
        raise NotFound('CLB LUTs and Registers in {}'.format(util_rpt))


def named_in(path_list, name_fragment):
    # raise a ValueError if path_list doesn't include exactly one
    # path with a filename containing name_fragment
    [p] = [p for p in path_list if name_fragment in p.stem]
    return p


def get_ppa(dirname):
    dirpath = Path(dirname)
    reports = [f for f in dirpath.iterdir() if f.suffix == '.rpt']
    pwr_rpt = named_in(reports, 'power')
    utl_rpt = named_in(reports, 'utilization')
    tmg_rpt = named_in(reports, 'timing')

    power = get_power(pwr_rpt)
    utlzn = get_utilization(utl_rpt)
    clock = get_cpu_clock(tmg_rpt)

    return dict(**power, **utlzn, **clock)


if __name__ == '__main__':
    from json import dumps
    from sys import argv
    if len(argv) == 2 and Path(argv[1]).is_dir():
        print(dumps(get_ppa(argv[1])))
    else:
        print("Usage: {} [Vivado report directory]".format(argv[0]))

#!/usr/bin/env python
"""Script to run a compiled elf on the GFE
"""

import argparse
import gfetester
import os
import time

# Parse the input binary and other arguments
parser = argparse.ArgumentParser(description='Run a binary test on the GFE.')
parser.add_argument(
    "binary",
    help="path to a RISCV elf", metavar="FILE",
    type=str)
parser.add_argument(
    "--runtime",
    help="Seconds of wait time while running the program on the gfe",
    default=0.5,
    type=float)
args = parser.parse_args()

# Validate the inputs
if not os.path.exists(args.binary):
    raise Exception("Path {} does not exist".format(args.binary))

gfe = gfetester.gfetester()

# Start gdb and reset the processor
gfe.startGdb()
gfe.softReset()

# Setup pySerial UART
gfe.setupUart(
    timeout = 1,
    baud=115200,
    parity="NONE",
    stopbits=2,
    bytesize=8)
gfe.launchElf(binary=args.binary)

# Test sleeps for specified amount of time
time.sleep(args.runtime)

# Receive from UART and print 
num_rxed =  gfe.uart_session.in_waiting
rx = gfe.uart_session.read( num_rxed ) 
print("\nReceived: {}".format(rx))
gfe.gdb_session.interrupt()

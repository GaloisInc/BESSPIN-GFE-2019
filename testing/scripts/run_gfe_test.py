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
tohost_desc = "tohost address. Memory address containing the "
tohost_desc += "passing condition of a test"
parser.add_argument(
    "--tohost",
    help=tohost_desc,
    default=0x80001000,
    type=int)
parser.add_argument(
    "--runtime",
    help="Seconds of wait time while running the program on the gfe",
    default=0.5,
    type=float)
parser.add_argument(
    "--gdblog", help="print gdb log",
    action="store_true")
parser.add_argument(
    "--openocdlog", help="print openOCD log",
    action="store_true")
args = parser.parse_args()

# Validate the inputs
if not os.path.exists(args.binary):
    raise Exception("Path {} does not exist".format(args.binary))

# Gdb into the GFE
gfe = gfetester.gfetester()
(passed, msg) = gfe.runElfTest(binary=args.binary, runtime=args.runtime,
    tohost=args.tohost)

# Print the result
print(
    "Test {} {} after running for {} seconds".format(
        args.binary, msg, args.runtime))

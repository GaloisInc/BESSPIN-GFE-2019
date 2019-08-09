#!/bin/bash
# Simple programming script for GFE
# Usage:
# ./program_fpga.sh <chisel|bluespec> [override bitfile location]
#
# Only first argument is required. Second argument will force an override of
# the default bitstream location. Path can either be relative to current folder
# or absolute.
#

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source $BASE_DIR/setup_env.sh

proc_picker $1

bitfile=./bitstreams/soc_${proc_name}.bit
probfile=./bitstreams/soc_${proc_name}.ltx

if [ "a$2" != "a" ]
then
    echo "INFO: Overriding default bit file with given path: $2"
    bitfile=$2
fi

check_file $bitfile "Could not locate bitstream at $bitfile"
check_file $probfile "Could not locate probe file at $probfile"

check_command vivado_lab
err_msg $SETUP_ENV_ERR "program_fpga.sh: Programming the FPGA failed"
vivado_lab -nojournal -notrace -nolog -source ./tcl/prog_bit.tcl -mode batch -tclargs $bitfile $probfile

# Clean up webtalk logs
if [ -f webtalk.log ]; then
  rm webtalk.log
  rm webtalk.jou
fi

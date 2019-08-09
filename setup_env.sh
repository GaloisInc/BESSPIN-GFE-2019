#!/usr/bin/env bash

# Get the path to the root folder of the git repository
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
SETUP_ENV_ERR=0

# Check that the required tools are on the users path
function check_command {
	if ! [ -x "$(command -v $1)" ]; then
		echo "Error: $1 is not found. Please add it to your path." >&2
		SETUP_ENV_ERR=1
	fi
}

check_command openocd
check_command riscv64-unknown-elf-gcc
check_command riscv64-unknown-linux-gnu-gcc
check_command riscv32-unknown-elf-gcc

function err_msg {
	if [[ $1 -ne 0 ]]
	then
		echo $2
		exit 1
	else
		echo $3
	fi
}

function check_file {
	if [ ! -f $1 ]; then
		echo $2
		exit 1
	fi
}

function proc_usage {
    echo "Usage: $0 [chisel_p1|chisel_p2|chisel_p3|bluespec_p1|bluespec_p2|bluespec_p3]"
    echo "Please specify a bluespec or chisel processor!"
}

function proc_picker {
	# Parse the processor selection
	if [ "$1" == "bluespec_p1" ]; then
	        proc_name="bluespec_p1"
	elif [ "$1" == "bluespec_p2" ]; then
	        proc_name="bluespec_p2"
	elif [ "$1" == "bluespec_p3" ]; then
	        proc_name="bluespec_p3"
	elif [ "$1" == "chisel_p1" ]; then
	        proc_name="chisel_p1"
	elif [ "$1" == "chisel_p2" ]; then
	        proc_name="chisel_p2"
	elif [ "$1" == "chisel_p3" ]; then
	        proc_name="chisel_p3"
	else
	        proc_usage
	        exit -1
	fi
}

function proc_xlen_usage {
        echo "Usage: $0 [32|64]"
        echo "Please specify a 32 or 64 bit processor!"
}

function xlen_picker {
	# Parse the processor selection
	if [ "$1" == "32" ]; then
	        XLEN="32"
	elif [ "$1" == "64" ]; then
	        XLEN="64"
	else
	        proc_xlen_usage
	        exit -1
	fi
}

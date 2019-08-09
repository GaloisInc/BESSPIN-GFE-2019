#!/usr/bin/env bash

function runOnLinux_usage {
    echo "Usage: $0 [--debug] proc_name linux_image prog_to_run [--FastForward]"
    echo "Usage: $0 [--debugOnly] proc_name linux_image [--FastForward]"
    echo "Usage: $0 --help"
}

function runOnLinux_args {
    if [ "$1" == "--debug" ] ; then
        if [ $# -lt 4 ] || [ $# -gt 5 ] ; then runOnLinux_usage; exit; fi
        isDebug=1
        proc_picker $2
        linux_picker $3
        isProg=1
        progToRun=$4
        check_file $progToRun "$0: Error: $progToRun is not found."
        checkMode $5
    elif [ "$1" == "--debugOnly" ] ; then
        if [ $# -lt 3 ] || [ $# -gt 4 ] ; then runOnLinux_usage; exit; fi
        isDebug=1
        proc_picker $2
        linux_picker $3
        isProg=0
        checkMode $4
    else
        isDebug=0
        isProg=1
        if [ "$1" == "--help" ] || [ $# -lt 3 ] ; then runOnLinux_usage; exit; fi
        proc_picker $1
        linux_picker $2
        progToRun=$3
        check_file $progToRun "$0: Error: $progToRun is not found."
        checkMode $4
    fi
}

function proc_linux_usage {
    echo "Usage: $0 linux_image = [busybox|debian]"
}

function linux_picker {
	# Parse the processor selection
	if [ "$1" == "debian" ]; then
	        linux_image="debian"
	elif [ "$1" == "busybox" ]; then
	        linux_image="busybox"
	else
        proc_linux_usage
        exit -1
	fi
}

function checkMode {
    if [ "$1" == "--FastForward" ]; then
        isFastForward=1
        doSkipFPGA=1
    elif [ "$1" == "--SkipFPGA" ]; then
        isFastForward=0
        doSkipFPGA=1
    else
        isFastForward=0
        doSkipFPGA=0
    fi
}

source ../setup_env.sh

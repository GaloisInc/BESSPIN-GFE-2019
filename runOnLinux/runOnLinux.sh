#!/usr/bin/env bash

#### Environment setup and verifying parameters
echo "$0: Setting up the environment.."

source setup_env.sh

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

err_msg $SETUP_ENV_ERR "Sourcing setup_env.sh failed"

runOnLinux_args "$@"

if [ ${proc_name: -1} -eq 1 ]; then 
    xlen_picker 32
    err_msg 1 "$0: NotImplementedError: runOnLinux is not implemented for P1 processors."
else 
    xlen_picker 64
fi

if [ $isProg -eq 1 ]; then
    #### Cross compiling the user C file
    echo "$0: Cross compiling $progToRun.."
    make clean 
    make PROG=$progToRun XLEN=$XLEN
    err_msg $? "$0: Cross compiling $progToRun failed"
fi

#### Building linux and programming the FPGA
if [ $isFastForward -ne 1 ]; then
    echo "$0: Building the linux [$linux_image] image.."
    linux_folder=$BASE_DIR/../bootmem/
    cd $linux_folder
    if [ "$linux_image" == "debian" ]; then
        make debian
    else
        make
    fi
    err_msg $? "Building Linux failed."

    echo "$0: Programming the FPGA.."
    cd ..
    ./program_fpga.sh $proc_name
    err_msg $? "$0: Programming the FPGA failed"
    sleep 1
else
    echo "$0: FastForward mode is activated."
    echo "$0: Assuming linux is up on the FPGA."
fi

#### Booting linux on the FPGA
echo "$0: Booting $linux_image on the FPGA.."
cd $BASE_DIR/../testing/scripts/
if [ $isDebug -ne 1 ]; then
    python runOnLinux.py RunOnLinux.test_${linux_image}_runAprog
elif [ $isProg -ne 1 ] ; then
    python runOnLinux.py RunOnLinux.test_${linux_image}_terminal
else
    python runOnLinux.py RunOnLinux.test_${linux_image}_runANDterminal
fi
err_msg $? "$0: Running on Linux failed."
echo "$0: Running on Linux ran successfully."
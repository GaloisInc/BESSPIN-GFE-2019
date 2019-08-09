#!/usr/bin/env bash

# Get the path to the root folder of the git repository
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source $BASE_DIR/setup_env.sh

proc_picker $1

PRJNAME=soc_${proc_name}
BITFILE=$BASE_DIR/vivado/${PRJNAME}/${PRJNAME}.runs/impl_1/design_1.bit
LTXFILE=$BASE_DIR/vivado/${PRJNAME}/${PRJNAME}.runs/impl_1/design_1.ltx
PRJFILE=${PRJNAME}/${PRJNAME}.xpr
REVMEMFILE=$BASE_DIR/bootrom/bootrom.bytereversed.mem

check_file $BITFILE "Error! Cannot find bit file at $BITFILE"
check_file $LTXFILE "Error! Cannot find LTX file at $LTXFILE"
check_file vivado/$PRJFILE "Error! Cannot find Vivado Project file at vivado/$PRJFILE"

# Generate the MMI necessary for finding the memory
echo "Running Vivado to extract memory information..."
cd $BASE_DIR/vivado
vivado -mode batch -nojournal -nolog -notrace -source ../tcl/update_bootrom.tcl $PRJFILE
err_msg $? "Error! Extracting memory information failed!"

echo "Updating memory with data from $REVMEMFILE"
updatemem -force --meminfo $BASE_DIR/vivado/blk_mem_gen_0.mmi \
--data $REVMEMFILE \
--bit $BITFILE --proc dummy -debug \
-out $BASE_DIR/bitstreams/design_1_bootrom.bit
err_msg $? "Error! Updating memory failed!"

cp $LTXFILE $BASE_DIR/bitstreams/design_1_bootrom.ltx
echo "Success! New bit file can found at $BASE_DIR/bitstreams/design_1_bootrom.bit"


#!/usr/bin/env bash

# Get the path to the script folder of the git repository
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source $BASE_DIR/setup_env.sh
err_msg $SETUP_ENV_ERR "Sourcing setup_env.sh failed"
cd $BASE_DIR/testing/scripts

freertos_folder=$BASE_DIR/FreeRTOS-mirror/FreeRTOS/Demo/RISC-V_Galois_P1/
python_unittest_script=test_gfe_unittest.py
bootmem_folder=$BASE_DIR/bootmem/


function proc_freertos_usage {
    echo "Usage: $0"
    echo "Usage: $0 --ethernet"
    echo "Usage: $0 --flash proc_name [blinky|full|path_to_elf]"
    echo "Add --ethernet if you want to test ethernet on Linux"
    echo "Add --flash if you want to program the image into flash and boot from it"
    echo "	choose between main_full or main_blinky or provide a path to an elf file"
    echo "	default is main_blinky if no option was provided"
}

function freertos_test {
	cd $freertos_folder
	make clean; PROG=$1 make
	err_msg $? "Building FreeRTOS-RISCV PROG=$1 test failed"

	cd $BASE_DIR/testing/scripts
	python $python_unittest_script TestFreeRTOS.$2
	err_msg $? "FreeRTOS test TestFreeRTOS.$2 failed"
}

if [[ $1 == "--flash" ]]; then
	use_flash=true
	test_ethernet=false
	full_ci=false
	proc_picker $2
	if [ $# -lt 3 ]; then
		echo "test_freertos.sh: No flash image was specified. Using \"main_blinky.elf\" by default."
		flash_option="blinky"
	elif [[ $3 == "full" ]]; then
		echo "test_freertos.sh: Flash image \"main_full.elf\"."
		flash_option="full"
	elif [[ $3 == "blinky" ]]; then
		echo "test_freertos.sh: Flash image \"main_blinky.elf\"."
		flash_option="blinky"
	elif [[ ! -f ${BASE_DIR}/$3 ]]; then
		err_msg 1 "test_freertos.sh: Flash image $3 cannot be found."
	else
		flash_option=${BASE_DIR}/$3
		echo "test_freertos.sh: Flash image \"$3\"."
	fi
elif [[ $1 == "--ethernet" ]]; then
	use_flash=false
	test_ethernet=true
	full_ci=false
elif [[ $1 == "--full_ci" ]]; then
	test_ethernet=false
	use_flash=false
	full_ci=true
else
	test_ethernet=false
	use_flash=false
	full_ci=false
fi

if [ "$test_ethernet" = true ]; then
	freertos_test main_udp test_udp
	sleep 10
	freertos_test main_tcp test_tcp
	sleep 10
elif [ "$use_flash" = true ]; then
	#Fetching the specified elf file
	if [[ $flash_option == "full" ]] || [[ $flash_option == "blinky" ]]; then
		cd $freertos_folder
		make clean; PROG=main_$flash_option make
		err_msg $? "Building FreeRTOS-RISCV PROG=main_$flash_option failed"
		cp main_$flash_option.elf $bootmem_folder/freertos.elf
	else
		cp $3 $bootmem_folder/freertos.elf
	fi
	#Making the FreeRTOS binary image <bootmem.bin>
	cd $bootmem_folder
	make -f Makefile.freertos clean
	make -f Makefile.freertos
	#Programming the flash
	cd $BASE_DIR/testing/scripts/
	echo "test_freertos.sh: Programming flash with FreeRTOS image"
	python test_upload_flash.py
	err_msg $? "test_freertos.sh: Programming flash failed" "test_freertos.sh: Programming flash OK"
	#[Re-]Programming the fpga
	cd $BASE_DIR
	echo "test_freertos.sh: Programming FPGA with a bitstream after a flash upload"
	./program_fpga.sh $proc_name
	err_msg $? "test_freertos.sh: Programming the FPGA failed" "test_freertos.sh: Programming the FPGA OK"
	#Need to sleep before the test to leave enough time for FreeRTOS to boot from flash
	sleep 10
	#The Test itself
	if [[ $flash_option == "full" ]] || [[ $flash_option == "blinky" ]]; then
		cd $BASE_DIR/testing/scripts
		python $python_unittest_script TestFreeRTOS.test_flash_$flash_option
		err_msg $? "FreeRTOS test TestFreeRTOS.test_flash_$flash_option failed"
	else
		echo "test_freertos.sh: No test available for $flash_option. Please test accordingly."
	fi
elif [ "$full_ci" = true ]; then
	# Disaling for now, the PMOD header has difficulty pulling the line down
	#freertos_test main_gpio test_gpio
	freertos_test main_uart test_uart
	sleep 10
	freertos_test main_iic test_iic
	sleep 10
	freertos_test main_sd test_sd
	sleep 10
else
	freertos_test main_blinky test_blink
	sleep 10
	freertos_test main_full test_full
	sleep 10
fi

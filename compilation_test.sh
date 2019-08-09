#!/bin/bash
cd FreeRTOS-mirror/FreeRTOS/Demo/RISC-V_Galois_P1/
TARGETS="main_blinky main_full main_iic main_gpio main_tcp main_udp main_sd main_uart"
for TARGET in $TARGETS
do
    echo $TARGET
    export PROG=$TARGET
    make clean
    if [ $? -gt 0 ]
    then
        exit 1
    fi
    make
    if [ $? -gt 0 ]
    then
        exit 1
    else
        make clean
    fi
done
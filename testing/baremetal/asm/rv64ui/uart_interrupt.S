# See LICENSE for license details.

#*****************************************************************************
# uart.S
#-----------------------------------------------------------------------------
#
# Test add instruction.
#

#include "riscv_test.h"
#include "test_macros.h"
#include "gfe_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # SETUP RISCV Interrupt 
  #-------------------------------------------------------------

  #-------------------------------------------------------------
  # SETUP PLIC 
  #-------------------------------------------------------------

plic_setup:
  # Disable lowest interrupts
  li t0, PLIC_BASE
  li t1, PLIC_ENABLE_OFFSET
  add t2, t0, t1
  li t3, 0x0
  sw t3, 0(t2)

  # Set the priority bits
  li t1, PLIC_PRIORITY_OFFSET
  add t2, t0, t1
  li t3, 0x1
  sw t3, 0(t2) 
  sw t3, 4(t2) 
  sw t3, 8(t2) 
  sw t3, 0xc(t2) 

  # Enable the first global (uart 0)
  li t1, PLIC_ENABLE_OFFSET
  add t2, t0, t1
  li t3, 0xfff
  sw t3, 0(t2) 

  #-------------------------------------------------------------
  # SETUP UART 
  #-------------------------------------------------------------

uart_setup:
  li t0, UART_BASE

  # UART_LCR = 0x80
  # This configures the DLAB bit, which allows writing into the Divisor Latch 
  # least significant and most significant bytes.
  li t1, 0x80
  addi t3, t0, UART_LCR
  sw t1, 0(t3)
  # Write to the Divisor Latch least significant byte and write
  # to the Divisor Latch most significant byte in that order.
  li t1, UART_DLL_VAL 
  addi t3, t0, UART_DLL
  sw t1, 0(t3)
  li t1, UART_DLM_VAL
  addi t3, t0, UART_DLM
  sw t1, 0(t3)
  
  # UART_LCR = 0x1F
  # This configures word length to 8 bits,
  # number of stop bits to 2, parity is enabled and set to even parity and the 
  # DLAB bit is set to 0 to enable the use of the Transmitter Holding register
  # and Receiver Buffer register data for transmission and reception
  li t1, 0x1F
  addi t3, t0, UART_LCR
  sw t1, 0(t3)

  #-------------------------------------------------------------
  # Interrupt Test
  #-------------------------------------------------------------

  # Enable receive data available interrupt
  li t1, UART_IER_ERBFI
  addi t3, t0, UART_IER
  sw t1, 0(t3)

  li t1, 0x30
  addi t2, t0, UART_BUFFER

  # Enable MEI interrupt
  li t3, 0x800
  csrw mie, t3

  # Loop forever, waiting for interrupt and sending back 0xAA
wait_for_interrupt:

  # Check if interrupt is set
  csrr t4, mip
  and t4, t4, t3 # t4 & 0x800
  beq t4, x0, wait_for_interrupt

handle_interrupt:
  # Claim the interrupt in the plic by reading from the claim register
  li t0, PLIC_BASE
  li t1, PLIC_CLAIM_OFFSET
  add t2, t0, t1
  lw t3, 0(t2)
  beq t3, x0, fail

  # Read from the uart buffer to clear the interrupt
  lw t4, 0(t2)
  fence

  # Transmit the success code back to the tester
  sw t1, 0(t2)
  fence
  addi t1, t1, 1

wait_for_clear:
  csrr t4, mip
  and t4, t4, t3
  bne t4, x0, wait_for_clear
  j wait_for_interrupt

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END

# See LICENSE for license details.

#*****************************************************************************
# soft_reset.S
#-----------------------------------------------------------------------------
#
# Send soft reset command to GFE reset controller.
#
# NOTE: This does NOT actually perform a "test" - there is no return value. It
# only resets the GFE, including the core
#

#include "riscv_test.h"
#include "test_macros.h"
#include "gfe_macros.h"

.section .text.init
.align  6
.globl _start

_start:                    
  #-------------------------------------------------------------
  # SEND RESET COMMAND
  #-------------------------------------------------------------
  GFE_SOFT_RESET

  # Should never actually reach this point
  RVTEST_FAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END

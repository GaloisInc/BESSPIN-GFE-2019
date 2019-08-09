#include <stdio.h>
#include <stdint.h>
#include "riscv_counters.h"

int verify () {
	// Write code to verify that the test has executed properly here
	return 1;
}

int main (int argc, char *argv[])
{
	// -------------------------------------------------------------------------
	// This is where your test code goes
	//
	//
	// -------------------------------------------------------------------------

	// -------------------------------------------------------------------------
	// This is where you check the results. The verify function defined above is
	// where you write your code to verify that the results are correct. Based
	// on the output of the verify function, you declare the test as TEST_PASS
	// or TEST_FAIL. These are assembly helper routines which write to the x28
	// register with a pre-set code which is understood by the gdb routine. The
	// code for this is in the file ../../lib/riscv_counters.h

	if (verify ()) {
		TEST_PASS
	} else {
		TEST_FAIL
	}
	// -------------------------------------------------------------------------
	return 0;
}

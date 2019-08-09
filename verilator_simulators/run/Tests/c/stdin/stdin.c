#include <stdio.h>
#include <stdint.h>
#include "riscv_counters.h"

int verify (void) {
	// Write code to verify that the test has executed properly here
	return 1;
}

int main (int argc, char *argv[])
{
	// -------------------------------------------------------------------------
	// This is where your test code goes
    char some_char;
    char some_string[80];
    int some_number;
    
    printf ("This test checks the CONSOLE-IN feature.\n");
    printf ("This is not a self-checking test. ");
    printf ("Please inspect results visually.\n");

    printf ("Enter a character\n");
    scanf ("%c", &some_char);
    printf ("Enter a string (less than 80 characters)\n");
    //scanf ("%[^\n]s", some_string);
    scanf ("%s", some_string);
    printf ("Enter an integer\n");
    scanf ("%d", &some_number);

    printf ("The character you entered is: %c\n", some_char);
    printf ("The string you entered is: %s\n", some_string);
    printf ("The number you entered is: %d\n", some_number);
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

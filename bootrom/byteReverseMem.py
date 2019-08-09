#!/usr/local/bin/python
# Reverse byte order of a .mem file
import sys

def reverseMemLine(mem_line):
    # Don't reverse address lines
    if("@" in mem_line):
        return mem_line.rstrip()

    reversed_line = ""
    hex_values = mem_line.split()
    for value in hex_values:
        # Flip the byte order for the .mem format
        n = 2
        byte_chars = [value[i:i+2] for i in range(0, len(value), n)]
        byte_chars = byte_chars[::-1]
        reversed_line = "".join(byte_chars)
    return reversed_line 

def reverseMemContents(mem_contents):
    reversed_contents = ""
    for line in mem_contents.splitlines():
        reversed_contents += reverseMemLine(line) + "\n"
    return reversed_contents

def main():
    for line in sys.stdin:
        print(reverseMemLine(line))

if __name__ == '__main__':
    main()

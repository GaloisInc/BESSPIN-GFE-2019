#!/usr/local/bin/python
import codecs
codecs.getencoder('hex')(b'foo')[0]

fin = "bootrom.hex"
fout = "bootrom.coe"

mem_header = """memory_initialization_radix=16;
memory_initialization_vector="""
mem_string = ""
mem_string += mem_header + "\n"

with open(fin, "r") as f:
    for line in f:
        hex_values = line.split()
        for value in hex_values:
            mem_string += value
            mem_string += ",\n"

mem_string = mem_string[:-2] + ";"

print(mem_string)
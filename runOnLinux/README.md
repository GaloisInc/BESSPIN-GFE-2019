# Run a program above linux on the FPGA #
Use the script `runOnLinux.sh` to run a user-chosen C file above linux on FPGA. 
Usage is as follows:
`echo "Usage: $0 [--debug] proc_name linux_image prog_to_run [--FastForward]"`
`echo "Usage: $0 [--debugOnly] proc_name linux_image [--FastForward]"`
`echo "Usage: $0 --help"`

The `--debug` mode leaves an interactive terminal open with the processor. The `--debugOnly` mode only opens an interactive terminal without running any programs.

This is a list of the interpreter commands [All starting with `--`]:
- `--exit`: closes the interactive terminal and exists the program.
- `--ctrlc`: sends a Ctrl+C to the linux running on RISCV.
- `--sput [-ft] sourceFile destFile`: transmits a file from the server to the linux on RISCV.

Supported processors:
- Chisel P2
- Bluespec P2

Supported linux systems:
- Busybox
- Debian


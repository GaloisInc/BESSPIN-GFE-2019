# Government Furnished Equipment (GFE) #

[![pipeline status](https://gitlab-ext.galois.com/ssith/gfe/badges/develop/pipeline.svg)](https://gitlab-ext.galois.com/ssith/gfe/commits/develop)

Source files and build scripts for generating and testing the GFE for SSITH.

Please refer to the [GFE System Description pdf](GFE_Rel4_System_Description.pdf)
for a high-level overview of the system.

## Table of contents ##

- [Getting Started](#getting-started)
  - [Setup OS (Debian Buster)](#setup-os-debian-buster)
  - [Install Vivado](#install-vivado)
  - [Clone this Repo](#clone-this-repo)
  - [Update Dependencies](#update-dependencies)
  - [Building the Bitstream](#building-the-bitstream)
  - [Storing a Bitstream in Flash](#storing-a-bitstream-in-flash)
  - [Testing](#testing)
- [Simulation](#simulation)
- [Manually Running FreeRTOS](#manually-running-freertos)
  - [Running FreeRTOS + TCP/IP stack](#running-freertos-tcp-ip-stack)
- [Running Linux - Debian or Busybox](#running-linux-debian-or-busybox)
  - [Creating Debian Image](#creating-debian-image)
  - [Creating Busybox Image](#creating-busybox-image)
    - [Build the memory image](#build-the-memory-image)
    - [Load and run the memory image](#load-and-run-the-memory-image)
  - [Using Ethernet on Linux](#using-ethernet-on-linux)
  - [Storing a boot image in Flash](#storing-a-boot-image-in-flash)
- [Adding in Your Processor](#adding-in-your-processor)
  - [Modifying the GFE](#modifying-the-gfe)
- [Rebuilding the Chisel and Bluespec Processors](#rebuilding-the-chisel-and-bluespec-processors)
- [Tandem Verification](#tandem-verification)
  - [Establishing the PCIe Link](#establishing-the-pcie-link)
  - [Installing Bluespec](#installing-bluespec)
  - [Licensing](#licensing)
  - [Capturing a Trace](#capturing-a-trace)
  - [Comparing a Trace](#comparing-a-trace)


## Getting Started ##

To update from a previous release, please follow the instructions below,
starting with [Update Dependencies](#update-dependencies).

Prebuilt images are available in the bitstreams folder.
Use these, if you want to quickly get started.
This documentation walks through the process of building and testing a bitstream.
It suggests how to modify the GFE with your own processor.


### Setup OS (Debian Buster) ###

Before installing the GFE for the first time,
please perform a clean install of [Debian 10 ("Buster")](https://www.debian.org/releases/buster/)
on the development and testing hosts.
This is the supported OS for building and testing the GFE.
At the time of release 1 (Feb 1), Debian Buster Alpha 4 was the latest version,
but we expect to upgrade Buster to the stable release version when it is available.


### Install Vivado ###

Download and install Vivado 2017.4. A license key for the tool is included on a piece of paper in the box containing the VCU118. See Vivado [UG973](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2017_4/ug973-vivado-release-notes-install-license.pdf) for download and installation instructions. The GFE only requires the Vivado tool, not the SDK, so download the `Vivado Design Suite - HLx 2017.4 ` from the [Vivado Download Page](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2017-4.html). You must make an account with Vivado in order to register the tool and install the license. After installing Vivado, you must also install libtinfo5 for Debian to run the tool. Install this dependency by running `sudo apt-get install libtinfo5`.

If using separate development and testing machines, only the development machine needs a license. We recommend installing Vivado Lab on the testing machine, because it does not require a license and can be used to program the FPGA.


### Clone this Repo ###

Once the OS is installed, you will need to
[add an ssh key](https://gitlab-ext.galois.com/profile/keys)
to your Galois Gitlab account in order to clone the GFE repo.
These [instructions](https://docs.gitlab.com/ee/ssh/#adding-an-ssh-key-to-your-gitlab-account) have more details.

After setting up an ssh key, clone this repo by running
```bash
git clone git@gitlab-ext.galois.com:ssith/gfe.git
cd gfe
```


### Update Dependencies ###

If you are updating from an earlier release or development version of the GFE,
first run
```bash
git pull origin master
```
in the GFE repo's root directory.

The GFE relies on several nested Git submodules to provide processor sources
and RISC-V development tools.
Because some of these submodules contain redundant copies of the toolchain,
we provide a script to initialize only those necessary for GFE development.

The tool-suite submodule contains a [Nix](https://nixos.org/nix/) shell environment
that builds all the tools necessary for the GFE excluding Vivado.
The argument-less `nix-shell` command relies on a configuration file in the tool-suite repo,
which is the target of the `shell.nix` symlink.
**All subsequent commands in this document should be run within the Nix shell.**
This applies to scripts within the GFE such as `test_processor.sh`.
If you wish to use your own binaries for RISCV tools,
then you should modify your PATH variable from inside the Nix shell.

If you do not have Nix installed, first follow
[these instructions](https://nixos.org/nix/manual/#sect-multi-user-installation).

Then run the following command to get the current version of all GFE dependencies.
```bash
./init_submodules.sh && nix-shell
```

*This may take several hours to complete the first time it is run*,
as it checks out several large repositories and builds an entire toolchain from source.
Subsequent runs will be fast, using the locally cached Nix packages.


### Building the Bitstream ###

To build your own bitstream, make sure Vivado 2017.4 is on your path (`$ which vivado`) and run the following commands

```bash
cd $GFE_REPO
./setup_soc_project.sh chisel_p1 # generate vivado/soc_chisel_p1/soc_chisel_p1.xpr
./build.sh chisel_p1 # generate bitstreams/soc_chisel_p1.bit
```

where GFE_REPO is the top level directory for the gfe repo. To view the project in the Vivado gui, run the following:

```bash
cd $GFE_REPO/vivado
vivado soc_chisel_p1/soc_chisel_p1.xpr
```

`setup_soc_project.sh` should only be run once. We also recommend running `build.sh` for the initial build then performing future builds using the Vivado GUI to take advantage of convenient error reporting and visibility into the build process. The Vivado project will be generated in the `$GFE_REPO/vivado/soc_$proc_name` folder of the repository and can be re-opened there. Note that all the same commands can be run with the argument `bluespec_p1` to generate the bluespec P1 bitstream and corresponding Vivado project (i.e. `./setup_soc_project.sh bluespec_p1`).


### Storing a Bitstream in Flash ###

See [flash-scripts/README](flash-scripts/README) for directions on how to write a bitstream to flash on the VCU118. 
This is optional, and allows the FPGA to be programmed from flash on power-up.

### Testing ###

We include some automated tests for the GFE.
The `test_processor.sh` script programs the FPGA with an appropriate bitstream, tests the GDB connection to the FPGA then runs the appropriate ISA and operating system tests.
To check that you have properly setup the GFE, or to test a version you have modified yourself, run the following steps:

1. Give the current user access to the serial and JTAG devices.
```bash
sudo usermod -aG dialout $USER
sudo usermod -aG plugdev $USER
sudo reboot
```
2. Connect micro USB cables to JTAG and UART on the the VCU118. This enables programming, debugging, and UART communication.
3. Make sure the VCU118 is powered on (fan should be running) 
4. Add Vivado or Vivado Lab to your path (i.e. `source /opt/Xilinx/Vivado_Lab/2017.4/settings64.sh`).
5. Run `./test_processor.sh chisel_p1` from the top level of the gfe repo. Replace `chisel_p1` with your processor of choice. This command will program the FPGA and run the appropriate tests for that processor.

A passing test will not display any error messages. All failing tests will report errors and stop early.

## Simulation ##

For Verilator simulation instructions,
see [verilator_simulators/README](verilator_simulators/).
To build and run ISA tests on a simulated GFE processor, run (e.g.)
```bash
./test_simulator.sh bluespec_p1
```

## Manually Running FreeRTOS ##

To run FreeRTOS on the GFE, you'll need to run OpenOCD, connect to gdb, and view the UART output in minicom. First, install minicom and build the FreeRTOS demo.

```bash
sudo apt-get install minicom

cd FreeRTOS-mirror/FreeRTOS/Demo/RISC-V_Galois_P1

# for simple blinky demo
make clean; PROG=main_blinky make

# for full demo
make clean; PROG=main_full make
```

We expect to see warnings about memory alignment and timer demo functions when compiling.

Follow these steps to run freeRTOS with an interactive GDB session:

1. Reset the SoC by pressing the CPU_RESET button (SW5) on the VCU118 before running FreeRTOS.
2. Run OpenOCD to connect to the riscv core `openocd -f $GFE_REPO/testing/targets/ssith_gfe.cfg`.
3. In a new terminal, run minicom with `minicom -D /dev/ttyUSB1 -b 115200`. `ttyUSB1` should be replaced with whichever USB port is connected to the VCU118's USB-to-UART bridge.
Settings can be configured by running `minicom -s` and selecting `Serial Port Setup` and then `Bps/Par/Bits`. 
The UART is configured to have 8 data bits, 2 stop bits, no parity bits, and a baud rate of 115200.
4. In a new shell, run gdb with `riscv32-unknown-elf-gdb $GFE_REPO/FreeRTOS-mirror/FreeRTOS/Demo/RISC-V_Galois_P1/main_blinky.elf`, where `main_blinky` should be the name of the demo you have compiled and want to run.
5. Once gdb is open, type `target remote localhost:3333` to connect to OpenOCD. OpenOCD should give a message that it has accepted a gdb connection.
Load the FreeRTOS elf file onto the processor with `load`. To run, type `c` or `continue`.
6. When you've finished running FreeRTOS, make sure to reset the SoC before running other tests or programs.

The expected output from simple blinky test is:
```
[0]: Hello from RX
[0]: Hello from TX
[1] TX: awoken
[1] RX: received value
Blink !!!
[1]: Hello from RX
[1] TX: sent
[1]: Hello from TX
[2] TX: awoken
[2] RX: received value
Blink !!!
[2]: Hello from RX
[2] TX: sent
[2]: Hello from TX
[3] TX: awoken
[3] RX: received value
Blink !!!
...
```

The expected output from full test is:
```
Starting main_full
Pass....
```

If you see error messages, then something went wrong.

To run any `.elf` file on the GFE, you can use the `run_elf.py` script in `$GFE_REPO/testing/scripts/`. It can be run using `python run_elf.py path_to_elf/file.elf`. By default the program waits 0.5 seconds before printing what it has received from UART, but this can be changed by using the `--runtime X` argument where X is the number of seconds to wait.

### Running FreeRTOS + TCP/IP stack ###
Details about the FreeRTOS TCP/IP stack can be found [here](https://www.freertos.org/FreeRTOS-Plus/FreeRTOS_Plus_TCP/index.html). We provide a small example, demonstrating 
the DHCP, ICMP (ping), UDP and TCP functionality. The setup is little bit involved, hence it is not automated yet. The demo can also be modified to better suit your use-case.

Our setup is below:
```
----------------------------------                       ---------------------------------------
|    HOST COMPUTER               |                       |      FPGA Board                     |
|    DHCP server                 |    Ethernet cable     |      DHCP On                        |
|    IP: 10.88.88.2              |<=====================>|      IP: assumed to be 10.88.88.3   |
|    Netmask: 255.255.255.0      |                       |      MAC: 00:0A:35:04:DB:77         |
----------------------------------                       ---------------------------------------
```

If you want to replicate our setup you should:
1) Install and start a DHCP server on your host machine (make sure you configure it to service the interface that is connected to the FPGA).
A howto guide is for example [here](https://www.tecmint.com/install-dhcp-server-in-ubuntu-debian/)
2) If you have only one FPGA on the network, then you can leave the MAC address as is,
otherwise [change it](https://github.com/GaloisInc/FreeRTOS-mirror/blob/p1_release/FreeRTOS/Demo/RISC-V_Galois_P1/FreeRTOSIPConfig.h#L325) 
to the MAC address of the particular board (there is a sticker).
3) If you change the host IP, reflect the changes accordingly in [FreeRTOSIPConfig](https://github.com/GaloisInc/FreeRTOS-mirror/blob/p1_release/FreeRTOS/Demo/RISC-V_Galois_P1/FreeRTOSIPConfig.h#L315)

**Scenario 1: DHCP**

Follow the steps below:

1) Program your FPGA with a P1 bitstream: `./program_fpga.sh chisel_p1` **NOTE:** If you have already programmed the FPGA, at least restart it before continuing to make sure it is in a good state. 
2) Start openocd with `openocd -f $GFE_REPO/testing/targets/ssith_gfe.cfg`
3) Connect the FPGA Ethernet port into a router/switch that provides a DHCP server. Our router has an adress/netmask of 10.88.88.1/255.255.255.0
4) Connect your host computer to the same router.
5) Go to the demo directory: `cd FreeRTOS-mirror/FreeRTOS/Demo/RISC-V_Galois_P1`
6) Generate `main_tcp.elf` binary: `export PROG=main_tcp; make clean; make`
7) Start GDB: `riscv32-unknown-elf-gdb main_tcp.elf`
8) in your GDB session type: `target remote localhost:3333`
9) in your GDB session type: `load`
10) start minicom: `minicom -D /dev/ttyUSB1 -b 115200` **NOTE:** The default baud rate for TCP example is 115200 baud.
11) in your GDB session type: `continue`
12) In minicom, you will see a bunch of debug prints. The interesting piece is when you get:
```
IP Address: 10.88.88.3
Subnet Mask: 255.255.255.0
Gateway Address: 10.88.88.1
DNS Server Address: 10.88.88.1
```
which means the FreeRTOS got assigned an IP address and is ready to communicate.

13) Open a new terminal, and type `ping 10.88.88.3` (or whatever is the FPGA's IP address) - you should see something like this:
```
$ ping 10.88.88.3
PING 10.88.88.3 (10.88.88.3) 56(84) bytes of data.
64 bytes from 10.88.88.3: icmp_seq=1 ttl=64 time=14.1 ms
64 bytes from 10.88.88.3: icmp_seq=2 ttl=64 time=9.22 ms
64 bytes from 10.88.88.3: icmp_seq=3 ttl=64 time=8.85 ms
64 bytes from 10.88.88.3: icmp_seq=4 ttl=64 time=8.84 ms
64 bytes from 10.88.88.3: icmp_seq=5 ttl=64 time=8.85 ms
64 bytes from 10.88.88.3: icmp_seq=6 ttl=64 time=8.83 ms
64 bytes from 10.88.88.3: icmp_seq=7 ttl=64 time=8.83 ms
^C
--- 10.88.88.3 ping statistics ---
7 packets transmitted, 7 received, 0% packet loss, time 6007ms
rtt min/avg/max/mdev = 8.838/9.663/14.183/1.851 ms
```
That means ping is working and your FPGA is responding.

14) Now open another terminal and run TCP Echo server at port 9999: `ncat -l 9999 --keep-open --exec "/bin/cat" -v`
Note that this will work only if your TCP Echo server is at 10.88.88.2 (or you [updated the config file](https://github.com/GaloisInc/FreeRTOS-mirror/blob/p1_release/FreeRTOS/Demo/RISC-V_Galois_P1/FreeRTOSIPConfig.h#L315)
). After a few seconds, you will see something like this:
```
$ ncat -l 9999 --keep-open --exec "/bin/cat" -v
Ncat: Version 7.60 ( https://nmap.org/ncat )
Ncat: Generating a temporary 1024-bit RSA key. Use --ssl-key and --ssl-cert to use a permanent one.
Ncat: SHA-1 fingerprint: 2EDF 34C4 1F16 FF89 0AE1 6B1B F236 D933 A4DD 030E
Ncat: Listening on :::9999
Ncat: Listening on 0.0.0.0:9999
Ncat: Connection from 10.88.88.3.
Ncat: Connection from 10.88.88.3:25816.
Ncat: Connection from 10.88.88.3.
Ncat: Connection from 10.88.88.3:2334.
Ncat: Connection from 10.88.88.3.
Ncat: Connection from 10.88.88.3:14588.
```


15) [Optional] start `wireshark` and inspect the interface that is at the same network as the FPGA. You sould clearly see the ICMP ping requests and responses, as well as the TCP packets
to and from the echo server.
16) [Optional] Send a UDP packet with `socat stdio udp4-connect:10.88.88.3:5006 <<< "Hello there"`. In the minicom output, you should see `prvSimpleZeroCopyServerTask: received $N bytes` depending 
on how much data you send. **Hint:** instead of minicom, you can use `cat /dev/ttyUSB1 > log.txt` to redirect the serial output into a log file for later inspection.

**Troubleshooting**

If something doesn't work, then:
1) check that your connection is correct (e.g. if you have a DHCP server, it is enabled in the FreeRTOS config, or that your static IP is correct)
2) sometimes restarting the FPGA with `CPU_RESET` button (or typing `reset` in GDB) will help
3) Check out our [Issue](https://gitlab-ext.galois.com/ssith/gfe/issues) - maybe you have a problem we already know about.


## Running Linux - Debian or Busybox ##
### Creating Debian Image ###
Before starting, there are several necessary packages to install. Run:
``` 
apt-get install libssl-dev debian-ports-archive-keyring binfmt-support qemu-user-static mmdebstrap
```

The debian directory includes several scripts for creating a Debian image and a simple Makefile to run them. Running `make debian` from `$GFE_REPO/bootmem` will perform all the steps of creating the image. If you want to make modifications to the chroot and then build the image, you can do the following:

``` bash
# Using the scripts
cd $GFE_REPO/debian

# Create chroot and compress cpio archive
sudo ./create_chroot.sh

# Enter chroot
sudo chroot riscv64-chroot/

# ... Make modifications to the chroot ...

# Remove apt-cache and list files to decrease image size if desired
./clean_chroot

# Exit chroot
exit

# Recreate the cpio.gz image
sudo ./create_cpio.sh

# Build kernel and bbl
cd $GFE_REPO/bootmem
make debian
```
To decrease the size of the image, some language man pages, documentation, and locale files are removed.
This results in warnings about locale settings and man files that are expected.

If you want to install more packages than what is included, run `sudo ./create_chroot.sh package1 package2` and subsitute `package1` and `package2` with all the packages you want to install. Then recreate the cpio.gz image and run `make debian` as described above. If installing or removing packages manually rather than with the script, use `apt-get` to install or remove any packages from within the chroot and run `./clean_chroot` from within the chroot afterwards.

The bbl image is located at `$GFE_REPO/bootmem/build-bbl/bbl` and can be loaded and run using gdb. The default root password is `riscv`.

A memory image is also created that can be loaded into the flash ROM on the FPGA at `$GFE_REPO/bootmem/bootmem.bin`

### Creating Busybox Image ###

The following instructions describe how to boot Linux with Busybox.

#### Build the memory image ####

The default make target will build a simpler kernel with only a busybox boot environment:

```bash
cd $GFE_REPO/bootmem/
make
```

#### Load and run the memory image ####

Follow these steps to run Linux and Busybox with an interactive GDB session:

1. Reset the SoC by pressing the CPU_RESET button (SW5) on the VCU118 before running Linux.
2. Run OpenOCD to connect to the riscv core `openocd -f $GFE_REPO/testing/targets/ssith_gfe.cfg`.
3. In a new terminal, run minicom with `minicom -D /dev/ttyUSB1 -b 115200`. `ttyUSB1` should be replaced with whichever USB port is connected to the VCU118's USB-to-UART bridge. Settings can be configured by running `minicom -s` and selecting `Serial Port Setup` and then `Bps/Par/Bits`. 
The UART is configured to have 8 data bits, 2 stop bits, no parity bits, and a baud rate of 115200. In the minicom settings, make sure hardware flow control is turned off. Otherwise, the Linux terminal may not be responsive.
4. In a new terminal, run gdb with `riscv64-unknown-elf-gdb $GFE_REPO/bootmem/build-bbl/bbl`.
5. Once gdb is open, type `target remote localhost:3333` to connect to OpenOCD. OpenOCD should give a message that it has accepted a gdb connection.
6. On Bluespec processors, run `continue` then interrupt the processor with `Ctl-C`. The Bluespec processors start in a halted state, and need to run the first few bootrom instructions to setup a0 and a1 before booting Linux. See #40 for more details.
7. Load the Linux image onto the processor with `load`. To run, type `c` or `continue`.
8. When you've finished running Linux, make sure to reset the SoC before running other tests or programs.

In the serial terminal you should expect to see Linux boot messages.  The final message says ```Please press Enter to activate this console.```.  If you do as instructed (press enter), you will be presented with a shell running on the GFE system.

### Using Ethernet on Linux ###

The GFE-configured Linux kernel includes the Xilinx AXI Ethernet driver. You should see the following messages in the boot log:
```
[    4.320000] xilinx_axienet 62100000.ethernet: assigned reserved memory node ethernet@62100000
[    4.330000] xilinx_axienet 62100000.ethernet: TX_CSUM 2
[    4.330000] xilinx_axienet 62100000.ethernet: RX_CSUM 2
[    4.340000] xilinx_axienet 62100000.ethernet: enabling VCU118-specific quirk fixes
[    4.350000] libphy: Xilinx Axi Ethernet MDIO: probed
```
The provided configuration of busybox includes some basic networking utilities (ifconfig, udhcpc, ping, telnet, telnetd) to get you started. Additional utilities can be compiled into busybox or loaded into the filesystem image (add them to `$GFE_REPO/bootmem/_rootfs/`).

***Note*** Due to a bug when statically linking glibc into busybox, DNS resolution does not work. This will be fixed in a future GFE release either in busybox or by switching to a full Linux distro.
***Note*** There is currently a bug in the Chisel P3 that may result in a kernel panic when using the provided Ethernet driver. A fix will be released shortly.

The Debian image provided has the iproute2 package already installed and is ready for many network environments. 

**DHCP IP Example**

On Debian, the eth0 interface can be configured using the `/etc/network/interfaces` file followed by restarting the network service using `systemctl`.

On busybox, you must manually run the DHCP client:
```
/ # ifconfig eth0 up
...
xilinx_axienet 62100000.ethernet eth0: Link is Up - 1Gbps/Full - flow control rx/tx
...
/ # udhcpc -i eth0
udhcpc: started, v1.30.1
Setting IP address 0.0.0.0 on eth0
udhcpc: sending discover
udhcpc: sending select for 10.0.0.11
udhcpc: lease of 10.0.0.11 obtained, lease time 259200
Setting IP address 10.0.0.11 on eth0
Deleting routers
route: SIOCDELRT: No such process
Adding router 10.0.0.2
Recreating /etc/resolv.conf
 Adding DNS server 10.0.0.2
```

On either OS, you can run `ping 4.2.2.1` to test network connectivity. The expected output of this is: 
```
PING 4.2.2.1 (4.2.2.1): 56 data bytes
64 bytes from 4.2.2.1: seq=0 ttl=57 time=22.107 ms
64 bytes from 4.2.2.1: seq=1 ttl=57 time=20.754 ms
64 bytes from 4.2.2.1: seq=2 ttl=57 time=20.908 ms
64 bytes from 4.2.2.1: seq=3 ttl=57 time=20.778 ms
^C
--- 4.2.2.1 ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 20.754/21.136/22.107 ms
/ # 
```

**Static IP Example**

Use the commands below to enable networking when a DHCP server is not available. Replace the IP and router addresses as necessary for your setup:

On busybox:
```
/ # ifconfig eth0 10.0.0.3
/ # route add 10.0.0.0/24 dev eth0
/ # route add default gw 10.0.0.1
```

On Debian:
```
/ # ip addr add 10.0.0.3 dev eth0
/ # ip route add 10.0.0.0/24 dev eth0
/ # ip route add default via 10.0.0.1
/ # ping 4.2.2.1
PING 4.2.2.1 (4.2.2.1): 56 data bytes
64 bytes from 4.2.2.1: seq=0 ttl=57 time=23.320 ms
64 bytes from 4.2.2.1: seq=1 ttl=57 time=20.738 ms
...
^C
--- 4.2.2.1 ping statistics ---
20 packets transmitted, 20 packets received, 0% packet loss
round-trip min/avg/max = 20.536/20.913/23.320 ms

/ # 
```

### Storing a boot image in Flash ###

1. Prepare the Linux image with either Debian or Busybox as described above.
2. Write to flash memory on the board with the command `tcl/program_flash datafile bootmem/bootmem.bin`. Note that this command is run from the shell (not inside vivado).
3. The `program_flash` command overwrites the FPGA's configuration. Depending on your setup, follow the relevant instructions below:
    * If a suitable P2 or P3 bitstream is also stored in flash, the board can be physically reset or cold rebooted to automatically boot into Linux. 
    * Otherwise, you will have to reprogram the desired bit file using the `program_fpga.sh` script at this point. The processor will execute the flash image immediately.

Occasionally, the `tcl/program_flash` command will end with an out of memory error. As long as `Program/Verify Operation successful.` was printed before existing, the flash operation was completed.

There will not be any console messages while the boot image is read from flash, which could take some time for the full Debian OS.


## Adding in Your Processor ##

We recommend using the Vivado IP integrator flow to add a new processor into the GFE. This should require minimal effort to integrate the processor and this flow is already demonstrated for the Chisel and Bluespec processors. Using the integrator flow requires wrapping the processor in a Xilinx User IP block and updating the necessary IP search paths to find the new IP. The Chisel and Bluespec Vivado projects are created by sourcing the same tcl for the block diagram (`soc_bd.tcl`). The only difference is the location from which it pulls in the ssith_processor IP block.

The steps to add in a new processor are as follows:

1. Duplicate the top level verilog file `mkCore_P1.v` from the Chisel or Bluespec designs and modify it to instantiate the new processor. See `$GFE_REPO/chisel_processors/P1/xilinx_ip/hdl/mkP1_Core.v` and `$GFE_REPO/bluespec-processors/P1/Piccolo/src_SSITH_P1/xilinx_ip/hdl/mkP1_Core.v` for examples.
2. Copy the component.xml file from one of the two processors and modify it to include all the paths to the RTL files for your design. See `$GFE_REPO/bluespec-processors/P1/Piccolo/src_SSITH_P1/xilinx_ip/component.xml` and `$GFE_REPO/chisel_processors/P1/xilinx_ip/component.xml`. This is the most clunky part of the process, but is relatively straight forward.
    *  Copy a reference component.xml file to a new folder (i.e. `cp $GFE_REPO/chisel_processors/P1/xilinx_ip/component.xml new_processor/`)
    *  Replace references to old verilog files within component.xml. Replace `spirit:file` entries such as 
    ```xml
    <spirit:file>
        <spirit:name>hdl/galois.system.P1FPGAConfig.behav_srams.v</spirit:name>
        <spirit:fileType>verilogSource</spirit:fileType>
    </spirit:file>
    ```
   with paths to the hdl for the new processor such as: 
    ```xml
    <spirit:file>
        <spirit:name>hdl/new_processor.v</spirit:name>
        <spirit:fileType>verilogSource</spirit:fileType>
    </spirit:file>
    ```
    The paths in component.xml are relative to its parent directory (i.e. `$GFE_REPO/chisel_processors/P1/xilinx_ip/`).
    * Note that the component.xml file contains a set of files used for simulation (xilinx_anylanguagebehavioralsimulation_view_fileset) and another set used for synthesis. Make sure to replace or remove file entries as necessary in each of these sections.
    * Vivado discovers user IP by searching all it's IP repository paths looking for component.xml files. This is the reason for the specific name. This file fully describes the new processor's IP block and can be modified through a gui if desired using the IP packager flow. It is easier to start with an example component.xml file to ensure the port naming and external interfaces match those used by the block diagram.

3. Add your processor to `$GFE_REPO/tcl/proc_mapping.tcl`. Add a line here to include the mapping between your processor name and directory containing the component.xml file. This mapping is used by the `soc.tcl` build script.
    ```bash
    vim tcl/proc_mapping.tcl
    # Add line if component.xml lives at ../new_processor/component.xml
    + dict set proc_mapping new_processor "../new_processor"
    ```
   The mapping path is relative to the `$GFE_REPO/tcl` path
4. Create a new Vivado project with your new processor by running the following:
    ```bash
    cd $GFE_REPO
    ./setup_soc_project.sh new_processor
    ```
   new_processor is the name specified in the `$GFE_REPO/tcl/proc_mapping.tcl` file.

5. Synthesize and build the design using the normal flow. Note that users will have to update the User IP as prompted in the gui after each modification to the component.xml file or reference Verilog files.

All that is required (and therefore tracked by git) to create a Xilinx User IP block is a component.xml file and the corresponding verilog source files.
If using the Vivado GUI IP packager, the additional project collateral does not need to be tracked by git.

### Modifying the GFE ###

To save changes to the block diagram in git (everything outside the SSITH Processor IP block), please open the block diagram in Vivado and run `write_bd_tcl -force ../tcl/soc_bd.tcl`. Additionally, update `tcl/soc.tcl` to add any project settings.

### Rebuilding the Chisel and Bluespec Processors ###

The compiled verilog from the latest Chisel and Bluespec build is stored in git to enable building the FPGA bitstream right away. To rebuild the bluespec processor, follow the directions in `bluespec-processors/P1/Piccolo/README.md`. To rebuild the Chisel processor for the GFE, run the following commands
```bash
cd chisel_processors/P1
./build.sh
```

## Tandem Verification ##

Below are instructions for running Tandem verification on the GFE. For more information on the trace collected by Tandem Verification see [trace-protocol.pdf](trace-protocol.pdf).

### Establishing the PCIe Link ###

Begin by compiling the provided version of the bluenoc executable and kernel module:

```bash
$ # Install Kernel Headers
$ sudo apt-get install linux-headers-$(uname -r)
$ cd bluenoc/drivers
$ make
$ sudo make install
$ cd ../bluenoc
$ make
```

Next, program the FPGA with a tandem-verification enabled bitstream: `./program_fpga.sh bluespec_p2`

**Note: This process is motherboard-dependent.**

If using the prescribed MSI motherboard in your host machine, you will need to 
power the VCU118 externally using the supplied power brick. You must be able to 
fully shut down the computer while maintaining power to the FPGA. Turn off your
host machine and then turn it back on.

On computers with Asus motherboards (and potentially others), a warm rebooot may be
all that is necessary.

After the cold or warm reboot, run the bluenoc utility to determine if the PCIe link has been established:
```bash
$ cd bluenoc/bluenoc
$ ./bluenoc
Found BlueNoC device at /dev/bluenoc_1
  Board number:     1
  Board:            Xilinx VCU118 (A118)
  BlueNoC revision: 1.0
  Build number:     34908
  Timestamp:        Wed Dec 21 13:41:31 2016
  SceMi Clock:      41.67 MHz
  Network width:    4 bytes per beat
  Content ID:       5ce000600080000
  Debug level:      OFF
  Profiling:        OFF
  PCIe Link:        ENABLED
  BlueNoC Link:     ENABLED
  BlueNoC I/F:      READY
  Memory Sub-Sys:   ENABLED
```

After the link has been established, you may reprogram the FPGA with other TV-enabled bitstreams and re-establish the PCIe link with just a warm reboot.
If you program a bitstream that does not include the tandem verification hardware, you will need to follow the cold reboot procedure to re-establish the link later on.

### Installing Bluespec ###
A full Bluespec installation is required for the current version of the write_tvtrace program. It has been tested with Bluespec-2017.07.A. The following paths should to be set:

```bash
$ export BLUESPECDIR=/opt/Bluespec-2017.07.A/lib
$ export PATH=$BLUESPECDIR/../bin:$PATH
```

### Licensing ###
For the license to work, Debian must be reconfigured to use old-style naming of the Ethernet devices.

Open `/etc/default/grub` and modify:

```
GRUB_CMDLINE_LINUX=""
```

to contain:

```
GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"
```

Rebuild the grub configuration:

```
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

After a reboot, check that there is now a `eth0` networking device:

```bash
$ ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT group default qlen 1000
    link/ether 30:9c:23:a5:f2:40 brd ff:ff:ff:ff:ff:ff
```

If you have more than one network device, be sure the MAC address for eth0 is used to request a license, even if it is not your active connection.

Send the MAC address to support@bluespec.com to request a license if you do not already have one.

Once the license is obtained, set the following variable (replacing the path with the proper location):

```bash
$ export LM_LICENSE_FILE=/opt/Bluespec.lic
```

### Capturing a Trace ###
Use the `exe_write_tvtrace_RV64` program to capture a trace (works for both 32-bit and 64-bit processors):

```bash
$ cd $GFE_REPO/TV-hostside
$ ./exe_write_tvtrace_RV64
----------------------------------------------------------------
Bluespec SSITH Support, TV Trace Dumper v1.0
Copyright (c) 2016-2019 Bluespec, Inc. All Rights Reserved.
----------------------------------------------------------------

---------------- debug start
Starting verifier thread
Writing trace to 'trace_data.dat'
Receiving traces ...
^C
```

Use `Ctrl-C` to stop capturing trace data after your program has finished executing.

### Comparing a Trace ###
To compare the captured trace against the Cissr simulation model, use the `exe_tvchecker_RV*` programs. There are separate binaries for comparing 32-bit and 64-bit traces:

```bash
$ cd $GFE_REPO/TV-hostside
$ ./exe_tvchecker_RV64 trace_data.dat
Opened file 'test.trace' for reading trace_data.
Loading BOOT ROM from file 'boot_ROM_RV64.memhex'
ISA = RV64IMAFDCUS
Cissr: v2018-01-31 (RV64)
------
Cissr: reset
Tandem verifier is: Cissr
Trace configation: XLEN=64, MLEN=64, FLEN=0
{ STATE_INIT[mem_req addr 0x6fff0000 STORE 32b data 0x1] }
ERROR: cissr_write_mem32: STORE_AMO_ACCESS_FAULT at address 0x6fff0000
{ RESET }
------
Cissr: reset
...
{ [pc c000000c][instr 00800f93][t6(x31) 8] } inum 497
{ [pc c0000040][instr 03ff0a63] } inum 498
{ STATE_INIT[mem_req addr 0xc0000040 STORE 32b data 0x0] }
```

Note that some early mismatches are expected as the simulation model is updated with the correct PC and initial status registers.

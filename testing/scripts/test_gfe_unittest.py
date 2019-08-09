#!/usr/bin/env python
"""Script to run a compiled elf on the GFE
"""

import unittest
import argparse
import gfetester
import gfeparameters
import os
import time
import struct
import glob
import sys
import subprocess
import socket
import re
import select

class BaseGfeTest(unittest.TestCase):
    """GFE base testing class. All GFE Python unittests inherit from this class
    
    Attributes:
        gfe (gfetester): GFE handler with functions to interact with the VCU118
        path_to_asm (string): Path to custom GFE assembly tests
        path_to_freertos (string): Path to FreeRTOS folder in the GFE repo
    """

    def getXlen(self):
        return '32'

    def getFreq(self):
        """Return the processor frequency in Hz.
        Child classes can override this function for tests on different processors
        
        Returns:
            int: Processor frequency in Hz
        """
        return gfeparameters.GFE_P1_DEFAULT_HZ

    def getGdbPath(self):
        """Get the proper riscv gdb executable depending on the architecture of the GFE
        (32 vs 64 bit processor).
        
        Returns:
            string: Executable name for riscv gdb (i.e. riscv32-unkown-elf-gdb)
        """
        if '32' in self.getXlen():
            return gfeparameters.gdb_path32
        return gfeparameters.gdb_path64   

    def setupUart(self, timeout=1, baud=115200, parity="NONE",
        stopbits=2, bytesize=8):
        """Setup a pyserial UART connection with the GFE
        
        Args:
            timeout (int, optional): Timeout seconds used by pySerial
            baud (int, optional): UART baud rate
            parity (str, optional): UART parity: EVEN, ODD, or NONE
            stopbits (int, optional): Number of UART stop bits
            bytesize (int, optional): UART byte size
        """
        self.gfe.setupUart(
            timeout=timeout,
            baud=baud,
            parity=parity,
            stopbits=stopbits,
            bytesize=bytesize)
        print(
            "Setup pySerial UART. {} baud, {} {} {}".format(
                baud, bytesize, parity, stopbits))

    def check_uart_out(self, timeout, expected_contents, absent_contents=None):
        # Store and print all UART output while the elf is running
        rx_buf = []
        start_time = time.time()
        while time.time() < (start_time + timeout):
            pending = self.gfe.uart_session.in_waiting
            if pending:
                data = self.gfe.uart_session.read(pending)
                rx_buf.append(data) # Append read chunks to the list.
                sys.stdout.write(data)

        rx = ''.join(rx_buf)

        # Check that the output contains the expected text
        for text in expected_contents:
            self.assertIn(text, rx)

        if absent_contents != None:
            self.assertNotIn(absent_contents, rx)

        return rx

    def check_in_output(self, elf, timeout, expected_contents, absent_contents=None,
        baud=115200, parity="NONE", stopbits=2, bytesize=8,
        uart_timeout=1, run_from_flash=False):
        """Run a program and check UART output for some expected contents
        
        Args:
            elf (string): Path to the test program
            timeout (int): Number of seconds for which test program will be run
            expected_contents (list(string)): List of expected strings in the UART output
            baud (int, optional): UART baud rate
            parity (str, optional): UART parity
            stopbits (int, optional): UART stopbits
            bytesize (int, optional): UART byte size
            uart_timeout (int, optional): UART timeout for pySerial
            run_from_flash (bool, optional): Run the elf currently stored in flash by
                resetting the GFE. Do not load a new program onto the GFE.
        """

        # Halt the processor before setting up the UART connection
        self.gfe.gdb_session.interrupt()
        self.setupUart(
            baud=baud,
            parity=parity,
            stopbits=stopbits,
            bytesize=bytesize,
            timeout=uart_timeout)

        # Run the program of interest (from flash or using "gdb load")
        if run_from_flash:
            print("Loading from flash")
            #self.gfe.softReset()
            self.gfe.gdb_session.c(wait=False)
        else:
            print("Loading Elf {}".format(elf))
            print("This may take some time...")
            self.gfe.launchElf(elf, verify=False)
            print("Running elf with a timeout of {}s".format(timeout))

        # Store and print all UART output while the elf is running
        print("Printing all UART output from the GFE...")
        self.check_uart_out(timeout=timeout, expected_contents=expected_contents, absent_contents=absent_contents)

    def setUp(self):
        # Reset the GFE
        self.gfe = gfetester.gfetester(gdb_path=self.getGdbPath())
        self.gfe.startGdb()
        self.path_to_asm = os.path.join(
                os.path.dirname(os.getcwd()), 'baremetal', 'asm')
        self.path_to_freertos = os.path.join(
                os.path.dirname(os.getcwd()), 'FreeRTOS-RISCV', 'Demo', 'p1-besspin')       
        self.gfe.softReset()

    def tearDown(self):
        if not self.gfe.gdb_session:
            return
        self.gfe.gdb_session.interrupt()
        self.gfe.gdb_session.command("disassemble", ops=20)
        self.gfe.gdb_session.command("info registers all", ops=100)
        self.gfe.gdb_session.command("flush regs")
        self.gfe.gdb_session.command("info threads", ops=100)
        del self.gfe

class TestGfe(BaseGfeTest):
    """Collection of smoke tests to exercise the GFE peripherals.
    This class is inherited by TestGfe32 and TestGfe64 for testing P1
    and P2/3 processors respectively."""

    def test_soft_reset(self):
        """Test the soft reset mechanism of the GFE.
        Write to a UART register and ensure the value is reset after calling softReset.
        """
        UART_SCRATCH_ADDR = gfeparameters.UART_BASE + gfeparameters.UART_SCR
        test_value = 0xef

        # Check the initial reset value
        scr_value = self.gfe.riscvRead32(UART_SCRATCH_ADDR)
        self.assertEqual(scr_value, 0x0)

        # Write to the UART register and check the write succeeded
        self.gfe.riscvWrite32(UART_SCRATCH_ADDR, test_value)
        scr_value = self.gfe.riscvRead32(UART_SCRATCH_ADDR)
        err_msg = "Value read from UART scratch register {} "
        err_msg += "does not match {} written to it."
        err_msg = err_msg.format(hex(scr_value), hex(test_value))
        self.assertEqual(test_value, scr_value, err_msg)

        # Reset the SoC
        self.gfe.softReset()

        # Check that the value was reset
        scr_value = self.gfe.riscvRead32(UART_SCRATCH_ADDR)
        self.assertEqual(scr_value, 0x0)

    def test_uart(self):
        """Run a test UART program.
        Send the RISCV core characters using pyserial and receive them back
        """
        print("xlen = " + self.getXlen())
        if '64' in self.getXlen():
            uart_elf = 'rv64ui-p-uart'
        else:
            uart_elf = 'rv32ui-p-uart'

        uart_baud_rate = 115200
        uart_elf_path = os.path.abspath(
            os.path.join(self.path_to_asm, uart_elf))
        print("Using: " + uart_elf_path)

        self.gfe.setupUart(
            timeout=1,
            baud=uart_baud_rate,
            parity="EVEN",
            stopbits=2,
            bytesize=8)

        # Setup the UART devisor bits to account for GFEs at
        # different frequencies
        divisor = int(self.getFreq()/(16 * uart_baud_rate))
        # Get the upper and lower divisor bytes into dlm and dll respectively
        uart_dll_val = struct.unpack("B", struct.pack(">I", divisor)[-1])[0]
        uart_dlm_val = struct.unpack("B", struct.pack(">I", divisor)[-2])[0]
        uart_base = gfeparameters.UART_BASE
        print("Uart baud rate {} Clock Freq {}\nSetting divisor to {}. dlm = {}, dll = {}".format(
            uart_baud_rate, self.getFreq(),
            divisor, hex(uart_dlm_val), hex(uart_dll_val)))
        self.gfe.riscvWrite32(uart_base + gfeparameters.UART_LCR, 0x80)
        self.gfe.riscvWrite32(uart_base + gfeparameters.UART_DLL, uart_dll_val)
        self.gfe.riscvWrite32(uart_base + gfeparameters.UART_DLM, uart_dlm_val)
        print("Launching UART assembly test {}".format(uart_elf_path))      
        self.gfe.launchElf(uart_elf_path, openocd_log=True, gdb_log=True)

        # Allow the riscv program to get started and configure UART
        time.sleep(0.2)

        for test_char in [b'a', b'z', b'd']:

            self.gfe.uart_session.write(test_char)
            print("host sent ", test_char)
            b = self.gfe.uart_session.read()
            print("riscv received ", b)
            self.assertEqual(
                b, test_char,
                "Character received {} does not match test test_char {}".format(
                    b, test_char) )
        return

    def test_ddr(self):
        """Write data to ddr and read it back"""

        # Read the base address of ddr
        ddr_base = gfeparameters.DDR_BASE
        _base_val = self.gfe.riscvRead32(ddr_base)
        # Perform enough writes to force a writeback to ddr
        addr_incr = 0x100000
        write_n = 10
        for i in range(write_n):
            self.gfe.riscvWrite32(
                ddr_base + i * addr_incr,
                i)
        # Perform enough reads to force a fetch from ddr
        for i in range(write_n):
            val = self.gfe.riscvRead32(
                ddr_base + i * addr_incr)
            self.assertEqual(i, val)
        return

    def test_bootrom(self):
        """Read some values bootrom and make sure they aren't all zero"""

        # Read the first value from the bootrom
        bootrom_base = gfeparameters.BOOTROM_BASE
        bootrom_size = gfeparameters.BOOTROM_SIZE
        base_val = self.gfe.riscvRead32(bootrom_base)

        # Check that it isn't zeros or ones
        self.assertNotEqual(base_val, 0)
        self.assertNotEqual(base_val, 0xFFFFFFFF)

        # Read a value higher up in the address space
        self.assertGreater(bootrom_size, 0xf0)
        self.gfe.riscvRead32(
            bootrom_base + bootrom_size - 0xf0)

        # Make sure the read operations complete by checking
        # the first value again
        self.assertEqual(
            base_val,
            self.gfe.riscvRead32(bootrom_base)
            )
        return

# Create test classes for 64 and 32 bit processors
class TestGfe32(TestGfe):

    def getXlen(self):
        return '32'

    def getFreq(self):
        return gfeparameters.GFE_P1_DEFAULT_HZ

class TestGfe64(TestGfe):

    def getXlen(self):
        return '64'

    def getFreq(self):
        return gfeparameters.GFE_P2_DEFAULT_HZ

class TestFreeRTOS(BaseGfeTest):

    def getFreq(self):
        return gfeparameters.GFE_P1_DEFAULT_HZ # FreeRTOS only runs on the P1

    def setUp(self):
        # Reset the GFE
        self.gfe = gfetester.gfetester(gdb_path=self.getGdbPath())
        self.gfe.startGdb()
        self.gfe.softReset()
        self.path_to_freertos = os.path.join(
                os.path.dirname(os.path.dirname(os.getcwd())),
                'FreeRTOS-mirror', 'FreeRTOS', 'Demo',
                'RISC-V_Galois_P1')

    def runSubprocess(self, timeout, command, expected_contents):
        process = subprocess.Popen(command, stdout=subprocess.PIPE, 
                                stderr=subprocess.PIPE, shell=True)
        response_stdout = process.stderr.read()
        time.sleep(timeout)
        process.kill()
        print(response_stdout)
        self.assertIn(expected_contents, response_stdout)
        return


    def test_full(self):
        # load freertos binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_full.elf'))
        print(freertos_elf)
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=60,
            expected_contents=["main_full", "Pass"],
            absent_contents="ERROR")

        return

    def test_flash_full(self):
        # load freertos binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_full.elf'))
        print(freertos_elf)
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=60,
            expected_contents=["main_full", "Pass"],
            absent_contents="ERROR",
            run_from_flash= True ) 

        return

        
    def test_blink(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_blinky.elf'))
        print(freertos_elf)

        expected_contents = [
            "Blink",
            "RX: received value",
            "TX: sent",
            "Hello from RX",
            "Hello from TX",
        ]
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=3,
            expected_contents=expected_contents)

        return
    
    def test_flash_blinky(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_blinky.elf'))
        print(freertos_elf)

        expected_contents = [
            "Blink",
            "RX: received value",
            "TX: sent",
            "Hello from RX",
            "Hello from TX",
        ]
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=10,
            expected_contents=expected_contents,
            run_from_flash = True)

        return


    def test_uart(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_uart.elf'))
        print(freertos_elf)

        expected_contents = [
            "UART1 RX: Hello from UART1",
        ]
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=15,
            expected_contents=expected_contents)

        return
    
    def test_gpio(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_gpio.elf'))
        print(freertos_elf)

        expected_contents = [
            "#0 changed: 1 -> 0",
            "#1 changed: 1 -> 0",
            "#2 changed: 1 -> 0",
            "#3 changed: 1 -> 0",
            "#0 changed: 0 -> 1",
            "#1 changed: 0 -> 1",
            "#2 changed: 0 -> 1",
            "#3 changed: 0 -> 1",
        ]
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=15,
            expected_contents=expected_contents)

        return

    def test_iic(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_iic.elf'))
        print(freertos_elf)

        expected_contents = [
            "Whoami: 0x71",
        ]
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=15,
            expected_contents=expected_contents)

        return

    def test_sd(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_sd.elf'))
        print(freertos_elf)

        expected_contents = [
            "prvSdTestTask0 terminating, exit code = 0",
        ]
        
        self.check_in_output(
            elf=freertos_elf,
            timeout=30,
            expected_contents=expected_contents)

        return

    def test_tcp(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_tcp.elf'))
        print(freertos_elf)

        # Setup UART
        self.setupUart()

        # Load and run elf
        print("Loading Elf {}".format(freertos_elf))
        print("This may take some time...")
        self.gfe.launchElf(freertos_elf, verify=False)

         # Store and print all UART output while the elf is running
        timeout = 60
        print("Printing all UART output from the GFE...")
        rx_buf = []
        start_time = time.time()
        while time.time() < (start_time + timeout):
            pending = self.gfe.uart_session.in_waiting
            if pending:
                data = self.gfe.uart_session.read(pending)
                rx_buf.append(data) # Append read chunks to the list.
                sys.stdout.write(data)
        print("Timeout reached")

        # Get FPGA IP address
        riscv_ip = 0
        rx_buf_str = ''.join(rx_buf)
        rx_buf_list = rx_buf_str.split('\n')
        for line in rx_buf_list:
            index = line.find('IP Address:')
            if index != -1:
                ip_str = line.split()
                riscv_ip = ip_str[2]

        # Ping FPGA
        print("RISCV IP address is: " + riscv_ip)
        if (riscv_ip == 0) or (riscv_ip == "0.0.0.0"):
            raise Exception("Could not get RISCV IP Address. Check that it was assigned in the UART output.")
        ping_response = os.system("ping -c 1 " + riscv_ip)
        self.assertEqual(ping_response, 0,
                        "Cannot pin FPGA.")

        # Run TCP echo client
        print("\n Sending to RISC-V's TCP echo server")
        # Create a TCP/IP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        # Connect the socket to the port where the server is listening
        server_address = (riscv_ip, 7)
        print >>sys.stderr, 'connecting to %s port %s' % server_address
        sock.connect(server_address)
        sock.setblocking(0)
        try:
            # Send data
            message = 'This is the message.  It will be repeated.'
            print >>sys.stderr, 'sending "%s"' % message
            sock.sendall(message)

            # Look for the response
            amount_received = 0
            amount_expected = len(message)

            while amount_received < amount_expected:
                ready = select.select([sock], [], [], 10)
                if ready[0]:
                    data = sock.recv(128)
                    amount_received += len(data)
                    print >>sys.stderr, 'received "%s"' % data
                    self.assertEqual(message, data)
                else:
                    raise Exception("TCP socket timeout")
        finally:
            print >>sys.stderr, 'closing socket'
            sock.close()
        return

    def test_udp(self):
        # Load FreeRTOS binary
        freertos_elf = os.path.abspath(
           os.path.join( self.path_to_freertos, 'main_udp.elf'))
        print(freertos_elf)

        # Setup UART
        self.setupUart()

        # Load and run elf
        print("Loading Elf {}".format(freertos_elf))
        print("This may take some time...")
        self.gfe.launchElf(freertos_elf, verify=False)

         # Store and print all UART output while the elf is running
        timeout = 60
        print("Printing all UART output from the GFE...")
        rx_buf = []
        start_time = time.time()
        while time.time() < (start_time + timeout):
            pending = self.gfe.uart_session.in_waiting
            if pending:
                data = self.gfe.uart_session.read(pending)
                rx_buf.append(data) # Append read chunks to the list.
                sys.stdout.write(data)
        print("Timeout reached")

        # Get FPGA IP address
        riscv_ip = 0
        rx_buf_str = ''.join(rx_buf)
        rx_buf_list = rx_buf_str.split('\n')
        for line in rx_buf_list:
            index = line.find('IP Address:')
            if index != -1:
                ip_str = line.split()
                riscv_ip = ip_str[2]

        # Ping FPGA
        print("RISCV IP address is: " + riscv_ip)
        if (riscv_ip == 0) or (riscv_ip == "0.0.0.0"):
            raise Exception("Could not get RISCV IP Address. Check that it was assigned in the UART output.")
        ping_response = os.system("ping -c 1 " + riscv_ip)
        self.assertEqual(ping_response, 0,
                        "Cannot ping FPGA")

        # Send UDP packet
        print("\n Sending to RISC-V's UDP echo server")
        # Create a UDP socket at client side
        UDPClientSocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
        msgFromClient       = "Hello UDP Server"
        bytesToSend         = str.encode(msgFromClient)
        serverAddressPort   = (riscv_ip, 5006)
        bufferSize          = 1024

        # Send to server using created UDP socket
        UDPClientSocket.setblocking(0)
        UDPClientSocket.sendto(bytesToSend, serverAddressPort)
        ready = select.select([UDPClientSocket], [], [], 10)
        if ready[0]:
            msgFromServer = UDPClientSocket.recvfrom(bufferSize)
            print(msgFromServer)
            self.assertIn(msgFromClient, msgFromServer)
        else:
            raise Exception("UDP socket timeout")
        return

class TestLinux(BaseGfeTest):

    def getBootImage(self):
        return os.path.join(
            os.path.dirname(os.path.dirname(os.getcwd())),
            'bootmem', 'build-bbl', 'bbl')

    def getXlen(self):
        return '64'

    def getDebianExpected(self):
        return [
            "Run /init as init process",
            "Debian GNU/Linux bullseye/sid",
            "login:"
        ]
    def getBusyBoxExpected(self):
        return [
            "Xilinx Axi Ethernet MDIO: probed",
            "Please press Enter to activate this console"
        ]

    def boot_linux(self, image=None):
        if not image:
            image = self.getBootImage()

        linux_elf = self.getBootImage()

        self.gfe.gdb_session.command("set $a0 = 0")
        self.gfe.gdb_session.command("set $a1 = 0x70000020")

        # Setup UART
        self.setupUart()

        # Load and run elf
        print("Loading Elf {}".format(linux_elf))
        print("This may take some time...")
        self.gfe.launchElf(linux_elf, verify=False)
        return

    def boot_image(self, expected_contents, image=None,
        run_from_flash=False, timeout=60):

        if not image:
            image = self.getBootImage()

        linux_elf = self.getBootImage()

        self.gfe.gdb_session.command("set $a0 = 0")
        self.gfe.gdb_session.command("set $a1 = 0x70000020")

        self.check_in_output(
            elf=linux_elf,
            timeout=timeout,
            expected_contents=expected_contents,
            run_from_flash=run_from_flash)
        return

    def test_busybox_boot(self):
        self.boot_image(expected_contents=self.getBusyBoxExpected(), timeout=60)
        return

    def test_busybox_flash_boot(self):
        self.boot_image(expected_contents=self.getBusyBoxExpected(), timeout=100, run_from_flash=True)
        return

    def test_debian_boot(self):
        self.boot_image(expected_contents=self.getDebianExpected(), timeout=1500)
        return

    def test_debian_flash_boot(self):
        self.boot_image(expected_contents=self.getDebianExpected(), timeout=1500, run_from_flash=True)
        return

    def test_busybox_ethernet(self):
        # Boot busybox
        self.boot_linux();
        linux_boot_timeout=60

        print("Running elf with a timeout of {}s".format(linux_boot_timeout))
        # Check that busybox reached activation screen
        self.check_uart_out(
            timeout=linux_boot_timeout,
            expected_contents=["Please press Enter to activate this console"])

        # Send "Enter" to activate console
        self.gfe.uart_session.write(b'\r')
        time.sleep(1)

        # Run DHCP client
        self.gfe.uart_session.write(b'ifconfig eth0 up\r')
        self.check_uart_out(
            timeout=10,
            expected_contents=["xilinx_axienet 62100000.ethernet eth0: Link is Up - 1Gbps/Full - flow control rx/tx"])

        self.gfe.uart_session.write(b'udhcpc -i eth0\r')
         # Store and print all UART output while the elf is running
        timeout = 10
        print("Printing all UART output from the GFE...")
        rx_buf = []
        start_time = time.time()
        while time.time() < (start_time + timeout):
            pending = self.gfe.uart_session.in_waiting
            if pending:
                data = self.gfe.uart_session.read(pending)
                rx_buf.append(data) # Append read chunks to the list.
                sys.stdout.write(data)
        print("Timeout reached")

        # Get FPGA IP address
        riscv_ip = 0
        rx_buf_str = ''.join(rx_buf)
        rx_buf_list = rx_buf_str.split('\n')
        for line in rx_buf_list:
            index = line.find('Setting IP address')
            if index != -1:
                ip_str = line.split()
                riscv_ip = ip_str[3]
                print("RISCV IP address is: " + riscv_ip)
                # break # keep reading till the end to get the latest IP asignemnt

        # Ping FPGA
        if riscv_ip == 0:
            raise Exception("Could not get RISCV IP Address. Check that it was assigned in the UART output.")
        ping_response = os.system("ping -c 1 " + riscv_ip)
        self.assertEqual(ping_response, 0,
                        "Cannot ping FPGA.")
        return


    def test_debian_ethernet(self):
        # Boot Debian
        self.boot_linux()
        linux_boot_timeout=800
        print("Running elf with a timeout of {}s".format(linux_boot_timeout))
        
        # Check that Debian booted
        self.check_uart_out(
                timeout=linux_boot_timeout,
                expected_contents=self.getDebianExpected())

        # Login to Debian
        self.gfe.uart_session.write(b'root\r')
        # Check for password prompt and enter password
        self.check_uart_out(timeout=5, expected_contents=["Password"])
        self.gfe.uart_session.write(b'riscv\r')
    
        # Check for command line prompt
        self.check_uart_out(
                timeout=15,
                expected_contents=["The programs included with the Debian GNU/Linux system are free software;",
                                    ":~#"
                                    ])
        self.gfe.uart_session.write(b'ifup eth0\r')
        self.gfe.uart_session.write(b'ip addr\r')

        # Get RISC-V IP address and ping it from host
        # Store and print all UART output while the elf is running
        timeout = 60
        print("Printing all UART output from the GFE...")
        rx_buf = []
        start_time = time.time()
        while time.time() < (start_time + timeout):
            pending = self.gfe.uart_session.in_waiting
            if pending:
                data = self.gfe.uart_session.read(pending)
                rx_buf.append(data) # Append read chunks to the list.
                sys.stdout.write(data)
        print("Timeout reached")

        # Get FPGA IP address
        riscv_ip = 0
        rx_buf_str = ''.join(rx_buf)
        rx_buf_list = rx_buf_str.split('\n')
        for line in rx_buf_list:
            index1 = line.find('inet')
            index2 = line.find('eth0')
            if (index1 != -1) & (index2 != -1):
                ip_str = re.split('[/\s]\s*', line)
                riscv_ip = ip_str[2]

        # Ping FPGA
        print("RISCV IP address is: " + riscv_ip)
        if (riscv_ip == 0) or (riscv_ip == "0.0.0.0"):
            raise Exception("Could not get RISCV IP Address. Check that it was assigned in the UART output.")
        ping_response = os.system("ping -c 1 " + riscv_ip)
        self.assertEqual(ping_response, 0,
                        "Cannot ping FPGA.")
        return
        
class BaseTestIsaGfe(BaseGfeTest):
    """ISA unittest base class for P1 and P2 processors.

    Note that this testing flow is slower than using GDB scripting,
    so we continue to use separate gdb scripts for running automated
    ISA tests on the GFE. The python framework can be useful for more
    complex debugging."""

    def run_isa_test(self, test_path):
        test_name = os.path.basename(test_path)
        if '32' in test_name:
            xlen = '32'
        if '64' in test_name:
            xlen = '64'
        if 'p' in test_name:
            return self.run_isa_p_test(xlen, test_path)
        if 'v' in test_name:
            return self.run_isa_v_test(xlen, test_path)           

    def run_isa_p_test(self, xlen, test_path):
        test_name = os.path.basename(test_path)
        print("Running {}".format(test_path))
        self.gfe.gdb_session.command("file {}".format(test_path))
        self.gfe.gdb_session.load()
        self.gfe.gdb_session.b("write_tohost")
        self.gfe.gdb_session.c()
        gp = self.gfe.gdb_session.p("$gp")
        self.assertEqual(gp, 1)
        return

    def run_isa_v_test(self, xlen, test_path):
        test_name = os.path.basename(test_path)
        print("Running {}".format(test_path))
        self.gfe.gdb_session.command("file {}".format(test_path))
        self.gfe.gdb_session.load()
        self.gfe.gdb_session.b("terminate")
        self.gfe.gdb_session.c()
        a0 = self.gfe.gdb_session.p("$a0")
        self.assertEqual(a0, 1)
        return

# Extract lists of isa tests from riscv-tests directory
riscv_isa_tests_path = os.path.join(
    os.path.dirname(os.path.dirname(os.getcwd())),
    'riscv-tools',
    'riscv-tests',
    'isa')
p2_isa_list = glob.glob(os.path.join(riscv_isa_tests_path, 'rv64*-*-*'))
p2_isa_names = [os.path.basename(k) for k in p2_isa_list]
p2_isa_names = [k for k in p2_isa_names if '.' not in k] # Remove all .dump files etc
p2_isa_list = [os.path.join(riscv_isa_tests_path, k) for k in p2_isa_names]

p1_isa_list = glob.glob(os.path.join(riscv_isa_tests_path, 'rv32*-p-*'))
p1_isa_names = [os.path.basename(k) for k in p1_isa_list]
p1_isa_names = [k for k in p1_isa_names if '.' not in k] # Remove all .dump files etc
p1_isa_list = [os.path.join(riscv_isa_tests_path, k) for k in p1_isa_names]

class TestP2IsaGfe(BaseTestIsaGfe):
    """ISA unitttests for P2 processor"""

    def getXlen(self):
        return '64'

    def test_isa(self):
        for test_path in p2_isa_list:
            self.run_isa_test(test_path)

class TestP1IsaGfe(BaseTestIsaGfe):
    """ISA unitttests for P1 processor"""

    def getXlen(self):
        return '32'

    def test_isa(self):
        for test_path in p1_isa_list:
            self.run_isa_test(test_path)

if __name__ == '__main__':
    unittest.main()

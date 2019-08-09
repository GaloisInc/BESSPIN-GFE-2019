import testlib
import re
import gfeparameters
import os
import time
import serial
import serial.tools.list_ports


class gfetester(object):
    """Collection of functions and state used to interact with the GFE fpga.
    This code can be used to coordinate and control actions over the
    physical interfaces to the GFE"""
    def __init__(
        self,
        gdb_port=gfeparameters.gdb_port,
        gdb_path=gfeparameters.gdb_path,
        openocd_command=gfeparameters.openocd_command,
        openocd_cfg_path=gfeparameters.openocd_cfg_path,
    ):
        super(gfetester, self).__init__()
        self.gdb_port = gdb_port
        self.openocd_command = openocd_command
        self.openocd_cfg_path = openocd_cfg_path
        self.gdb_path = gdb_path
        self.gdb_session = None
        self.openocd_session = None
        self.uart_session = None

    # ------------------ GDB/JTAG Functions ------------------

    def startGdb(
        self,
        port=None,
        binary=None,
        server_cmd=None,
        config=None,
        riscv_gdb_cmd=None,
        verbose=False
    ):
        """Start a gdb session with the riscv core on the GFE

        Args:
            port (int, optional): TCP port for GDB connection over openocd
            server_cmd (string, optional): The base openocd command to run
            config (string, optional): Path to the openocd debugger
            configuration riscv_gdb_cmd (string, optional): Base gdb
            command for the riscv gdb program
        """
        if not server_cmd:
            server_cmd = self.openocd_command
        if not config:
            config = self.openocd_cfg_path
        if not riscv_gdb_cmd:
            riscv_gdb_cmd = self.gdb_path
        self.openocd_session = testlib.Openocd(
            server_cmd=server_cmd,
            config=config,
            debug=False)
        self.gdb_session = testlib.Gdb(
            cmd=riscv_gdb_cmd,
            ports=self.openocd_session.gdb_ports,
            binary=binary)
        self.gdb_session.connect()

    def endGdb(self):
        del self.openocd_session
        del self.gdb_session

    def launchElf(self, binary, gdb_log=False, openocd_log=False, verify=True):
        """Launch a binary on the GFE using GDB
        
        Args:
            binary (string): path to riscv elf file 
            gdb_log (bool, optional): Print the gdb log
                if the gdb commands raise an exception
            openocd_log (bool, optional): Print openocd log
                if the openocd command raise an exception
        """

        if not self.gdb_session:
            self.startGdb()
        gdblog = open(self.gdb_session.logfiles[0].name, 'r')
        openocdlog = open(self.openocd_session.logfile.name, 'r')
        binary = os.path.abspath(binary)
        try:
            self.gdb_session.command("file {}".format(binary))
            self.gdb_session.load(verify)
            self.gdb_session.c(wait=False)
        except Exception as e:
            if gdb_log:
                print("------- GDB Log -------")
                print(gdblog.read())
            if openocd_log:
                print("------- OpenOCD Log -------")
                print(openocdlog.read())
            openocdlog.close()
            gdblog.close()
            raise e


    def runElfTest(
        self, binary, gdb_log=False, openocd_log=False, runtime=0.5,
        tohost=0x80001000):
        """Run a binary test on the GFE using GDB.
        
        Args:
            binary (string): path to riscv elf file 
            gdb_log (bool, optional): Print the gdb log
                if the gdb commands raise an exception
            openocd_log (bool, optional): Print openocd log
                if the openocd command raise an exception
            runtime (float, optional): Time (seconds) to wait while
                the test to run
            tohost (int, optional): Memory address to check for
                the passing condition at the end of the test.
                A "0x1" written to this address indicates the test passed
        
        Returns:
            (passed, msg) (bool, string): passed is true if the test passed 
                msg that can be printed to further describe the passing or 
                failure condition
        
        Raises:
            e: Exception from gdb or openocd if an error occurs (i.e. no riscv detected)
        """
        
        self.launchElf(binary=binary, gdb_log=gdb_log, openocd_log=openocd_log)
        time.sleep(runtime)
        self.gdb_session.interrupt()
        tohost_val = self.riscvRead32(tohost)
        msg = ""

        # Check if the test passed
        if tohost_val == 1:
            msg = "passed"
            passed = True
        elif tohost_val == 0:
            msg = "did not complete. tohost value = 0"
            passed = False
        else:
            msg = "failed"
            passed = False

        return (passed, msg)

    def getGdbLog(self):
        if self.gdb_session:
            with open(self.gdb_session.logfiles[0].name, 'r') as gdblog:
                data = gdblog.read()
            return data
        else:
            return "No gdb_session open."

    def riscvRead32(self, address, verbose=False, dbg_txt=""):
        """Read 32 bits from memory using the riscv core

        Args:
            address (int): Memory address

        Returns:
            int: Value at the address
        """
        if not self.gdb_session:
            self.startGdb()

        value = self.gdb_session.x(address=address, size="1w")

        if verbose:
            print("{} Read: {} from {}".format(dbg_txt, hex(value), hex(address)))

        return value

    def riscvWrite(self, address, value, size, verbose=False, dbg_txt=""):
        """Use GDB to perform a write with the synchronous riscv core

        Args:
            address (int): Write address
            value (int): Write value
            size (int): Write data size in bits (8, 32, or 64 bits)

        Raises:
            Exception: Invalid write size
        """

        size_options = {8: "char", 32: "int"}

        # Validate input
        if size not in size_options:
            raise Exception(
                "Write size {} must be one of {}".format(
                    size, size_options.keys()))

        if not self.gdb_session:
            self.startGdb()

        # Perform the write command using the gdb set command
        output = self.gdb_session.command(
            "set *(({} *) 0x{:x}) = 0x{:x}".format(
                size_options[size], address, value))

        if verbose:
            print("{} Write: {} to {}".format(dbg_txt, hex(value), hex(address)))

        # Check for an error message from gdb
        m = re.search("Cannot access memory", output)
        if m:
            raise testlib.CannotAccess(address)

    def riscvWrite32(self, address, value, verbose=False, dbg_txt=""):
        self.riscvWrite(address, value, 32, verbose=verbose, dbg_txt=dbg_txt)

    def softReset(self):
        print("Performing a soft reset of the GFE...")
        self.riscvWrite32(gfeparameters.RESET_BASE, gfeparameters.RESET_VAL)
        self.endGdb()
        self.startGdb()
        # Note: There is a bug that prevents loading an elf later in the test script
        # without first continuing and interrupting. This is fine for now, but may
        # not be compatible with future tests that require a completely clean start point
        self.gdb_session.c(wait=False)
        self.gdb_session.interrupt()

    # ------------------ UART Functions ------------------
    def findUartPort(
        self,
        search_vid=0x10C4,
        search_pid=0xEA70,
        port_num=1):

        # Get a list of all serial ports with the desired VID/PID
        ports = [port for port in serial.tools.list_ports.comports() if port.vid == search_vid and port.pid == search_pid]

        for port in ports:
            #print "Checking port: %s" % port.hwid
            # Silabs chip on VCU118 has two ports. Locate port 1 from the hardware description
            m = re.search('LOCATION=.*:1.(\d)', port.hwid)
            if m:
                if m.group(1) == '1':
                    print "Located UART device at %s with serial number %s" % (port.device, port.serial_number)
                    return port.device
        raise Exception(
                "Could not find a UART port with expected VID:PID = %X:%X" % (search_vid, search_pid))

    def setupUart(
        self,
        timeout=None, # wait forever on read data
        port=gfeparameters.uart_serial_dev, 
        baud=9600,
        parity="ODD",
        stopbits=2,
        bytesize=8):

        # Get the UART port
        if port == "auto":
            port = self.findUartPort()

        # Translate inputs into serial settings
        if parity.lower() == "odd":
            parity = serial.PARITY_ODD
        elif parity.lower() == "even":
            parity = serial.PARITY_EVEN
        elif parity.lower() == "none" or parity == None:
            parity = serial.PARITY_NONE
        else:
            raise Exception(
                "Parity {} must be even or odd".format(parity))

        if stopbits == 1:
            stopbits = serial.STOPBITS_ONE
        elif stopbits ==2:
            stopbits = serial.STOPBITS_TWO
        else:
            raise Exception(
                "Stop bits {} must be 1 or 2".format(stopbits))

        if bytesize == 5:
            bytesize = serial.FIVEBITS
        elif bytesize == 6:
            bytesize = serial.SIXBITS
        elif bytesize == 7:
            bytesize = serial.SEVENBITS
        elif bytesize == 8:
            bytesize = serial.EIGHTBITS
        else:
            raise Exception(
                "bytesize {} must be 5,6,7 or 8".format(bytesize))           

        # configure the serial connections 
        self.uart_session = serial.Serial(
            port=port,
            baudrate=baud,
            parity=parity,
            stopbits=stopbits,
            timeout=timeout,
            bytesize=bytesize
        )

        if not self.uart_session.is_open:
            self.uart_session.open()



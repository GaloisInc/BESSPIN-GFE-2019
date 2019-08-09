#!/usr/bin/env python
"""This script is used by ../../runOnLinux
- THIS IS A BACKUP FILE FOR THE manual sput and sput -b
This is not used anymore
"""

import threading
import warnings
import re
from test_gfe_unittest import *

class BaseGfeForLinux(BaseGfeTest):

    def read_uart_out_until_stop (self,run_event,stop_event):
        while (not stop_event.is_set()):
            run_event.wait()
            pending = self.gfe.uart_session.in_waiting
            if pending:
                data = self.gfe.uart_session.read(pending)
                sys.stdout.write(data)
            time.sleep(1)
        return

    def flush_uart_out (self,timeout=1):
        while (True):
            time.sleep (timeout)
            pending = self.gfe.uart_session.in_waiting
            if (not pending):
                return
            dump = self.gfe.uart_session.read(pending)
    
    def interpreter_sput (self, sourceFilePath, destFilePath, isBinary=False):
        ###check sourceFileExist
        sourceFilePath = os.path.expanduser(sourceFilePath)
        if (not os.path.isfile(sourceFilePath)):
            warnings.warn("%s: Cannot open or file does not exist. Press Enter to continue..." % (sourceFilePath), SyntaxWarning)
            return
        ###Check destFileExist + delete and create file
        self.gfe.uart_session.write('touch ' + destFilePath + '\r')
        try:
            self.check_uart_out(5,expected_contents=[], absent_contents="No such file or directory")
        except:
            warnings.warn("%s: Cannot open or file does not exist. Press Enter to continue..." % (destFilePath), SyntaxWarning)
            return
        self.gfe.uart_session.write('rm ' + destFilePath + '\r')
        self.gfe.uart_session.write('touch ' + destFilePath + '\r')
        fileToPut = sourceFilePath
        fileFromPut = destFilePath
        beginTime = time.time()
        if (isBinary):
            try:
                subprocess.call("busybox uuencode -m {0} < {0} >{0}.enc.orig".format(sourceFilePath), shell=True)
                #The encoded file has the wrong path which would cause issues when decoded. Also, using sed in-place will
                #truncate the file because of flushing limits (binary file has a very very long single line)
                #.enc.orig has the wrong path
                subprocess.call ("sed \'s:{0}:{1}:w {0}.enc\' {0}.enc.orig > dump; rm dump".format(sourceFilePath, destFilePath) ,shell=True)
                #.enc has the correct first line
                subprocess.call ("sed -i 1d {0}.enc.orig".format(sourceFilePath) ,shell=True)
                #.enc.orig now has the rest without the first line
                subprocess.call ("cat {0}.enc.orig >> {0}.enc".format(sourceFilePath) ,shell=True)
                #.enc now is ready. Should delete .enc.orig
                subprocess.call ("rm {0}.enc.orig".format(sourceFilePath) ,shell=True)
                print ("\n%s: Encoding successful. Now putting..." % (sourceFilePath))
            except:
                warnings.warn("%s: Failed to encode." % (sourceFilePath), RuntimeWarning)
                return
            fileToPut = sourceFilePath + '.enc'
            fileFromPut = destFilePath + '.enc'

        #Read source file
        try:
            time.sleep(0.1)
            inFile = open(fileToPut, "r")
            lines = inFile.readlines()
            inFile.close()
        except:
            warnings.warn("%s: Cannot open or file does not exist. Press Enter to continue..." % (fileToPut), SyntaxWarning)
            return
        ####MACROS
        numLinesPerPacket = 50
        waitBetweenLines = 0.1
        flushTimeout = 0.2
        #####
        numPackets = ((len(lines)-1) //  numLinesPerPacket ) + 1 #ceil division
        print ("\n%s will be divided into %d packets."%(sourceFilePath,numPackets))
        echoPrefix = "echo -n -e \""
        for iPacket in range(numPackets):
            iFileFromPut = fileFromPut + ".{0}".format(iPacket)
            echoSuffix = "\" >> " + iFileFromPut
            maxLimit = 255-len(echoPrefix)-len(echoSuffix)
            iLinesLimit = min((iPacket+1)*numLinesPerPacket,len(lines))
            for line in lines[iPacket*numLinesPerPacket:iLinesLimit]:
                numChunks = ((len(line)-1) // maxLimit) + 1  #ceil division
                for iChunk in range(0,len(line),maxLimit):
                    iLimit = min(iChunk+maxLimit, len(line))
                    self.gfe.uart_session.write(echoPrefix + line[iChunk:iLimit] + echoSuffix + '\r')
                    time.sleep(waitBetweenLines)
            self.flush_uart_out(flushTimeout)
            print (">>> Packet %d/%d done."%(iPacket+1,numPackets))

        print ("\nPutting complete. Now combining the packets...")
        for iPacket in range(numPackets):
            self.gfe.uart_session.write( "cat {0}.{1} >> {0}".format(fileFromPut,iPacket) + '\r')
            time.sleep(flushTimeout)
            self.gfe.uart_session.write( "rm {0}.{1}".format(fileFromPut,iPacket) + '\r')

        self.flush_uart_out(flushTimeout)

        if (isBinary):
            print ("\nCombining complete. Now decoding...")
            subprocess.call("rm " + fileToPut ,shell=True)
            self.gfe.uart_session.write('uudecode <' + fileFromPut + '\r')
            time.sleep (1)
            self.gfe.uart_session.write('rm ' + fileFromPut + '\r')
            time.sleep (1)
            print ("\nDecoding successful.")
        else:
            print ("\nCombining complete.")
        print ("\n Transmission speed was %d bytes in %d seconds." %(os.path.getsize(sourceFilePath), time.time()-beginTime))
        return

    def interactive_terminal (self):
        self.gfe.uart_session.write('stty -echo\r')
        print ("\nStarting interactive terminal...")
        stopReading = threading.Event() #event to stop the reading process in the end
        runReading = threading.Event() #event to run/pause the reading process
        readThread = threading.Thread(target=self.read_uart_out_until_stop, args=(runReading,stopReading))
        stopReading.clear()
        runReading.set()
        readThread.start() #start the reading
        warnings.simplefilter ("always")
        formatwarning_orig = warnings.formatwarning
        warnings.formatwarning = lambda message, category, filename, lineno, line=None: \
                            formatwarning_orig(message, category, filename, lineno, line='')
        exitTerminal = False
        while (not exitTerminal):
            instruction = raw_input ("")
            if (len(instruction)>2 and instruction[0:2]=='--'): #instruction to the interpreter
                if (instruction[2:6] == 'exit'): #exit terminal and end test
                    exitTerminal = True
                elif (instruction[2:6] == 'sput'): #copy a file from local to linux
                    sputbMatch = re.match(r'--sput -b (?P<sourceFilePath>[\w/.~-]+) (?P<destFilePath>[\w/.~-]+)\s*',instruction)
                    sputMatch = re.match(r'--sput (?P<sourceFilePath>[\w/.~-]+) (?P<destFilePath>[\w/.~-]+)\s*',instruction)
                    if (sputbMatch != None):
                        runReading.clear() #pause reading
                        self.interpreter_sput(sputbMatch.group('sourceFilePath'), sputbMatch.group('destFilePath'), isBinary=True)
                        runReading.set()
                    elif (sputMatch != None):
                        runReading.clear() #pause reading
                        self.interpreter_sput(sputMatch.group('sourceFilePath'), sputMatch.group('destFilePath'))
                        runReading.set()
                    else:
                        warnings.warn("Please use \"--sput [-b] sourceFilePath destFilePath\". Press Enter to continue...", SyntaxWarning)
                else:
                    warnings.warn("Interpreter command not found. Press Enter to continue...", SyntaxWarning)
            else:
                self.gfe.uart_session.write(instruction + '\r')
                time.sleep(1)
            
        stopReading.set()
        return

class RunOnLinux (TestLinux, BaseGfeForLinux):

    def test_busybox_terminal (self):
        # Boot busybox
        self.boot_linux()
        linux_boot_timeout=60

        print("Running elf with a timeout of {}s".format(linux_boot_timeout))
        # Check that busybox reached activation screen
        self.check_uart_out(
            timeout=linux_boot_timeout,
            expected_contents=["Please press Enter to activate this console"])

        # Send "Enter" to activate console
        self.gfe.uart_session.write(b'\r')
        time.sleep(1)

        #start interactive terminal
        self.interactive_terminal()
        time.sleep(2)
        return
    
    def test_debian_terminal(self):
        # Boot Debian
        self.boot_linux()
        linux_boot_timeout=800
        print("Running elf with a timeout of {}s".format(linux_boot_timeout))
        
        # Check that Debian booted
        self.check_uart_out(
                timeout=linux_boot_timeout,
                expected_contents=[ "Debian GNU/Linux 10",
                                    "login:"
                                    ])

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

        time.sleep(1)
        self.interactive_terminal()
        time.sleep(2)

        return

if __name__ == '__main__':
    unittest.main()
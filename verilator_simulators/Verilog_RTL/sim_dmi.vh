
`ifndef __SIM_DMI_VH__
`define __SIM_DMI_VH__

import "DPI-C" function int vpidmi_request(input int fd, output int addr, output int data, output int op);
import "DPI-C" function int vpidmi_response(input int fd, input int data, input int response);

`endif

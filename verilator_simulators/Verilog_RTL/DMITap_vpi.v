// Copyright (c) 2019 Bluespec, Inc.
// Modified by Dylan Hand, Galois, Inc

// This file is a plug-compatible replacement for DMITap in SSITH rocket P1/P2

`include "sim_socket.vh"
`include "sim_dmi.vh"

`define DEFAULT_DEBUG_PORT_VPI 5555
`define DELAY_VALUE 200

module DMITap(
  // These are the system clock and reset
  input clock,
  input reset,

  // These are the JTAG Clock and Reset
  // Can be ignored
  input dmi_in_dmiClock,
  input dmi_in_dmiReset,

  output        dmi_out_dmi_req_valid,
  input         dmi_out_dmi_req_ready,
  output [ 6:0] dmi_out_dmi_req_bits_addr,
  output [ 1:0] dmi_out_dmi_req_bits_op,
  output [31:0] dmi_out_dmi_req_bits_data,

  input         dmi_out_dmi_resp_valid,
  output        dmi_out_dmi_resp_ready,
  input  [ 1:0] dmi_out_dmi_resp_bits_resp,
  input  [31:0] dmi_out_dmi_resp_bits_data,

  input         dmi_in_dmi_req_valid,
  output        dmi_in_dmi_req_ready,
  input  [ 6:0] dmi_in_dmi_req_bits_addr,
  input  [ 1:0] dmi_in_dmi_req_bits_op,
  input  [31:0] dmi_in_dmi_req_bits_data,

  output        dmi_in_dmi_resp_valid,
  input         dmi_in_dmi_resp_ready,
  output [ 1:0] dmi_in_dmi_resp_bits_resp,
  output [31:0] dmi_in_dmi_resp_bits_data,

  output dmi_out_dmiClock,
  output dmi_out_dmiReset
);

   int port;
   int sock;
   int fd;
   int err;
   int delay_count;

   initial begin
      fd = -1;
      delay_count = 0;

      if ($value$plusargs("vpi_port=%d", port) == 0)
	port = `DEFAULT_DEBUG_PORT_VPI;

      $display("using debug port (vpi) :%d", port);

      sock = socket_open(port);
      if (sock < 0) begin
	 $display("ERROR: socket_open(%d) returned %d", port, sock);
	 $finish;
      end
   end

   // Passthrough clock and reset
   assign dmi_out_dmiClock = clock;
   assign dmi_out_dmiReset = reset;

   // Assign dmi_in (from Jtag Controller) to zero
   // DH: This is just a guess!! May need to alter
   // the ready & valid values
   assign dmi_in_dmi_req_ready  = 0;
   assign dmi_in_dmi_resp_valid = 0;
   assign dmi_in_dmi_resp_bits_resp = '0;
   assign dmi_in_dmi_resp_bits_data = '0;

   always @(posedge clock) begin
      if (reset) begin
	 dmi_out_dmi_req_valid <= 0;
	 dmi_out_dmi_req_bits_addr <= 0;
	 dmi_out_dmi_req_bits_data <= 0;
	 dmi_out_dmi_req_bits_op <= 0;
	 dmi_out_dmi_resp_ready <= 0;
      end
   end

   always @(posedge clock) begin
      if (~reset) begin
	 if (fd >= 0) begin
	    dmi_out_dmi_resp_ready <= 1;

	    if (dmi_out_dmi_resp_valid) begin
	       int data;
	       int response;
	       data = dmi_out_dmi_resp_bits_data;
	       response = {30'd0, dmi_out_dmi_resp_bits_resp};
	       err = vpidmi_response(fd, data, response);
	       if (err < 0) begin
		  $display("ERROR: vpidmi_response() returned %d", err);
		  $finish;
	       end
	    end

	    if (!dmi_out_dmi_req_valid || dmi_out_dmi_req_ready) begin
	       if (delay_count == 0) begin
		  int addr;
		  int data;
		  int op;
		  err = vpidmi_request(fd, addr, data, op);
		  if (err < 0) begin
		     $display("ERROR: vpidmi_request() returned %d", err);
		     $finish;
		  end
		  else if (err > 0) begin
		     dmi_out_dmi_req_valid <= 1;
		     dmi_out_dmi_req_bits_addr <= addr[6:0];
		     dmi_out_dmi_req_bits_data <= data;
		     dmi_out_dmi_req_bits_op <= op[1:0];
		     if (op[1:0] == 2) delay_count = `DELAY_VALUE; // if it's a write
		  end
		  else
		     dmi_out_dmi_req_valid <= 0;
	       end
	       else begin
		  delay_count = delay_count - 1;
		  dmi_out_dmi_req_valid <= 0;
	       end
	    end
	 end
	 else begin
	    fd = socket_accept(sock);
	 end
      end
   end

endmodule

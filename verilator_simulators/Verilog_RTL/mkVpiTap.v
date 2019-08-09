
`include "sim_socket.vh"
`include "sim_dmi.vh"

`define DEFAULT_DEBUG_PORT 5555


module mkJtagTap(
		 input 		 CLK,
		 input 		 RST_N,

		 input           jtag_tdi,
		 input     	 jtag_tms,
		 input           jtag_tclk,
		 output          jtag_tdo,

		 input 		 req_ready,
		 output reg 	 req_valid,
		 output reg [6:0]  req_addr,
		 output reg [31:0] req_data,
		 output reg [1:0]  req_op,

		 output reg 	 rsp_ready,
		 input 		 rsp_valid,
		 input [31:0] 	 rsp_data,
		 input [1:0] 	 rsp_response

		 output CLK_jtag_tclk_out,
		 output CLK_GATE_jtag_tclk_out
		 );

   int 				 port;
   int 				 sock;
   int 				 fd;
   int 				 err;

   initial begin
      fd = -1;

      if ($value$plusargs("debug_port=%d", port) == 0)
	port = `DEFAULT_DEBUG_PORT;

      $display("using debug port (vpi) :%d", port);

      sock = socket_open(port);
      if (sock < 0) begin
	 $display("ERROR: socket_open(%d) returned %d", port, sock);
	 $finish;
      end
   end

   always @(posedge CLK) begin
      if (!RST_N) begin
	 req_valid <= 0;
	 req_addr <= 0;
	 req_data <= 0;
	 req_op <= 0;
	 rsp_ready <= 0;
      end
   end

   always @(posedge CLK) begin
      if (RST_N) begin
	 if (fd >= 0) begin
	    rsp_ready <= 1;

	    if (rsp_valid) begin
	       int data;
	       int response;
	       data = rsp_data;
	       response = {30'd0, rsp_response};
	       err = vpidmi_response(fd, data, response);
	       if (err < 0) begin
		  $display("ERROR: vpidmi_response() returned %d", err);
		  $finish;
	       end
	    end

	    if (!req_valid || req_ready) begin
	       int addr;
	       int data;
	       int op;
	       err = vpidmi_request(fd, addr, data, op);
	       if (err < 0) begin
		  $display("ERROR: vpidmi_request() returned %d", err);
		  $finish;
	       end
	       else if (err > 0) begin
		  req_valid <= 1;
		  req_addr <= addr[6:0];
		  req_data <= data;
		  req_op <= op[1:0];
	       end
	       else
		 req_valid <= 0;
	    end
	 end
	 else begin
	    fd = socket_accept(sock);
	 end
      end
   end

endmodule

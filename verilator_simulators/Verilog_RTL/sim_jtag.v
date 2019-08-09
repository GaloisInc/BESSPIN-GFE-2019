
`include "sim_socket.vh"

`define DEFAULT_DEBUG_PORT_JTAG 5550

module sim_jtag(
		input 	   clk,
		input 	   rst_n,

		output reg tdi,
		output reg tms,
		output reg tclk,
		input 	   tdo
		);

   int 				 port;
   int 				 sock;
   int 				 fd;
   int 				 err;

   initial begin
      fd = -1;

      if ($value$plusargs("jtag_port=%d", port) == 0)
	 port = `DEFAULT_DEBUG_PORT_JTAG;

      $display("using debug port (rbb) :%d", port);

      sock = socket_open(port);
      if (sock < 0) begin
	 $display("ERROR: socket_open(%d) returned %d", port, sock);
	 $finish;
      end
   end

   always @(posedge clk) begin
      if (!rst_n) begin
	 tdi <= 0;
	 tms <= 0;
	 tclk <= 0;
      end
   end

   always @(posedge clk) begin
      if (rst_n) begin
	 if (fd >= 0) begin
	    err = socket_getchar(fd);
	    if (err >= 0) begin
	       case (err[7:0])
		 "B", "b": begin
		    // blink
		 end
		 "0", "1", "2", "3", "4", "5", "6", "7": begin
		    err[7:0] = err[7:0] - "0";
		    {tclk, tms, tdi} <= err[2:0];
		 end
		 "R": begin
		    err = socket_putchar(fd, {24'd0, tdo ? "1" : "0"});
		    if (err < 0) begin
		       $display("ERROR: socket_putchar() returned %d", err);
		       $finish;
		    end
		 end
		 "Q": begin
		    $display("rbb quit received");
		    //$finish;
		    fd = -1;
		 end
		 default: begin
		    // nothing
		 end
	       endcase
	    end
	 end
	 else begin
	    fd = socket_accept(sock);
	    if (fd>=0) $display("Connection accepted!");
	 end
      end
   end

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2019 11:10:57 PM
// Design Name: 
// Module Name: iobuf
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module iobuf(
    input data_i,
    output data_o,
    input data_t,
    inout io
    );
    
       IOBUF IOBUF_inst (
       .O(data_o),   // 1-bit output: Buffer output
       .I(data_i),   // 1-bit input: Buffer input
       .IO(io), // 1-bit inout: Buffer inout (connect directly to top-level port)
       .T(data_t)    // 1-bit input: 3-state enable input
    );
endmodule

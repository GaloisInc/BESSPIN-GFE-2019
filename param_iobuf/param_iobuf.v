`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/29/2019 3:30:43 PM
// Design Name: 
// Module Name: param_iobuf
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


module param_iobuf
    #(parameter WIDTH=1)
    (
    input [WIDTH-1:0] data_i,
    output [WIDTH-1:0] data_o,
    input [WIDTH-1:0] data_t,
    inout [WIDTH-1:0] io
    );
    

    genvar i;
    generate
        for (i=0; i<WIDTH; i=i+1) 
        begin : iobuf
            IOBUF IOBUF_inst (
            .O(data_o[i]),   // 1-bit output: Buffer output
            .I(data_i[i]),   // 1-bit input: Buffer input
            .IO(io[i]), // 1-bit inout: Buffer inout (connect directly to top-level port)
            .T(data_t[i])    // 1-bit input: 3-state enable input
            );
        end
    endgenerate

endmodule

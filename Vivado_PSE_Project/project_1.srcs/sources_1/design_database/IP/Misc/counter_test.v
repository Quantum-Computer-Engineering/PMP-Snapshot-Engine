`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/13/2024 12:11:35 AM
// Design Name: 
// Module Name: counter_test
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


module counter_test(
    input clk,
    input en,
    input rst,
    output reg [7:0] count
    );

    // Always block triggered on the positive edge of the clock or the negative edge of the reset
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            count <= 8'b0000;  // If reset is asserted (active low), set count to 0
        end else begin
            count <= count + 1;  // Otherwise, increment the counter
        end
    end
        
    
endmodule

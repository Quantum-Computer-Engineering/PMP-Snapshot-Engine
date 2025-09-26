`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/03/2024 04:51:27 PM
// Design Name: 
// Module Name: bram_interface
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


module bram_interface
#(
        parameter	LATENCY_IN_CYCLES	=	2
)(
    input               clk,
    input               reset,
    input               req,
    input               we_i,
    input [3:0]         be_i,
    output reg          valid,
    output reg [31:0]   wdata_bram_o,
    input [17:0]        addr_i,
    output reg [17:0]   addr_bram_o,
    output reg [3:0]    we_bram_o,
    output reg          bram_enable_o,
    input [31:0]        wdata_i
    );

    reg [15:0] counter;

    localparam IDLE=0, ACTIVE=1, DONE=2;
    reg [1:0]   state,
                nxtState;

    always @(posedge clk) begin
        if (!reset) 
        begin
            state <= IDLE; // Initial state
            nxtState <= IDLE;
            counter <= 0;
            valid <= 0;
        end 
        else 
        begin
            case (state)
                IDLE : begin
                    if (req) 
                    begin
                        nxtState = ACTIVE;

                        addr_bram_o <= addr_i;
                        wdata_bram_o <= wdata_i;
                        we_bram_o <= we_i ? be_i : 4'b0;
                        bram_enable_o <= 1;

                        // Increment counter already because switching states takes a cycles
                        counter <= counter + 1; 
                    end
                end

                ACTIVE : begin
                    counter <= counter + 1;  // Increment counter in ACTIVE state
                    if(counter >= LATENCY_IN_CYCLES - 1) // -1 because this state transition also takes one cycle
                    begin
                        nxtState = DONE;
                        valid <= 1;
                    end
                end

                DONE : begin
                    // Reset state and variables
                    addr_bram_o <= 0;
                    wdata_bram_o <= 32'h0;
                    we_bram_o <= 4'b0;
                    counter <= 0;            
                    valid <= 0;
                    bram_enable_o <= 0;

                    nxtState = IDLE;
                end
            endcase

            state <= nxtState;   
        end
    end

endmodule

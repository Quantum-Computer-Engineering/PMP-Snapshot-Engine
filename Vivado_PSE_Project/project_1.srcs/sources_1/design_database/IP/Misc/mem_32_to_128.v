`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/17/2024 12:17:04 PM
// Design Name: 
// Module Name: mem_32_to_128
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


module mem_32_to_128 #(
    parameter CACHE_LINE_WIDTH_BITS = 128,
    parameter	MEM_ADDR_BITS	=	15						
)
(
    input wire                              clk,
    input wire                              reset,

    input wire                              cache_line_req_i,
    input wire [MEM_ADDR_BITS-1	:0]	        cache_line_address_i,
    input wire                              cache_line_we_i,
    input wire                              bram_rvalid_i,
    input wire [31:0]                       bram_rdata_i,

    output reg                              bram_req_o,   
    output reg [31:0]	                    bram_address_o,
    output reg [CACHE_LINE_WIDTH_BITS-1:0]  cache_line_rdata_o,
    output reg                              cache_line_rvalid_o,

    input      [127:0]                      cache_line_wdata_i,
    output reg [31:0]                       cache_line_wdata_o,
    output reg                              cache_line_we_o

    );

    localparam IDLE=0, READ_WAIT=1, READ_RESPONSE=2, WRITE_WAIT=3, WRITE_RESPONSE=4, DONE=5;
    reg [2:0]   state, nxtState;
    reg [1:0]   req_counter;
    reg [1:0]   recv_counter;

    // Register to put together the 128 word to later write it to the output
    reg [CACHE_LINE_WIDTH_BITS-1:0] cache_line_rdata_reg;
    reg [31:0] bram_addr_reg;



    always @(posedge clk) begin

        if (!reset) 
        begin
            state <= IDLE; // Initial state
            nxtState <= IDLE;
            req_counter <= 0;
            recv_counter <= 0;
            bram_address_o <= 0;
            bram_addr_reg <= 0;
            cache_line_rdata_o <= 0;
            cache_line_rvalid_o <= 0;
        end 
        else 
        begin
            case (state)
                IDLE: begin
                    if (cache_line_req_i)
                    begin
                        nxtState = cache_line_we_i ? WRITE_WAIT : READ_WAIT;

                        // For writing
                        cache_line_we_o <= cache_line_we_i;
                        cache_line_wdata_o <= cache_line_wdata_i[127-:32];

                        // The 2 bit at the end are counted up four times
                        bram_addr_reg[MEM_ADDR_BITS+4-1 :0] = {cache_line_address_i, 4'b0};

                        bram_req_o <= 1;
                        bram_address_o <= bram_addr_reg;

                        // Increase to go for the next cell next round
                        req_counter <= req_counter + 1;
                    end
                end

                WRITE_WAIT: begin
                    bram_req_o <= 0;
                    
                    if (bram_rvalid_i)
                    begin
                        cache_line_wdata_o <= cache_line_wdata_i[32*(3-req_counter)+31 -: 32];


                        // Increase to go for the next cell next round
                        req_counter <= req_counter + 1;

                        if (req_counter == 0) // == 4 but overflown
                        begin
                            nxtState = WRITE_RESPONSE;   
                        end
                        else
                        begin
                            // Send next request for next memory cell
                            bram_req_o <= 1;
                            bram_addr_reg[MEM_ADDR_BITS+4-1 :0] = {cache_line_address_i, req_counter, 2'b0};
                            bram_address_o <= bram_addr_reg;
                        end
                    end
                end

                READ_WAIT: begin
                    bram_req_o <= 0;
                    
                    if (bram_rvalid_i)
                    begin
                        cache_line_rdata_reg[32*(3-recv_counter)+31 -: 32] <= bram_rdata_i;


                        // Increase to go for the next cell next round
                        req_counter <= req_counter + 1;
                        recv_counter <= recv_counter + 1;

                        if (recv_counter == 3)
                        begin
                            nxtState = READ_RESPONSE;   
                        end
                        else
                        begin
                            // Send next request for next memory cell
                            bram_req_o <= 1;
                            bram_addr_reg[MEM_ADDR_BITS+4-1 :0] = {cache_line_address_i, req_counter, 2'b0};
                            bram_address_o <= bram_addr_reg;
                        end
                    end
                end

                READ_RESPONSE:
                begin
                    cache_line_rvalid_o <= 1;
                    cache_line_rdata_o <= cache_line_rdata_reg;

                    nxtState = DONE;   
                end

                WRITE_RESPONSE:
                begin
                    cache_line_rvalid_o <= 1;

                    nxtState = DONE;   
                end

                DONE: begin
                    cache_line_rvalid_o <= 0;

                    req_counter <= 0;
                    recv_counter <= 0;
                    
                    nxtState = IDLE;
                end

            endcase
        end

        state <= nxtState;
    end

endmodule

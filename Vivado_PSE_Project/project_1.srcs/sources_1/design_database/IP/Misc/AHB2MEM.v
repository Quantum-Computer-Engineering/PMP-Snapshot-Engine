`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/18/2024 02:23:22 PM
// Design Name: 
// Module Name: AHB2MEM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Interface between AHB and BRAM
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module AHB2MEM
	#(
		parameter CPU_ADDR_BITS		=	32,
		parameter CPU_DATA_BITS		=	32,
		parameter MEM_ADDR_BITS		=	32,	
		parameter MEM_DATA_BITS		=	32,
		parameter MAIN_MEM_DELAY	=	100
	)
(
    //AHBLITE INTERFACE
    //Slave Select Signals
    input wire          HSEL,
    input wire          HCLK,
    input wire          HRESETn,
    input wire          HREADY,
    input wire [31:0]   HADDR,
    input wire [1:0]    HTRANS,
    input wire          HWRITE,
    input wire [2:0]    HSIZE,
    input wire [31:0]   HWDATA,
    output wire         HREADYOUT,
    output wire [31:0]  HRDATA,

    // TO BRAM
    output wire                     BRAM_MEM_REQ,
    output wire                     BRAM_MEM_WRITE,
    output wire [MEM_ADDR_BITS-1:0] BRAM_MEM_ADDR,
    output wire [MEM_DATA_BITS-1:0] BRAM_WDATA,
    input  wire [MEM_DATA_BITS-1:0] BRAM_RDATA,
    input  wire                     BRAM_MEM_VALID,
    output wire                     BRAM_RDY
    );


	
// Registers to store Adress Phase Signals
reg 							APhase_HWRITE;
reg 	[1:0] 					APhase_HTRANS;
reg 	[31:0] 					APhase_HADDR;
reg 	[2:0] 					APhase_HSIZE;
reg	    [31:0]					APhase_HWDATA;
reg                             APhase_HREADYOUT;

// Help signals for timing of data
reg                             DataPhase;

// WIRES TO CACHE
wire                            cache_req;
wire                            cache_rdy;
wire    [31:0]                  cache_din;



reg cache_req_reg;



// Assign signals 
// Set to 1 on start request, set to zero once ready
assign cache_req = (HSEL & (HTRANS ==2) & !BRAM_MEM_VALID); // ? 1 : (cache_rdy ? 0 : cache_req_reg)) ;
// assign cache_req = (HSEL & (HTRANS ==2) ? 1 : (cache_req_reg)) ;

always @(posedge HCLK, negedge HRESETn)
begin
    if(!HRESETn)
        cache_req_reg <= 0;
    else begin
        // if (!BRAM_MEM_VALID) begin
        cache_req_reg <= cache_req;
    // end else begin
        // cache_req_reg <= 0;
    end
end

// Select correct data to cache to deal with non-standard AHB behaviour
assign cache_din        = (DataPhase) ? HWDATA : APhase_HWDATA;
assign HREADYOUT        = APhase_HREADYOUT;
assign BRAM_MEM_REQ     = cache_req_reg; // & ~(HTRANS == 2);
assign BRAM_MEM_WRITE   = APhase_HWRITE;
assign BRAM_MEM_ADDR    = APhase_HADDR[31:0];
assign BRAM_WDATA       = cache_din;
assign cache_rdy        = BRAM_MEM_VALID;
assign HRDATA           = BRAM_RDATA;

// Main process to sample signals
always @(posedge HCLK, negedge HRESETn)
begin
    // RESET
    if(!HRESETn)
    begin
        APhase_HWRITE       <=  1'b0;
        APhase_HTRANS       <=  2'b00;
        APhase_HADDR        <=  32'h0;
		APhase_HSIZE 	    <=  3'b000;
        APhase_HWDATA       <=  32'h0;
        DataPhase           <=  1'b0;
        APhase_HREADYOUT    <=  1'b1;
    end
    // IF READY, SAMPLE INPUT
    else 
    begin
        // Store during address phase
        if (HREADY)
        begin
            APhase_HWRITE 	<= HWRITE;
            APhase_HTRANS 	<= HTRANS;
            APhase_HADDR 	<= HADDR;
            APhase_HSIZE 	<= HSIZE;
        end 
           
        // Cache data input logic
        if(HSEL & (HTRANS == 2))
        begin
            DataPhase       <=  1'b1;
        end
        else
        begin
            DataPhase       <=  1'b0;
        end
            
        // Read correct data during AHB data phase
        if (DataPhase)
        begin
            APhase_HWDATA   <=  HWDATA;
        end
            
        // Process to handle READY output
        if (cache_rdy)
        begin
            APhase_HREADYOUT <= 1'b1;
        end
        else if (HSEL & (HTRANS == 2))
        begin
            APhase_HREADYOUT <= 1'b0; 
        end
    end
end

endmodule

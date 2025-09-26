`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/11/2024 11:45:37 AM
// Design Name: 
// Module Name: AHB2ENCRYPTCTRL
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


module AHB2ENCRYPTCTRL
#(
    parameter N_KEY_SLOTS  	   =   4,
	parameter MEM_ADDR_BITS    =   15,
	parameter ENC_ENABLED  =   0
)
(
	input  wire [MEM_ADDR_BITS-1:0]	requested_mem_addr,
	output reg [127:0]				key_o,
	output reg 						key_valid_o,
	output reg  					enable_encryption,

	// AHB interface
	input wire 			HCLK,
	input wire 			HRESETn,
	input wire [31:0] 	HADDR,
	input wire [1:0] 	HTRANS,
	input wire 			HWRITE,
	input wire [31:0] 	HWDATA,
	input wire 			HSEL,
	input wire 			HREADY,
	
	output [31:0] 		HRDATA,
	output wire 		HREADYOUT
    
);
integer i;

localparam KEY_WIDTH  		= 128;
localparam ENABLE_BIT		=   1;


(* ram_style = "block" *) reg [0:KEY_WIDTH+(2*MEM_ADDR_BITS)+ENABLE_BIT-1] key_storage [0:N_KEY_SLOTS-1];


// Registers to store Adress Phase Signals
reg APhase_HSEL;
reg APhase_HWRITE;
reg [1:0] APhase_HTRANS;
reg [31:0] APhase_HADDR;

// Sample the Address Phase   
always @(posedge HCLK or negedge HRESETn)
begin
	if(!HRESETn)
	begin
	APhase_HSEL 	<= 	 1'b0;
	APhase_HWRITE 	<= 	 1'b0;
	APhase_HTRANS 	<=  2'b00;
	APhase_HADDR 	<=  32'h0;
	end
	else if(HREADY)
	begin
		APhase_HSEL 	<= HSEL;
		APhase_HWRITE 	<= HWRITE;
		APhase_HTRANS 	<= HTRANS;
		APhase_HADDR 	<= HADDR;
	end
end

wire [2:0] select_field; // 00 = key, 01 = starting address, 10 = end address
wire [$clog2(N_KEY_SLOTS)-1:0] select_keyslot;

assign select_field 	= APhase_HADDR[4:2];
assign select_keyslot 	= APhase_HADDR[$clog2(N_KEY_SLOTS)+5-1:5];

always @(posedge HCLK)
begin	
	if(APhase_HSEL & APhase_HWRITE & APhase_HTRANS[1])
	begin
		case (select_field)

		 	// Key 0-31
			3'b000 	: 	key_storage[select_keyslot][0:31] 		<= HWDATA;

		 	// Key 32-63
			3'b001 	: 	key_storage[select_keyslot][32:63] 		<= HWDATA;

		 	// Key 64-95
			3'b010 	: 	key_storage[select_keyslot][64:95] 		<= HWDATA;

		 	// Key 96-127
			3'b011 	: 	key_storage[select_keyslot][96:127] 	<= HWDATA;

			// Starting address
			3'b100 	: 	key_storage[select_keyslot][128:128+MEM_ADDR_BITS-1] <= HWDATA[MEM_ADDR_BITS+3:4];

			// end address
			3'b101 	: 	key_storage[select_keyslot][128+MEM_ADDR_BITS:128+(MEM_ADDR_BITS*2)-1] <= HWDATA[MEM_ADDR_BITS+3:4];

			// Enable
			3'b111 	: 	key_storage[select_keyslot][128+(MEM_ADDR_BITS*2)] 		<= HWDATA[0];
		endcase
	end
end

reg [MEM_ADDR_BITS-1:0] addr_low[0:N_KEY_SLOTS-1];
reg [MEM_ADDR_BITS-1:0] addr_high[0:N_KEY_SLOTS-1];
			

// Output according key
always @(*) begin
    
	key_o = 'b0; // Ensure key_o has a default value
	key_valid_o = 0;
	enable_encryption = 0;

    if ( ENC_ENABLED )
    begin
        for (i = 0; i < N_KEY_SLOTS; i = i + 1) 
        begin
            // Extract the two addresses from key_storage
            
            // Decode the storage contents
            addr_low[i] 	= key_storage[i][128:128+MEM_ADDR_BITS-1];
            addr_high[i] 	= key_storage[i][128+MEM_ADDR_BITS:128+(MEM_ADDR_BITS*2)-1];
            
            // Check if input_address falls in the range [addr_low, addr_high]
            if ((requested_mem_addr >= addr_low[i]) && (requested_mem_addr <= addr_high[i])) begin
                key_o = key_storage[i][0:127];
                key_valid_o = 1;
                enable_encryption = 1;
            end
        end
     end
end

// Write only peripheral 
assign HRDATA 		= 32'hC0FFEE00;
// Always ready
assign HREADYOUT 	= 1'b1;


endmodule


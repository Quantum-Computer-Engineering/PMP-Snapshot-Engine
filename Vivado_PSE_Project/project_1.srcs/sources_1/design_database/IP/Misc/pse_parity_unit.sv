`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/16/2025 04:51:01 PM
// Design Name: 
// Module Name: pse_parity_unit
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

// For genus synthesis add `include "cv32e40s_pkg.sv", 

module pse_parity_unit import cv32e40s_pkg::*;
#(
  parameter int PMP_ADDR_WIDTH      = 32, 
  parameter int PMP_CONFIG_WIDTH    = 8, 
  parameter int N_PARITY_BITS       = 1,
  parameter int BLOCK_SIZE          = 25,
  parameter int PSE_ENTRY_WIDTH     = 640,
  parameter bit USE_PARITY          = 1,
  parameter int COLUMN_PARITY_BITS  = 1
)
(
    input [(PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS-1:0]  pmp_csrs_i,
    input [N_PARITY_BITS-1:0]                   parity_bits_to_check_i,
    output                                      parity_invalid_o,
    output [PSE_ENTRY_WIDTH-1:0]                csrs_with_parity_o
);  
    
    // Dimensions of blocks
    localparam int N_FULL_BLOCKS    = (PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH) * PMP_MAX_REGIONS / BLOCK_SIZE;
    localparam int LAST_ROW_WIDTH   = ((PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS ) % BLOCK_SIZE;
    localparam int N_ROWS           = (LAST_ROW_WIDTH == 0) ? N_FULL_BLOCKS : N_FULL_BLOCKS + 1;

    
    logic [N_ROWS-1:0]       columns[BLOCK_SIZE];
        
    // 1 bit parity odd for each row
    logic [N_FULL_BLOCKS-1:0] parity_bits_per_full_row;   
    
    logic [3:0] csrs_rows[N_FULL_BLOCKS-1:0]; 
    
    for (genvar row = 0; row < N_FULL_BLOCKS; row++)
    begin
        /* Collecting for column parity */
        for (genvar i = 0; i < BLOCK_SIZE; i++)
        begin
            assign columns[i][row] = pmp_csrs_i[(row) * BLOCK_SIZE + i];
        end
        
        assign csrs_rows[row] = pmp_csrs_i[row * BLOCK_SIZE +: BLOCK_SIZE];
        
        assign parity_bits_per_full_row[row] = ^csrs_rows[row];
    end
    
    // Special treatment for last row 
    for (genvar i = 0; i < BLOCK_SIZE; i++)
    begin
        assign columns[i][N_ROWS-1] = (i < LAST_ROW_WIDTH) ? pmp_csrs_i[(N_ROWS-1) * BLOCK_SIZE + i] : 1'b0;
    end    
    

    
    // Column parities (count of ones modulo COLUMN_PARITY_BITS)
    logic [COLUMN_PARITY_BITS*BLOCK_SIZE-1:0]    column_parities;

    
	// Previous implementation probably inefficient
    /*for (genvar col = 0; col < BLOCK_SIZE; col++)
    begin
        localparam int PARITY_WEIGHT    = 2**COLUMN_PARITY_BITS;
        assign column_parities[col*COLUMN_PARITY_BITS +: COLUMN_PARITY_BITS] = $countones(columns[col]) % PARITY_WEIGHT;
    end*/

    // Popcount mod 2^k as a tiny adder (only k LSBs kept)
    function automatic [COLUMN_PARITY_BITS-1:0]
      mod2k_popcount (input logic [N_ROWS-1:0] v);
      automatic logic [COLUMN_PARITY_BITS-1:0] s;
      s = '0;
      for (int j = 0; j < N_ROWS; j++) begin
        s = s + v[j]; // natural wrap modulo 2^COLUMN_PARITY_BITS
      end
      return s;
    endfunction

	// Special-case k=1 to pure XOR (smallest)
    if (COLUMN_PARITY_BITS == 1) begin : gen_k1
      for (genvar col = 0; col < BLOCK_SIZE; col++) begin
        if (col < N_FULL_BLOCKS) begin
            assign column_parities[col] = ^columns[col];
        end else begin
            assign column_parities[col] = ^(columns[col][N_ROWS-1-1]);
        end
      end
    end else begin : gen_kN
      for (genvar col = 0; col < BLOCK_SIZE; col++) begin
        assign column_parities[col*COLUMN_PARITY_BITS +: COLUMN_PARITY_BITS] =
          mod2k_popcount(columns[col]);
      end
    end


    logic [N_ROWS-1:0] parity_bits_per_row;

	generate
	  if (LAST_ROW_WIDTH > 0) begin : gen_last_row

		// Special treatment for the last row because it is not completely full
	    logic [LAST_ROW_WIDTH-1:0] last_row;
        logic last_row_parity;
    
		assign last_row = pmp_csrs_i[N_FULL_BLOCKS * BLOCK_SIZE +: LAST_ROW_WIDTH];
		assign last_row_parity = ^last_row;

    	assign parity_bits_per_row = {parity_bits_per_full_row, last_row_parity};    

	  
      end else begin : gen_no_last_row

    	assign parity_bits_per_row = parity_bits_per_full_row;

	  end
	
    endgenerate
    	
    assign csrs_with_parity_o = USE_PARITY ? {pmp_csrs_i, parity_bits_per_row , column_parities} : pmp_csrs_i;

    if (USE_PARITY) begin
        assign parity_invalid_o = (parity_bits_to_check_i != {parity_bits_per_row, column_parities});
    end else begin
        assign parity_invalid_o = 1'b0;
    end
    
endmodule

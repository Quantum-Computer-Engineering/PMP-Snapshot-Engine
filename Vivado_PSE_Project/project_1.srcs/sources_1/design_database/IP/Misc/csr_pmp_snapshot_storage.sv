`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/10/2024 02:38:06 PM
// Design Name: 
// Module Name: csr_pmp_snapshot_storage
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
// and comment the pse_sram_black_box module definition 
// so it will treat it as a black box.


function automatic int optimal_block_size(input int entry_width_wo_parity, input int n_col_parity_bits);
    int res, mask, floor_val;
    int to_be_squared = entry_width_wo_parity / n_col_parity_bits;
    
    // Calculating the optimal block size with square-rooting to_be_squared
    begin
        res = 0;
        mask = 1 << 30; // start with the highest power of 4 <= max int
        while (mask > to_be_squared)
            mask >>= 2;

        while (mask != 0) begin
            if (to_be_squared >= res + mask) begin
                to_be_squared -= res + mask;
                res = (res >> 1) + mask;
            end else begin
                res >>= 1;
            end
            mask >>= 2;
        end
        
        if (res * res < (entry_width_wo_parity / n_col_parity_bits)) begin
            res = res + 1;
        end
            
        return res;
    end
endfunction

function automatic int unsigned ceil_div(input int unsigned a, input int unsigned b);
  return (a + b - 1) / b; // assumes b > 0
endfunction




module csr_pmp_snapshot_storage import cv32e40s_pkg::*;
#(
  parameter int PMP_ADDR_WIDTH      = 32,
  parameter int PMP_CONFIG_WIDTH    = 8,
  parameter int PMP_N_SLOT_REGIONS  = 8,
  parameter bit USE_PARITY          = 1,
  parameter bit ENABLE_COMPARISON_FAULT = 1
)
(
    input                                   clk,
    input                                   rst_n,
    input [$clog2(PMP_N_SLOT_REGIONS)-1:0]  slot_select,
    input                                   save_i,
    input                                   apply_i,
    input [PMP_ADDR_WIDTH-1:0]              pmp_addrs_i [PMP_MAX_REGIONS],
    input [PMP_CONFIG_WIDTH-1:0]            pmp_configs_i [PMP_MAX_REGIONS],
    
    output reg                              write_all_pmp_csrs_o,
    output [PMP_ADDR_WIDTH-1:0]             pmp_addrs_mem_o [PMP_MAX_REGIONS],
    output [PMP_CONFIG_WIDTH-1:0]           pmp_configs_mem_o [PMP_MAX_REGIONS],
    output wire                             rd_error_o


    );
    
// Some tests to make sure the block size is calculated properly
//initial begin
//    // inline tests
//    if (optimal_block_size(320, 1) != 18) $fatal("Test failed: optimal_block_size(320, 1) != 18, got %0d", optimal_block_size(320 ,1));
//    if (optimal_block_size(640, 1) != 26) $fatal("Test failed: optimal_block_size(640, 1) != 26, got %0d", optimal_block_size(640, 1));
//    if (optimal_block_size(2560,1) != 51) $fatal("Test failed: optimal_block_size(2560,1) != 51, got %0d", optimal_block_size(2560,1));
//    if (optimal_block_size(640, 2) != 18) $fatal("Test failed: optimal_block_size(640, 2)  != 18, got %0d", optimal_block_size(640, 2));
//    if (optimal_block_size(2560,2) != 36) $fatal("Test failed: optimal_block_size(2560,2)  != 36, got %0d", optimal_block_size(2560,2));
//    $display("All optimal_block_size() tests passed!");
//    $finish;
//end
   
   // -------------------------------------------------------------------------
   // FLATTENED MEMORIES : depth = number of slots, width = regions × addr width
   // -------------------------------------------------------------------------
   localparam int COLUMN_PARITY_BITS = 1; // Hamming distance = COLUMN_PARITY_BITS * 2, because D = d_r * d_c
   localparam int OPT_BLOCK_SIZE = optimal_block_size((PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS, COLUMN_PARITY_BITS);   
   localparam int N_PARITY_BITS = (ceil_div( (PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS, OPT_BLOCK_SIZE )) + (OPT_BLOCK_SIZE * COLUMN_PARITY_BITS);
   localparam int PSE_ENTRY_WIDTH  = USE_PARITY ? 
                                      (PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS + N_PARITY_BITS : 
                                      (PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS;
  
   localparam bit SRAM_AS_BLACK_BOX = 0;
   
   (* ram_style = "block" *)
   logic [PSE_ENTRY_WIDTH-1:0] snapshot_regions_mem
                                              [PMP_N_SLOT_REGIONS-1:0];


   // Packed version of incoming addresses (avoids operators on streaming concat)
   logic [PMP_ADDR_WIDTH*PMP_MAX_REGIONS-1:0] pmp_addrs_flat;
   logic [PMP_CONFIG_WIDTH*PMP_MAX_REGIONS-1:0] pmp_configs_flat;
   
   logic [(PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS-1:0] pmp_csr_flat;
   
   assign pmp_addrs_flat = {>>{pmp_addrs_i}};
   assign pmp_configs_flat = {>>{pmp_configs_i}};
   assign pmp_csr_flat = {pmp_addrs_flat, pmp_configs_flat};

   // -------------------------------------------------------------------------
   // PARITY LOGIC : Generates the parity bits during write and verifies during read
   // -------------------------------------------------------------------------  
   logic parity_invalid;
   logic [N_PARITY_BITS-1:0]                    extracted_parity_bits;
   logic [(PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS-1:0]   extracted_csr_bits;
   logic [PSE_ENTRY_WIDTH-1:0]                  pmp_csr_flat_with_parity;
   logic [(PMP_ADDR_WIDTH+PMP_CONFIG_WIDTH)*PMP_MAX_REGIONS-1:0] snapshot_q_flat_wo_parity;

   
   pse_parity_unit 
      #(
        .PMP_ADDR_WIDTH     ( PMP_ADDR_WIDTH ),
        .N_PARITY_BITS      ( N_PARITY_BITS ),
        .BLOCK_SIZE         ( OPT_BLOCK_SIZE ),
        .PSE_ENTRY_WIDTH    ( PSE_ENTRY_WIDTH ),
        .USE_PARITY         ( USE_PARITY ),
        .COLUMN_PARITY_BITS ( COLUMN_PARITY_BITS )
      )
   pse_parity_unit_0
   (
    
    .pmp_csrs_i                 ( pmp_csr_flat ),
    .parity_bits_to_check_i     ( extracted_parity_bits ),
    .parity_invalid_o           ( parity_invalid ),
    .csrs_with_parity_o         ( pmp_csr_flat_with_parity )
   );
   
  // Logic holding the output of the PSE storage 
  logic [PSE_ENTRY_WIDTH-1:0] snapshot_q_flat;

   
//(* black_box *) module pse_sram_black_box ( // clk, rst_n, addr, we, data_i, data_o);
  //  input clk, rst_n, we,
  //  input [$clog2(PMP_N_SLOT_REGIONS)-1:0]  addr,
  //  input [PSE_ENTRY_WIDTH-1:0] data_i,
  //  output [PSE_ENTRY_WIDTH-1:0] data_o );
 //endmodule
    
 generate
  if (SRAM_AS_BLACK_BOX && USE_PARITY) begin : GEN_SRAM_BB_PAR
      (* black_box *)  pse_sram_black_box u_bb (
          .clk  (clk),
          .rst_n(rst_n),
          .addr (slot_select),
          .we   (save_i),
          .data_i (pmp_csr_flat_with_parity),
          .data_o (snapshot_q_flat)
      );
  end 
  endgenerate 
  
  generate
  if (SRAM_AS_BLACK_BOX && !USE_PARITY) begin : GEN_SRAM_BB_NO_PAR
      (* black_box *)  pse_sram_black_box u_bb_no_par (          
          .clk  (clk),
          .rst_n(rst_n),
          .addr (slot_select),
          .we   (save_i),
          .data_i (pmp_csr_flat),
          .data_o (snapshot_q_flat)
      );
  end
endgenerate
  
   // -------------------------------------------------------------------------
   // WRITE SECTION  : store current PMP addresses when save_i is asserted
   // -------------------------------------------------------------------------
   always_ff @(posedge clk) begin
     if (save_i) 
     begin
       if (!SRAM_AS_BLACK_BOX) begin
           if (USE_PARITY) begin
             //$display("pmp_addrs_flat: %x", pmp_addrs_flat);
             //$display("pmp_configs_flat: %x", pmp_configs_flat);

             //$display("pmp_csr_flat: %x", pmp_csr_flat);
             //$display("pmp_csr_flat_with_parity: %x", pmp_csr_flat_with_parity);
             snapshot_regions_mem[slot_select] <= pmp_csr_flat_with_parity;
           end
           else begin
             snapshot_regions_mem[slot_select] <= pmp_csr_flat;
           end
       end
     end
   end

   // -------------------------------------------------------------------------
   // READ SECTION  : registered read from the selected slot
   // -------------------------------------------------------------------------
   always_ff @(posedge clk) begin
     if (!SRAM_AS_BLACK_BOX) begin
        snapshot_q_flat <= snapshot_regions_mem[slot_select];
     end
   end

   // Unpack the flat bus back into an array, preserving original bit order
   if (USE_PARITY) begin
       assign snapshot_q_flat_wo_parity = snapshot_q_flat[PSE_ENTRY_WIDTH-1:N_PARITY_BITS];
   end else begin 
       assign snapshot_q_flat_wo_parity = snapshot_q_flat[PSE_ENTRY_WIDTH-1:0];

   end
   
   for (genvar r = 0; r < PMP_MAX_REGIONS; r++) begin : gen_unpack
     localparam int ADDRS_BEGIN = PMP_CONFIG_WIDTH * PMP_MAX_REGIONS;
     
     assign pmp_addrs_mem_o[PMP_MAX_REGIONS-1-r] = 
                snapshot_q_flat_wo_parity[(ADDRS_BEGIN + r*PMP_ADDR_WIDTH) +: PMP_ADDR_WIDTH];
     
     assign pmp_configs_mem_o[PMP_MAX_REGIONS-1-r] = 
                snapshot_q_flat_wo_parity[r*PMP_CONFIG_WIDTH +: PMP_CONFIG_WIDTH];
   end

   // -------------------------------------------------------------------------
   // ONE-CYCLE PULSE FOR write_all_pmp_csrs_o ON apply_i RISING EDGE
   // -------------------------------------------------------------------------
   logic apply_i_q /* synthesis keep = 1 */; // TODO: Check without
  
   always_ff @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
       apply_i_q         <= 1'b0;
       write_all_pmp_csrs_o <= 1'b0;
     end else begin
       apply_i_q         <= apply_i;
       write_all_pmp_csrs_o <= apply_i & ~apply_i_q;
     end
   end

   // -------------------------------------------------------------------------
   // ERROR FLAG  : any word that does NOT match the inverted shadow
   // -------------------------------------------------------------------------
   logic comparison_fault;
   
   assign extracted_parity_bits = snapshot_q_flat[N_PARITY_BITS-1:0];
   //assign extracted_csr_bits  = snapshot_q_flat[PSE_ENTRY_WITDH-1:N_PARITY_BITS]; // Check whether redundant with snapshot_q_flat_wo...
   
   if (USE_PARITY) begin : gen_error                  
     if (ENABLE_COMPARISON_FAULT) begin
	 	assign comparison_fault = (pmp_csr_flat != snapshot_q_flat_wo_parity);
	 end else begin
		assign comparison_fault = 1'b0;
     end

	assign rd_error_o = parity_invalid || comparison_fault;
   end else begin
     assign comparison_fault = 1'b0;     
     assign rd_error_o = 1'b0;
   end
  
  
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/04/2024 11:48:03 AM
// Design Name: 
// Module Name: RISCV_CORE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Verilog wrapper module for system verilog module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module RISCV_CORE
#(
    parameter [31:0] BOOT_ADDRESS = 32'h80010000,
    parameter [31:0] PMP_NUM_REGIONS = 32,
    parameter [31:0] PMP_GRANULARITY = 0,
    parameter [31:0] DM_EXCEPTION_ADDRESS = 32'hD,
    parameter [31:0] DM_HALT_ADDRESS = 32'h0,
    parameter [31:0] HART_ID = 32'h0,
    parameter [31:0] MTVEC_ADDRESS = 32'h8081,
    parameter [3:0] MIMPID_PATCH = 4'b0100  // Arbitrary number for machine implementation ID  
)
(
    input wire         clk_i,
    input wire         rst_ni,
    input wire         scan_cg_en_i,

    // Instruction memory interface
    output wire        instr_req_o,
    input wire         instr_gnt_i,
    input wire         instr_rvalid_i,
    output wire [31:0] instr_addr_o,
    // output wire [1:0]  instr_memtype_o,
    // output wire [2:0]  instr_prot_o,
    // output wire        instr_dbg_o,
    input wire [31:0]  instr_rdata_i,
    // input wire         instr_err_i,
    
    output alert_major_o,

    // Data memory interface
    output wire        data_req_o,
    input wire         data_gnt_i,
    input wire         data_rvalid_i,
    output wire [31:0] data_addr_o,
    output wire [3:0]  data_be_o,
    output wire        data_we_o,
    output wire [31:0] data_wdata_o,
    // output wire [1:0]  data_memtype_o,
    // output wire [2:0]  data_prot_o,
    // output wire        data_dbg_o,
    input wire [31:0]  data_rdata_i,

    // Other signals
    output wire [63:0] mcycle_o,
    input wire [31:0]  irq_i,
    input wire         wu_wfe_i,
    // input wire         debug_req_i,
    // output wire        debug_havereset_o,
    // output wire        debug_running_o,
    // output wire        debug_halted_o,
    output wire [31:0] debug_pc_o,
    input wire         fetch_enable_i,
    input wire         fencei_flush_ack_i
    // output wire        core_sleep_o
);

    // Parameters (replace SystemVerilog parameterized types with constants)
    localparam integer LIB = 0;
    localparam integer RV32 = 0; // Assuming RV32I
    localparam integer B_EXT = 0;
    localparam integer M_EXT = 0;
    localparam integer DEBUG = 1;
    localparam integer DM_REGION_START = 32'hF0000000;
    localparam integer DM_REGION_END = 32'hF000FFFF;
    localparam integer DBG_NUM_TRIGGERS = 1;
    localparam integer PMA_NUM_REGIONS = 0;
    localparam integer CLIC = 0;
    localparam integer CLIC_ID_WIDTH = 5;
    localparam integer PMP_ENCRYPTION_ENABLED = 0;

    // Instantiate the cv32e40s_core module
    (* DONT_TOUCH = "TRUE" *)
    cv32e40s_core 
    #(
        .PMP_NUM_REGIONS(PMP_NUM_REGIONS),
        .PMP_GRANULARITY(PMP_GRANULARITY)
    )
    u_cv32e40s_core 
    (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .scan_cg_en_i(scan_cg_en_i),
        
        .boot_addr_i(BOOT_ADDRESS),
        .dm_exception_addr_i(DM_EXCEPTION_ADDRESS),
        .dm_halt_addr_i(DM_HALT_ADDRESS),
        .mhartid_i(HART_ID),
        .mimpid_patch_i(MIMPID_PATCH),
        .mtvec_addr_i(MTVEC_ADDRESS),

        // Instruction memory interface
        .instr_req_o(instr_req_o),
        .instr_gnt_i(instr_gnt_i),
        .instr_rvalid_i(instr_rvalid_i),
        .instr_addr_o(instr_addr_o),
        .instr_memtype_o( ),  // instr_memtype_o), // Unconnected because the memory interface does not use these
        .instr_prot_o( ),  // instr_prot_o),
        .instr_dbg_o( ),  // instr_dbg_o),
        .instr_rdata_i(instr_rdata_i),
        .instr_err_i ( 1'b0 ), 

        // Data memory interface
        .data_req_o(data_req_o),
        .data_gnt_i(data_gnt_i),
        .data_rvalid_i(data_rvalid_i),
        .data_addr_o(data_addr_o),
        .data_be_o(data_be_o),
        .data_we_o(data_we_o),
        .data_wdata_o(data_wdata_o),
        .data_memtype_o( ),  // data_memtype_o), // Unconnected because the memory interface does not use these
        .data_prot_o( ),  // data_prot_o),
        .data_dbg_o( ),  // data_dbg_o),
        .data_rdata_i(data_rdata_i),
        .data_err_i( 1'b0 ),  // data_err_i),

        // Cycle count
        .mcycle_o(mcycle_o),

        // Interrupts and other signals
        .irq_i(irq_i),
        .wu_wfe_i(wu_wfe_i),

        // Debug interface // Unconnected because debug not used yet
        .debug_req_i( 1'b0 ), // debug_req_i),
        .debug_havereset_o( ), // debug_havereset_o),
        .debug_running_o( ), // debug_running_o),
        .debug_halted_o( ), // debug_halted_o),
        .debug_pc_o(debug_pc_o),

        // CPU control signals
        .fetch_enable_i(fetch_enable_i),
        .core_sleep_o( ), // core_sleep_o)
        .fencei_flush_ack_i(fencei_flush_ack_i),

        // Used for PSE FI detection
        .alert_major_o(alert_major_o),

        // Security functionality not used yet
        .instr_reqpar_o (  ),         // secure
        .instr_gntpar_i ( 1'b0 ),         // secure
        .instr_rvalidpar_i ( 1'b0 ),      // secure
        .instr_achk_o (  ),           // secure
        .instr_rchk_i ( 5'b0 ),           // secure
        .data_gntpar_i  ( 1'b1              ),
        .data_rvalidpar_i ( 1'b1              ),
        .data_rchk_i    ( 5'b0              ),

        // CLIC (Not used here)
        .clic_irq_i         ( 1'h0 ),
        .clic_irq_id_i      ( 5'h0 ),
        .clic_irq_level_i   ( 8'h0 ),
        .clic_irq_priv_i    ( 2'h0 ),
        .clic_irq_shv_i     ( 1'b0 )
    );

endmodule
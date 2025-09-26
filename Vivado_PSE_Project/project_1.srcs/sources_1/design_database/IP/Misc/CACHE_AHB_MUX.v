`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/18/2024 03:12:47 PM
// Design Name: 
// Module Name: CACHE_AHB_MUX
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


module CACHE_AHB_MUX
#(
    parameter MEMORY_START_ADDRESS  = 32'h1c000000,
    parameter MEMORY_END_ADDRESS    = 32'h1cffffff
)
(
    input           clk_i,
    input           rst_ni,

    // Connected to core
    input               instr_req_i,
    output              instr_rvalid_o,
    input wire [31:0]   instr_addr_i,
    output [31:0]       instr_rdata_o,

    input           lsu_req_i,
    input [31:0]    lsu_addr_i,
    output [31:0]   lsu_rdata_o,
    input [31:0]    lsu_wdata_i,
    output          lsu_rvalid_o,
    input           lsu_we_i,
    input [3:0]     lsu_be_i,

    // To I-cache
    output wire        instr_req_o,
    input wire         instr_rvalid_i,
    output wire [31:0] instr_addr_o,
    input wire [31:0]  instr_rdata_i,
    // Outgoing connections to BRAM (later to D-Cache)
    output          data_req_o,
    output [31:0]   data_addr_o,
    input           bram_rvalid_i,
    output [31:0]   data_wdata_o,
    output          data_we_o,
    output [3:0]    data_be_o,
    input [31:0]    data_rdata_i,

    // I-Cache miss connections
    input               cache_instr_bram_req_i,
    input [31:0]        cache_instr_bram_addr_i,
    output reg          cache_instr_bram_rvalid_o,
    output reg [31:0]   cache_instr_bram_rdata_o,

    // D-Cache miss connections
    input               cache_data_bram_req_i,
    input [31:0]        cache_data_bram_addr_i,
    input [31:0]   cache_data_bram_wdata_i,
    input               cache_data_bram_we_i,
    output reg          cache_data_bram_rvalid_o,
    output reg [31:0]   cache_data_bram_rdata_o,
     
    // AHB-LITE MASTER PORT PERIPHERALS
    output wire [31:0]  dat_HADDR,
    output wire [ 2:0] 	dat_HBURST,
    output wire        	dat_HMASTLOCK,
    output wire [ 3:0] 	dat_HPROT,
    output wire [ 2:0] 	dat_HSIZE,
    output wire [ 1:0] 	dat_HTRANS,
    output wire [31:0] 	dat_HWDATA,
    output wire        	dat_HWRITE,
    input  wire [31:0] 	dat_HRDATA,
    input  wire        	dat_HREADY,
    input  wire        	dat_HRESP
    );


    reg		    ahb_req;
    wire	    ahb_gnt;
    wire	    ahb_rvalid;
    reg [31:0]  ahb_addr;
    reg		    ahb_we;
    reg [3:0]	ahb_be;
    wire [31:0]	ahb_rdata;
    reg [31:0]	ahb_wdata;

    wire current_address_is_in_memory_range;
    wire bram_gnt;

    localparam IDLE=0, ICACHE_TRANSACTION=1, DCACHE_TRANSACTION=2, MMPERIPH_TRANSACTION=3;
    reg [2:0]   state, nxtState;

    // Accessing the caches is separate from accessing the bus.
    // Therefore, there is no interference between these actions.
    assign instr_req_o = instr_req_i;
    assign instr_addr_o = instr_addr_i;
    assign instr_rvalid_o   = instr_rvalid_i;
    assign instr_rdata_o   = instr_rdata_i;

    assign current_address_is_in_memory_range = (lsu_addr_i >= MEMORY_START_ADDRESS) && (lsu_addr_i <= MEMORY_END_ADDRESS);

    assign lsu_rdata_o      = (state != MMPERIPH_TRANSACTION) ? data_rdata_i : ahb_rdata;
    assign lsu_rvalid_o     = (state == MMPERIPH_TRANSACTION) ? ahb_rvalid   : bram_rvalid_i; 

    // Send nothing to the data cache
    assign data_req_o       = current_address_is_in_memory_range ? lsu_req_i : 0;
    assign data_addr_o      = current_address_is_in_memory_range ? lsu_addr_i : 0;
    assign data_wdata_o     = current_address_is_in_memory_range ? lsu_wdata_i : 0;
    assign data_we_o        = current_address_is_in_memory_range ? lsu_we_i : 0;
    assign data_be_o        = current_address_is_in_memory_range ? lsu_be_i : 0;


    // Capture MM requests
    reg         mmperiph_req_outstanding;
    reg [31:0]  mmperiph_addr;
    reg         mmperiph_we;
    reg [3:0]   mmperiph_be;
    reg [31:0]  mmperiph_wdata;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            mmperiph_req_outstanding <= 0;
            mmperiph_addr   <= 0;
            mmperiph_we     <= 0;
            mmperiph_be     <= 0;
            mmperiph_wdata  <= 0;
        end 
        else if (lsu_req_i && !current_address_is_in_memory_range)
        begin
            mmperiph_req_outstanding <= 1;
            mmperiph_addr   <= lsu_addr_i;
            mmperiph_we     <= lsu_we_i;
            mmperiph_be     <= lsu_be_i;
            mmperiph_wdata  <= lsu_wdata_i;
        end
        else if (state == MMPERIPH_TRANSACTION) begin
            mmperiph_req_outstanding <= 0;
        end
    end

    reg icache_outstanding;
    reg dcache_outstanding;

    // This state machine comes into play when the cache needs to access the 
    // BRAM (because of a MISS). Because this is the only interface to the BRAM,
    // the accessed must be arbitrated. 
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state <= IDLE; 
            nxtState <= IDLE;
            icache_outstanding <= 0;
            dcache_outstanding <= 0;
        end 
        else 
        begin
            case (state)
                IDLE: begin
                    if (cache_instr_bram_req_i || icache_outstanding) begin
                        nxtState = ICACHE_TRANSACTION;
                        
                        // In case dcache request happens at the same time, 
                        // instr gets priority
                        if (cache_data_bram_req_i) begin
                            dcache_outstanding <= 1;
                        end
                    end
                    else if (cache_data_bram_req_i || dcache_outstanding) begin
                        nxtState = DCACHE_TRANSACTION;
                    end
                    else if (mmperiph_req_outstanding) begin
                        nxtState = MMPERIPH_TRANSACTION;
                    end
                end 

                ICACHE_TRANSACTION : begin
                    icache_outstanding <= 0;
                    if (cache_data_bram_req_i) 
                    begin
                        dcache_outstanding <= 1;    
                    end
                    if (ahb_rvalid) 
                    begin
                        nxtState = IDLE;
                    end
                end

                DCACHE_TRANSACTION : begin
                    dcache_outstanding <= 0;
                    if (cache_instr_bram_req_i) 
                    begin
                        icache_outstanding <= 1;    
                    end

                    if (ahb_rvalid) 
                    begin
                        nxtState = IDLE;
                    end
                end

                MMPERIPH_TRANSACTION : begin
                    if (cache_instr_bram_req_i) 
                    begin
                        icache_outstanding <= 1;    
                    end

                    // Only instr because data requests are send from the LSU
                    if (ahb_rvalid) 
                    begin
                        nxtState = IDLE;
                    end
                end
            endcase

            state <= nxtState;
        end
    end


    // Assignments based on state
    always @(*) begin
        case (state)
            IDLE: begin
                ahb_req = 0;
                ahb_addr = 0;
                ahb_we = 0;
                ahb_be = 0;
                ahb_wdata = 0;

                cache_instr_bram_rvalid_o   = 0;
                cache_data_bram_rvalid_o    = 0;
                cache_data_bram_rdata_o     = 0;
            end

            ICACHE_TRANSACTION: begin
                ahb_req         = 1; // cache_instr_bram_req_i; // Most be hold high instead of pulse
                ahb_addr        = cache_instr_bram_addr_i;
                ahb_we          = 0;        // I-Cache only reads
                ahb_be          = 4'b1111;  // Always full cache line
                ahb_wdata       = 0;        // Read only

                cache_instr_bram_rvalid_o   = ahb_rvalid;
                cache_instr_bram_rdata_o    = ahb_rdata;
            end

            DCACHE_TRANSACTION: begin
                ahb_req         = 1; // cache_instr_bram_req_i; // Most be hold high instead of pulse
                ahb_addr        = cache_data_bram_addr_i;
                ahb_we          = cache_data_bram_we_i; 
                ahb_be          = 4'b1111;  // Always full cache line because be is handled by cache already
                ahb_wdata       = cache_data_bram_wdata_i;        // Read only


                cache_data_bram_rvalid_o   = ahb_rvalid;
                cache_data_bram_rdata_o    = ahb_rdata;
            end

            MMPERIPH_TRANSACTION: begin
                ahb_req         = 1; // Most be hold high instead of pulse
                ahb_addr        = mmperiph_addr;
                ahb_we          = mmperiph_we; 
                ahb_be          = mmperiph_be;  // Always full cache line because be is handled by cache already
                ahb_wdata       = mmperiph_wdata;        // Read only
            end

            default: begin
                ahb_req = 0;
                ahb_addr = 0;
                ahb_we = 0;
                ahb_be = 0;
                ahb_wdata = 0;

            end
        endcase
    end


    // BURST not used yet
    assign dat_HBURST       = 3'h0;

    (* dont_touch = "true" *) core2ahb3lite
    #(
        .AHB_ADDR_WIDTH(32),
        .AHB_DATA_WIDTH(32)
    )
    lsu2ahb
    (
        .clk_i				(clk_i),
        .rst_ni				(rst_ni),

        .req_i				(ahb_req),
        .gnt_o				(ahb_gnt),
        .rvalid_o			(ahb_rvalid),
        .addr_i				(ahb_addr),
        .we_i				(ahb_we),
        .be_i				(ahb_be),
        .rdata_o			(ahb_rdata),
        .wdata_i			(ahb_wdata),

        .HADDR_o			(dat_HADDR),
        .HWDATA_o			(dat_HWDATA),
        .HRDATA_i			(dat_HRDATA),
        .HWRITE_o			(dat_HWRITE),
        .HSIZE_o			(dat_HSIZE),
        .HPROT_o			(dat_HPROT),
        .HTRANS_o			(dat_HTRANS),
        .HMASTLOCK_o		(dat_HMASTLOCK),
        .HREADY_i			(dat_HREADY)
    );

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/17/2024 01:41:48 PM
// Design Name: 
// Module Name: benchmark_output
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


module benchmark_output(
    input clk,
    input reset,
    input [31:0]    timer_counter_value,
    (* dont_touch = "yes" *) input           bm_gpio_1,
    (* dont_touch = "yes" *) input           bm_gpio_2,
    (* dont_touch = "yes" *) input           diff_mode_enable,
    output [31:0] cycles_bm1_o,
    output [31:0] cycles_bm2_o
    );
        
    // State machine is made up of three components
    // - next state logic
    // - state registers
    // - output logic
    
    parameter MAX_TIMER     = 32'h30d40;
    
    parameter IDLE          = 3'b000;
    parameter ACTIVE_1      = 3'b001;
    parameter ACTIVE_2      = 3'b010;
    parameter REPORTING_1   = 3'b011;
    parameter REPORTING_2   = 3'b100;

    (* dont_touch = "yes" *) reg [2:0] present_state, next_state;
    
    
    (* dont_touch = "yes" *) reg [31:0] t1_begin_cycles;
    (* dont_touch = "yes" *) reg [31:0] t1_end_cycles;
    (* dont_touch = "yes" *) reg [31:0] t2_begin_cycles;
    (* dont_touch = "yes" *) reg [31:0] t2_end_cycles;
    
    always @ (posedge clk)
    begin
        case(present_state)
        
        IDLE:
        begin
            if (bm_gpio_1 == 1'b1) begin
                next_state = ACTIVE_1;
                t1_begin_cycles = timer_counter_value;
            end
            else if (bm_gpio_2 == 1'b1) begin
                next_state = ACTIVE_2;
                t2_begin_cycles = timer_counter_value;
            end  
        end
    
        ACTIVE_1:
        begin
            if (bm_gpio_1 == 1'b0) begin
                next_state = REPORTING_1;
                t1_end_cycles = timer_counter_value;
            end
        end
       
        ACTIVE_2:
        begin
            if (bm_gpio_2 == 1'b0) begin
                next_state = REPORTING_2;
                t2_end_cycles = timer_counter_value;
            end
        end
        
        REPORTING_1, REPORTING_2:
        begin
            next_state = IDLE;
        end
    endcase
  end
        
    // Transition logic
    always @ (posedge clk or negedge reset)
    begin
        if (!reset) begin
            present_state <= IDLE;
            next_state <= IDLE;
            t1_begin_cycles <= 32'd0;
            t1_end_cycles <= 32'd0;
            t2_begin_cycles <= 32'd0;
            t2_end_cycles <= 32'd0;
        end
        else begin
            present_state <= next_state;
        end
    end
    
    assign cycles_bm1_o = diff_mode_enable ? t1_begin_cycles - t1_end_cycles : MAX_TIMER - t1_end_cycles;
    assign cycles_bm2_o = diff_mode_enable ? t2_begin_cycles - t2_end_cycles : MAX_TIMER - t2_end_cycles;
                
    
//    // Output logic
//    always @(posedge clk or posedge reset) begin
//        if (reset) begin
//            cycles_bm1_o <= 0;
//            cycles_bm1_o <= 1;
//        end else begin
//            case (present_state)
 
//                REPORTING_1: begin
//                    // Calculate cycle difference and output
//                    if(diff_mode_enable) 
//                        cycles_bm1_o <= t1_begin_cycles - t1_end_cycles;
//                    else
//                        cycles_bm1_o <= MAX_TIMER - t1_end_cycles;
//                end
                
//                REPORTING_2: begin
//                   // Calculate cycle difference and output
//                   if(diff_mode_enable) 
//                        cycles_bm2_o <= t2_begin_cycles - t2_end_cycles;
//                    else
//                        cycles_bm2_o <= MAX_TIMER - t2_end_cycles;
//                end
                
//                default: begin
//                    if(diff_mode_enable) begin
//                        cycles_bm1_o <= t1_begin_cycles - t1_end_cycles;
//                        cycles_bm2_o <= t2_begin_cycles - t2_end_cycles;
//                    end
//                    else begin
//                        cycles_bm1_o <= MAX_TIMER - t1_end_cycles;
//                        cycles_bm2_o <= MAX_TIMER - t2_end_cycles;
//                    end
//                end
                
//            endcase
//        end
//    end
    
   
endmodule

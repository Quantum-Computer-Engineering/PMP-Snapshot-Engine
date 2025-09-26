//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2023.1.1 (lin64) Build 3900603 Fri Jun 16 19:30:25 MDT 2023
//Date        : Tue Oct  1 15:24:47 2024
//Host        : TP-T480s running 64-bit Ubuntu 22.04.4 LTS
//Command     : generate_target Zynq_E40S_PMP_wrapper.bd
//Design      : Zynq_E40S_PMP_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module Zynq_E40S_PMP_wrapper
   (OUTPUT_LED_reset,
    OUTPUT_LEDs,
    sys_clock,
    sys_reset);
  output [0:0]OUTPUT_LED_reset;
  output [2:0]OUTPUT_LEDs;
  input sys_clock;
  input sys_reset;

  wire [0:0]OUTPUT_LED_reset;
  wire [2:0]OUTPUT_LEDs;
  wire sys_clock;
  wire sys_reset;

  Zynq_E40S_PMP Zynq_E40S_PMP_i
       (.OUTPUT_LED_reset(OUTPUT_LED_reset),
        .OUTPUT_LEDs(OUTPUT_LEDs),
        .sys_clock(sys_clock),
        .sys_reset(sys_reset));
endmodule

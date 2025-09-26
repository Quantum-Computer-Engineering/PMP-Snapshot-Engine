//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Tue Sep 23 11:37:10 2025
//Host        : qce-icdesignvm.ewi.tudelft.nl running 64-bit Red Hat Enterprise Linux 9.6 (Plow)
//Command     : generate_target E40S_with_Caches_wrapper.bd
//Design      : E40S_with_Caches_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module E40S_with_Caches_wrapper
   (MTIME_IRQ,
    OUTPUT_LED_reset,
    OUTPUT_LEDs,
    RsTx,
    sys_reset,
    sysclk_n,
    sysclk_p);
  output MTIME_IRQ;
  output [0:0]OUTPUT_LED_reset;
  output [2:0]OUTPUT_LEDs;
  output RsTx;
  input sys_reset;
  input sysclk_n;
  input sysclk_p;

  wire MTIME_IRQ;
  wire [0:0]OUTPUT_LED_reset;
  wire [2:0]OUTPUT_LEDs;
  wire RsTx;
  wire sys_reset;
  wire sysclk_n;
  wire sysclk_p;

  E40S_with_Caches E40S_with_Caches_i
       (.MTIME_IRQ(MTIME_IRQ),
        .OUTPUT_LED_reset(OUTPUT_LED_reset),
        .OUTPUT_LEDs(OUTPUT_LEDs),
        .RsTx(RsTx),
        .sys_reset(sys_reset),
        .sysclk_n(sysclk_n),
        .sysclk_p(sysclk_p));
endmodule

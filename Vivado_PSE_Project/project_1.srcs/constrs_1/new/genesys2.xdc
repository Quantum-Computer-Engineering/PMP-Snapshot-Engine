## Genesys 2 (inspired by https://github.com/Digilent/digilent-xdc/blob/master/Genesys-2-Master.xdc)

set_property -dict { PACKAGE_PIN T28   IOSTANDARD LVCMOS33 } [get_ports { OUTPUT_LEDs[0] }]; #IO_L11N_T1_SRCC_14 Sch=led[0]
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { OUTPUT_LEDs[1] }]; #IO_L19P_T3_A10_D26_14 Sch=led[1]
set_property -dict { PACKAGE_PIN U30   IOSTANDARD LVCMOS33 } [get_ports { OUTPUT_LEDs[2] }]; #IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=led[2]
set_property -dict { PACKAGE_PIN U29   IOSTANDARD LVCMOS33 } [get_ports { OUTPUT_LED_reset }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=led[3]

set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { MTIME_IRQ }];

## Clock Signal
set_property -dict { PACKAGE_PIN AD11  IOSTANDARD LVDS     } [get_ports { sysclk_n }]; #IO_L12N_T1_MRCC_33 Sch=sysclk_n
set_property -dict { PACKAGE_PIN AD12  IOSTANDARD LVDS     } [get_ports { sysclk_p }]; #IO_L12P_T1_MRCC_33 Sch=sysclk_p

# Reset
set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { sys_reset }]; #IO_0_14 Sch=cpu_resetn

### UART
# PMOD Header JA
set_property -dict { PACKAGE_PIN U27   IOSTANDARD LVCMOS33 } [get_ports { RsTx }];

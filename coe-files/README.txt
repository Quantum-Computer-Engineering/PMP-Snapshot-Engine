This directory contains the coe-files (for loading into Vivado's BRAM) and the corresponding .lst files for:

1. Running it on the FPGA (Task 1 and 2 run indefinetly. All messages are printed via UART).
2. The FI simulation file without PSE (Task 2 tries to access Task 1's data. Messages are skipped ot reduce simulation time)
3. The FI simulation file with PSE (same as 2)

Additionally, the bitstream file for 1 is added so it can immediately run on a Genesys2 board.


Below, the configs in rtos_config.h are added for clarity.


# ------------------ For 1: ------------------ #

// Setting for FI setup 
#define FI_VIVADO_SIMULATION_SETUP 0
#define SKIP_UART_PRINT FI_VIVADO_SIMULATION_SETUP

// Let Task 2 try to access task1's secret_data for FI experiments
#define FI_EXPERIMENT_SETUP 0

// Activate PSE (PMP Snapshot Engine)
#define PSE_ACTIVATED 1

// Normal settings

#if (FI_VIVADO_SIMULATION_SETUP == 0)
    // Clock of FPGA board
    #define CPU_CLOCK_HZ 20000000u

    // Low frequency for FPGA to see the prints (UART is slow)
    #define TICK_RATE_HZ 1u
#else
    // Clock in QEMU
    #define CPU_CLOCK_HZ 10000000u

    // For FI simulation, use 100Hz tick rate to speed up the experiment
    #define TICK_RATE_HZ 100u
#endif

// RTOS configuration parameters
#define MAX_TASKS 8
#define TASK_STACK_SIZE 1024

#define N_PMP_REGIONS 16

#define configMTIME_BASE_ADDRESS 0x0200BFF8
#define configMTIMECMP_BASE_ADDRESS 0x02004000


# --------------- For 2 and 3: --------------- #

---- Configuration in rtos_config.h ----

#ifndef RTOS_CONFIG_H
#define RTOS_CONFIG_H

// Configuration for Fault Injection (FI) experiments

// Setting for FI setup 
#define FI_VIVADO_SIMULATION_SETUP 1
#define SKIP_UART_PRINT FI_VIVADO_SIMULATION_SETUP

// Let Task 2 try to access task1's secret_data for FI experiments
#define FI_EXPERIMENT_SETUP 1

// Activate PSE (PMP Snapshot Engine)
#define PSE_ACTIVATED 0/1


// Normal settings

...
same as above
...


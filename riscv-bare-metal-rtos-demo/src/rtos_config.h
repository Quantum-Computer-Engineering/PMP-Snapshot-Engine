#ifndef RTOS_CONFIG_H
#define RTOS_CONFIG_H

// Configuration for Fault Injection (FI) experiments

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


#endif // RTOS_CONFIG_H
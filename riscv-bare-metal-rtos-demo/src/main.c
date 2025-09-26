/*
 ============================================================================
 Name        : main.c
 Author      : Christian Larmann
 Version     :
 Copyright   : Your copyright notice
 Description : Minimal bare metal RTOS example for RISC-V
 ============================================================================
 */

#include "rtos_config.h"
#include "bare_metal_rtos.h"
#include "tasks.h"

__attribute__((section(".task1_stack"))) unsigned int task1_stack[1024]; // Stack for Task 1
__attribute__((section(".task2_stack"))) unsigned int task2_stack[1024]; // Stack for Task 2

// External linker symbols
extern unsigned int __task1_text_begin;
extern unsigned int __task1_text_end;
extern unsigned int __task2_text_begin;
extern unsigned int __task2_text_end;

extern unsigned int __task1_stack_begin;
extern unsigned int __task1_stack_end;
extern unsigned int __task2_stack_begin;
extern unsigned int __task2_stack_end;

extern unsigned int _common_memory_begin;
extern unsigned int _common_memory_end;

PRIVILEGED_FUNCTION void main()
{
    // Verify that the compiler uses correct types
    if ((4 != sizeof(unsigned int)) || (8 != sizeof(unsigned long long)))
    {
        write_uart("Error: Type sizes do not match the hardware register sizes.\n");
        while (1)
            ;
    }

    initialize_bare_metal_rtos();

    // PMP settings for tasks using linker-defined stack boundaries
    pmp_settings_t pmp_settings_task1 = {
        .pmp_addr = {
            0x10000000 >> 2, // To also include uart
            PMP_ADDR(_common_memory_end),
            PMP_ADDR(__task1_stack_begin),
            PMP_ADDR(__task1_stack_end),
            PMP_ADDR(__task1_text_begin),
            PMP_ADDR(__task1_text_end),
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        .pmp_cfg = {( 0 << 0 ) | ((PMP_CFG_RWX | PMP_CFG_TOR) << 8) | ( 0 << 16 ) | ((PMP_CFG_RW | PMP_CFG_TOR) << 24), 
                    ( 0 << 0 ) | ((PMP_CFG_X | PMP_CFG_TOR) << 8), 
                    PMP_CFG_DISABLED, PMP_CFG_DISABLED}};

    pmp_settings_t pmp_settings_task2 = {
        .pmp_addr = {
            0x10000000 >> 2, // To also include uart
            PMP_ADDR(_common_memory_end),
            PMP_ADDR(__task2_stack_begin),
            PMP_ADDR(__task2_stack_end),
            PMP_ADDR(__task2_text_begin),
            PMP_ADDR(__task2_text_end),
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        .pmp_cfg = {( 0 << 0 ) | ((PMP_CFG_RWX | PMP_CFG_TOR) << 8) | ( 0 << 16 ) | ((PMP_CFG_RW | PMP_CFG_TOR) << 24), 
                    ( 0 << 0 ) | ((PMP_CFG_X | PMP_CFG_TOR) << 8), 
                    PMP_CFG_DISABLED, PMP_CFG_DISABLED}};

    #if ( PSE_ACTIVATED == 1 )
        pmp_settings_t pmp_settings_task1_duplicate = {
            .pmp_addr = {
                0x10000000 >> 2, // To also include uart
                PMP_ADDR(_common_memory_end),
                PMP_ADDR(__task1_stack_begin),
                PMP_ADDR(__task1_stack_end),
                PMP_ADDR(__task1_text_begin),
                PMP_ADDR(__task1_text_end),
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            .pmp_cfg = {( 0 << 0 ) | ((PMP_CFG_RWX | PMP_CFG_TOR) << 8) | ( 0 << 16 ) | ((PMP_CFG_RW | PMP_CFG_TOR) << 24), 
                        ( 0 << 0 ) | ((PMP_CFG_X | PMP_CFG_TOR) << 8), 
                        PMP_CFG_DISABLED, PMP_CFG_DISABLED}};

        pmp_settings_t pmp_settings_task2_duplicate = {
            .pmp_addr = {
                0x10000000 >> 2, // To also include uart
                PMP_ADDR(_common_memory_end),
                PMP_ADDR(__task2_stack_begin),
                PMP_ADDR(__task2_stack_end),
                PMP_ADDR(__task2_text_begin),
                PMP_ADDR(__task2_text_end),
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            .pmp_cfg = {( 0 << 0 ) | ((PMP_CFG_RWX | PMP_CFG_TOR) << 8) | ( 0 << 16 ) | ((PMP_CFG_RW | PMP_CFG_TOR) << 24), 
                        ( 0 << 0 ) | ((PMP_CFG_X | PMP_CFG_TOR) << 8), 
                        PMP_CFG_DISABLED, PMP_CFG_DISABLED}};
    #endif /* ( PSE_ACTIVATED == 1 ) */

    #if ( PSE_ACTIVATED == 0 )  
        bare_metal_rtos_create_task("Task1", task1_stack, sizeof(task1_stack), task1_function, &pmp_settings_task1);
        bare_metal_rtos_create_task("Task2", task2_stack, sizeof(task2_stack), task2_function, &pmp_settings_task2);
    #else
        bare_metal_rtos_create_task("Task1", task1_stack, sizeof(task1_stack), task1_function, &pmp_settings_task1, &pmp_settings_task1_duplicate);
        bare_metal_rtos_create_task("Task2", task2_stack, sizeof(task2_stack), task2_function, &pmp_settings_task2, &pmp_settings_task2_duplicate);
    #endif /* ( PSE_ACTIVATED == 1 ) */

    run_scheduler();

    /* Should not reach here */
    while (1)
    {
    }
}



PRIVILEGED_FUNCTION void load_access_fault(void)
{
    #if ((FI_EXPERIMENT_SETUP == 1) && (FI_VIVADO_SIMULATION_SETUP == 1))
    // For FI simulation, write done_sig=1, pass_sig=0
    asm volatile(
        "li a0, 0x1F100000\n" // GPIOs
        "li a1, 0b1000000000000\n"
        "sw a1, 0(a0)\n");
    #endif

    // Handle load access fault
    write_uart("Load access fault occurred!\n");
    write_uart("mepc: ");

    uint32_t mepc_value;
    asm volatile("csrr %0, mepc" : "=r"(mepc_value));

    write_uart_int(mepc_value);
    write_uart("\n");

    while (1)
    {
        // Infinite loop to halt execution
    }
}

PRIVILEGED_FUNCTION void major_alert_exception(void)
{
    #if (FI_EXPERIMENT_SETUP == 1)
    // For FI simulation, write done_sig=1, pass_sig=0
    asm volatile(
        "li a0, 0x1F100000\n" // GPIOs
        "li a1, 0b1000000000000\n"
        "sw a1, 0(a0)\n");
    #endif

    // Handle major alert exception
    write_uart("Major alert exception occurred!\n");

    while (1)
    {
        // Infinite loop to halt execution
    }
}

PRIVILEGED_FUNCTION void pmp_configuration_fault(void)
{
    // Handle PMP configuration fault
    write_uart("PMP configuration fault occurred!\n");

    while (1)
    {
        // Infinite loop to halt execution
    }
}
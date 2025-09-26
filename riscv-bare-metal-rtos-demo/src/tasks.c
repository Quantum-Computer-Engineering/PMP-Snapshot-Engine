#include "tasks.h"

__attribute__((section(".task1_stack"))) unsigned int secret_data = -1;

/* Task 1 implementation */
__attribute__((section(".task1_text"))) void task1_function(void *params)
{
    while (1)
    {
        // Perform task-specific operations
        write_uart("<Task 1 running>\n");

        // In assembly, only modify caller-saved (temporary) registers to avoid corrupting important state.
        asm volatile(
            "li x5, 5\n"   // t0
            "li x6, 6\n"   // t1
            "li x7, 7\n"   // t2
            "li x28, 28\n" // t3
            "li x29, 29\n" // t4
            "li x30, 30\n" // t5
            "li x31, 31\n" // t6
        );

        // Turn LED 0 off (to see it running on real hardware)
        // asm volatile(
        //     "li a0, 0x1F100000\n" // GPIOs
        //     "li a1, 0b0\n"
        //     "sw a1, 0(a0)\n");

// Delay for 2 seconds
#if (FI_VIVADO_SIMULATION_SETUP == 0)
        rtos_delay(3000);
#else
        rtos_delay(10);
#endif

        secret_data = 42; // Example operation to modify a variable
    }
}

/* Task 2 implementation */
__attribute__((section(".task2_text"))) void task2_function(void *params)
{
    while (1)
    {
        // Perform task-specific operations
        #if (SKIP_UART_PRINT == 0)
            write_uart("<Task 2 running>\n");
        #endif

        #if (FI_EXPERIMENT_SETUP == 1)
        #if (SKIP_UART_PRINT == 0)
            write_uart("Task 2 tries to access secret_data...\n");
        #endif
        volatile int local_var = secret_data;

        // Secret data access successful!
        // For FI simulation, write done_sig=1, pass_sig=1
        asm volatile(
            "li a0, 0x1F100000\n" // GPIOs
            "li a1, 0b1100000000000\n"
            "sw a1, 0(a0)\n");
        #endif

        // Turn LED 0 on (to see it running on real hardware)
        // asm volatile(
        //     "li a0, 0x1F100000\n" // GPIOs
        //     "li a1, 0b1\n"
        //     "sw a1, 0(a0)\n");


    #if (FI_VIVADO_SIMULATION_SETUP == 0)
            // Delay for 5 seconds
            rtos_delay(5000);
    #else
            rtos_delay(20);
    #endif
    }
}
#include "bare_metal_rtos.h"

// Global tick counter for the RTOS
PRIVILEGED_DATA static unsigned int tick_count = 0;

// Global task list and task counter
PRIVILEGED_DATA task_control_block_t task_list[MAX_TASKS];
PRIVILEGED_DATA unsigned int task_count = 0;

size_t g_tcb_size = sizeof(task_control_block_t);

// Global current task index (-1 means no current task)
PRIVILEGED_DATA int current_task_index = -1;

// Stack for idle task
__attribute__((section(".task_stacks"))) unsigned int idletask_stack[1024]; // Stack for idle task
void idle_task(void *params);

void initialize_bare_metal_rtos()
{
    // Set mtvec to trap handler
    uintptr_t vec = 0x80000801; // 0x80000800 base | VECTORED (bit 0 = 1)
    asm volatile("csrw mtvec, %0" ::"r"(vec));

    // Idle task is put at position 0 in the task list
    #if ( PSE_ACTIVATED == 0 )  
        bare_metal_rtos_create_task("IdleTask", idletask_stack, sizeof(idletask_stack), idle_task, NULL);
    #else
        bare_metal_rtos_create_task("IdleTask", idletask_stack, sizeof(idletask_stack), idle_task, NULL, NULL);
    #endif /* ( PSE_ACTIVATED == 1 ) */

    #if ( PSE_ACTIVATED == 0 )  
        write_uart("Bare Metal RTOS initialized (PSE deactivated)\n");
    #else
        write_uart("Bare Metal RTOS initialized (PSE activated)\n");
    #endif /* ( PSE_ACTIVATED == 1 ) */

    // Additional initialization code can be added here
}

// Hardware timer registers
unsigned long long ullNextTime = 0ULL;
unsigned int const ullMachineTimerCompareRegisterBase = configMTIMECMP_BASE_ADDRESS;
volatile unsigned long long *pullMachineTimerCompareRegister = NULL;
const size_t uxTimerIncrementsForOneTick = (size_t)((CPU_CLOCK_HZ) / (TICK_RATE_HZ)); /* Assumes increment won't go over 32-bits. */

void init_tick_timer(void)
{
    unsigned int ulCurrentTimeHigh, ulCurrentTimeLow;
    volatile unsigned int *const pulTimeHigh = (volatile unsigned int *const)((configMTIME_BASE_ADDRESS) + 4UL); /* 8-byte type so high 32-bit word is 4 bytes up. */
    volatile unsigned int *const pulTimeLow = (volatile unsigned int *const)(configMTIME_BASE_ADDRESS);
    volatile unsigned int ulHartId;

    pullMachineTimerCompareRegister = (volatile unsigned long long *)ullMachineTimerCompareRegisterBase;

    do
    {
        ulCurrentTimeHigh = *pulTimeHigh;
        ulCurrentTimeLow = *pulTimeLow;
    } while (ulCurrentTimeHigh != *pulTimeHigh);

    ullNextTime = (unsigned long long)ulCurrentTimeHigh;
    ullNextTime <<= 32ULL; /* High 4-byte word is 32-bits up. */
    ullNextTime |= (unsigned long long)ulCurrentTimeLow;
    ullNextTime += (unsigned long long)uxTimerIncrementsForOneTick;
    *pullMachineTimerCompareRegister = ullNextTime;

    /* Prepare the time to use after the next tick interrupt. */
    ullNextTime += (unsigned long long)uxTimerIncrementsForOneTick;
}

#if (PSE_ACTIVATED == 0)
void bare_metal_rtos_create_task(const char *name, unsigned int *stack_begin, const unsigned int stack_size, void (*const task_func)(void *), pmp_settings_t *pmp_settings)
#else
void bare_metal_rtos_create_task(const char *name, unsigned int *stack_begin, const unsigned int stack_size, void (*const task_func)(void *), pmp_settings_t *pmp_settings, pmp_settings_t *pmp_settings_duplicate)
#endif
{
    // Check if we have space for another task
    if (task_count >= MAX_TASKS)
    {
        write_uart("Error: Maximum number of tasks reached\n");
        return;
    }

    // Check for valid parameters
    if (name == NULL || task_func == NULL || stack_size == 0)
    {
        write_uart("Error: Invalid task parameters\n");
        return;
    }

    // Get the next available task slot
    task_control_block_t *new_task = &task_list[task_count];

    // Initialize the task control block
    strncpy(new_task->name, name, sizeof(new_task->name) - 1);
    new_task->name[sizeof(new_task->name) - 1] = '\0'; // Ensure null termination

    new_task->task_func = task_func;
    new_task->stack_size = stack_size;
    new_task->stack_ptr = stack_begin + (stack_size / 4);
    new_task->state = TASK_READY;
    new_task->tick_count = 0;
    new_task->is_ready = 1;
    new_task->is_privileged = (NULL == pmp_settings);

    // If PMP settings are provided, copy them; otherwise, use default settings
    if (pmp_settings)
    {
        new_task->pmp_settings = *pmp_settings;
    }

    #if (SKIP_UART_PRINT == 0)
        write_uart("Setting up task context...\n");
    #endif

    // Write first context to the stack
    extern void task_context_init_asm(unsigned int *stack_ptr, void (*task_func)(void *), int is_privileged);
    task_context_init_asm(new_task->stack_ptr, task_func, new_task->is_privileged);

    // Set current task index to the new task
    // (only needed for PSE actually but also here to make sure it does not break anything else)
    current_task_index = task_count;

    #if ( PSE_ACTIVATED == 1 )
        // Skip idle task for PSE
        if (current_task_index != 0) 
        {
            write_uart("(If it crashes in QEMU, deactivate the PSE)\n");
            // PMP Snapshot Engine specific initialization
            fi_resilient_task_pmp_init(pmp_settings, pmp_settings_duplicate);
            #if (SKIP_UART_PRINT == 0)
                write_uart("PMP settings configured for task. Now saving snapshot... (Does not work in QEMU)\n");
            #endif
        }
    #endif

    // Increment task count
    task_count++;

    #if (SKIP_UART_PRINT == 0)
        write_uart("Task created successfully\n");
    #endif
}

void rtos_delay(unsigned int delay_ms)
{
    // Calls syscall_process_delay via ecall
    // delay_ms is passed in a0
    asm volatile("li a7, %0" : : "i"(SYSCALL_NUM_DELAY));
    asm volatile("ecall");
}

task_control_block_t *syscall_process_delay(unsigned int delay_ms)
{
    // Step 1: Add the delay to current_task.tick_count
    if (current_task_index >= 0 && current_task_index < task_count)
    {
        // Convert milliseconds to ticks: delay_ms * TICK_RATE_HZ / 1000
        unsigned int delay_ticks = (delay_ms * TICK_RATE_HZ) / 1000;

        // If delay is less than 1 tick, make it at least 1 tick
        if (delay_ticks == 0 && delay_ms > 0)
        {
            delay_ticks = 1;
        }

        // Set the wake-up time for the current task
        task_list[current_task_index].tick_count = tick_count + delay_ticks;

        // Step 2: Set current_task.is_ready = 0
        task_list[current_task_index].is_ready = 0;
        task_list[current_task_index].state = TASK_WAITING;

        #if (SKIP_UART_PRINT == 0)
            write_uart(task_list[current_task_index].name);
            write_uart(" sleeps for ");
            write_uart_int(delay_ms);
            write_uart(" ms\n");
        #endif
    }

    // Step 3: Find the next ready task
    int next_task_index = 0; // Default to idle task
    for (unsigned int i = 1; i < task_count; i++)
    {
        if (task_list[i].state == TASK_READY && task_list[i].is_ready == 1)
        {
            next_task_index = i;
            break;
        }
    }

    // Step 4: Update current_task such that it points to the next ready task
    current_task_index = next_task_index;

    task_list[current_task_index].state = TASK_RUNNING;

    #if (SKIP_UART_PRINT == 0)
        write_uart("Switching to task: ");
        write_uart(task_list[current_task_index].name);
        write_uart("\n");

        /* Was used for debugging */
        // if (current_task_index == 0)
        // {
        //     // Debug print
        //     write_uart("mepc: ");

        //     uintptr_t entry_address = (uintptr_t) task_list[current_task_index].stack_ptr; 
        //     entry_address -= 16; // Point to mepc
        //     uint32_t* mepc_pointer = (uint32_t*) entry_address;

        //     write_uart_hex(*mepc_pointer);

        //     write_uart("\n");
        // }

    #endif

    return &task_list[current_task_index]; // Return the function pointer of the next task
}

void idle_task(void *params)
{
    // This function is called when no tasks are ready to run
    // params is unused for the idle task
    (void)params; // Suppress unused parameter warning

    while (1)
    {
        // Idle loop - can be used for low-power mode or other tasks
        // write_uart("Idle task running...\n");

        #if (SKIP_UART_PRINT == 0)
            // write_uart("Idle: ");

            // volatile unsigned int *const pulTimeLow = (volatile unsigned int *const)(configMTIME_BASE_ADDRESS);
            // unsigned int temp = *pulTimeLow;

            // write_uart_int(temp);
            // write_uart("\n");
        #endif

        // Optionally, you can add a small delay or sleep here
        for (volatile int i = 0; i < 100000; i++)
            ;

    }
}

void syscall_process_yield()
{
    // TODO: For later
}

// This function would be called by the hardware timer interrupt.
// It should increment the system tick count and perform any necessary
// scheduling actions, upon which it returns the next task to run
task_control_block_t *tick_interrupt_handler(void)
{
    tick_count++;

    /* Update mtimecmp - equivalent to portUPDATE_MTIMER_COMPARE_REGISTER macro */
    {
        volatile unsigned int *compare_reg = (volatile unsigned int *)pullMachineTimerCompareRegister;
        volatile unsigned int *next_time_ptr = (volatile unsigned int *)&ullNextTime;

        // Load the current ullNextTime values
        unsigned int low_word = next_time_ptr[0];  // Low 32 bits
        unsigned int high_word = next_time_ptr[1]; // High 32 bits

        // Update the 64-bit mtimer compare match value in two 32-bit writes
        // Step 1: Write 0xFFFFFFFF to low word to prevent spurious interrupts
        compare_reg[0] = 0xFFFFFFFF;

        // Step 2: Write high word first (no smaller than new value)
        compare_reg[1] = high_word;

        // Step 3: Write low word last
        compare_reg[0] = low_word;

        // Calculate next tier value (ullNextTime += uxTimerIncrementsForOneTick)
        unsigned int timer_increment = uxTimerIncrementsForOneTick;
        unsigned int new_low = low_word + timer_increment;
        unsigned int carry = (new_low < low_word) ? 1 : 0; // Check for overflow
        unsigned int new_high = high_word + carry;

        // Store the new ullNextTime value
        next_time_ptr[0] = new_low;
        next_time_ptr[1] = new_high;
    }

    // Assign current task as default
    task_control_block_t *next_task = &task_list[current_task_index];

    // Only switch if currently running idle task (simplified scheduling logic)
    if (current_task_index == 0) 
    {
        /* Check whether a task becomes ready */
        for (unsigned int i = 1; i < task_count; i++)
        {
            // Check if the task is waiting (sleeping) and its wake-up time has arrived
            if (task_list[i].state == TASK_WAITING && task_list[i].tick_count <= tick_count)
            {
                // Wake up the task
                task_list[i].state = TASK_READY;
                task_list[i].is_ready = 1;
                task_list[i].tick_count = 0; // Reset tick count

                write_uart("Task ");
                write_uart(task_list[i].name);
                write_uart(" woken up.\n");

                // Very simple scheduling logic
                current_task_index = i;
                next_task = &task_list[i];

            }
        }
    }

    // Additional code for handling task switching can be added here

    return next_task;
}

void handle_external_interrupt(void)
{
    // This function would handle external interrupts
    // For this example, we will just print a message indicating an external interrupt occurred
    write_uart("External interrupt occurred\n");

    // In a real RTOS, you would handle the interrupt and possibly switch tasks
}

void run_scheduler(void)
{
    // This function would implement the scheduling logic to switch between tasks
    // For this example, we will just print a message indicating that the scheduler is running

    write_uart("Scheduler is running...\n");

    #if (SKIP_UART_PRINT == 0)
        // Wait until UART FIFO is empty after all the init prints
        // Otherwise, the tick interrupt may occur while printing and does not catch up
        while (!is_uart_fifo_empty())
            ;
    #endif

    // Setup and enable timer interrupt
    init_tick_timer();
    timer_irq_enable();

    #if ( PSE_ACTIVATED == 1 ) 
        // For FI protection of PSE
        major_alert_irq_enable();
    #endif /* ( PSE_ACTIVATED == 1 ) */

    while (1)
    {
        // In a real RTOS, this would involve checking the task states and switching context as needed
        // For now, we will just simulate a context switch by printing the task names
        for (unsigned int i = 1; i < task_count; i++)
        {
            if (task_list[i].state == TASK_READY)
            {
                // Set this as the current running task
                current_task_index = i;
                task_list[i].state = TASK_RUNNING;

                // Setup context and call the task function
                launch_task_asm(&task_list[i]);

                // If we reach here, the task has returned (shouldn't normally happen)
                // Reset the task state
                task_list[i].state = TASK_READY;
                current_task_index = 0;
            }
        }

        // If no tasks are ready, print a message and continue
        if (current_task_index == 0)
        {
            write_uart("No ready tasks, running idle task.\n");
            // Small delay to prevent flooding the UART
            for (volatile int j = 0; j < 100000; j++)
                ;
        }
    }
}

void timer_irq_enable(void)
{
    // Timer specific int bit
    unsigned int mie;
    asm volatile("csrr %0, mie" : "=r"(mie));
    mie |= (0x1 << 7);
    asm volatile("csrw mie, %0" ::"r"(mie));

    // Set global interrupt enable bit
    asm volatile("csrs mstatus, %0" ::"i"(0x8));
}

void major_alert_irq_enable(void)
{
    // Enable interrupt at bit 3
    unsigned int mie;
    asm volatile("csrr %0, mie" : "=r"(mie));
    mie |= (0x1 << 3);
    asm volatile("csrw mie, %0" ::"r"(mie));

    // Set global interrupt enable bit
    asm volatile("csrs mstatus, %0" ::"i"(0x8));
}

void global_irq_disable(void)
{
    // Only reset global interrupt enable bit
    asm volatile("csrc mstatus, %0" ::"i"(0x8));
}

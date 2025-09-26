#ifndef BARE_METAL_RTOS_H
#define BARE_METAL_RTOS_H

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "io.h"
#include "rtos_config.h"
#include "pmp.h"

#if ( PSE_ACTIVATED == 1 )
    #include "pmp.h"
#endif  

// Maximum number of tasks supported
#define MAX_TASKS 8

#define PRIVILEGED_FUNCTION     __attribute__( ( section( ".priv_functions" ) ) )
#define PRIVILEGED_DATA         __attribute__( ( section( ".priv_data" ) ) )

// Task states
typedef enum
{
    TASK_IDLE = 0,
    TASK_READY,
    TASK_RUNNING,
    TASK_WAITING
} task_state_t;

// System call numbers
#define SYSCALL_NUM_DELAY 1 

// Task control block structure
typedef struct
{
    unsigned int *stack_ptr;    // Stack pointer
    void (*task_func)(void *);  // Task function pointer
    unsigned int is_privileged; // Privileged flag
    pmp_settings_t pmp_settings;// PMP settings for the task
    char name[16];              // Task name
    void *params;               // Task parameters
    unsigned int stack_size;    // Stack size
    task_state_t state;         // Current task state
    unsigned int tick_count;    // Tick count for delays
    _Bool is_ready;             // Ready flag
} task_control_block_t;

// Global task list
extern task_control_block_t task_list[MAX_TASKS];
extern unsigned int task_count;

// Global current task index (-1 means no current task)
extern int current_task_index;

/* Initialize the bare metal RTOS */
PRIVILEGED_FUNCTION void initialize_bare_metal_rtos(void);

/* Create a new task in the RTOS */
#if (PSE_ACTIVATED == 0)
PRIVILEGED_FUNCTION void bare_metal_rtos_create_task(const char *name, unsigned int *stack_begin, const unsigned int stack_size, void (*const task_func)(void *), pmp_settings_t *pmp_settings);
#else
PRIVILEGED_FUNCTION void bare_metal_rtos_create_task(const char *name, unsigned int *stack_begin, const unsigned int stack_size, void (*const task_func)(void *), pmp_settings_t *pmp_settings, pmp_settings_t *pmp_settings_duplicate);
#endif

/* Tick interrupt */
PRIVILEGED_FUNCTION void init_tick_timer(void);
PRIVILEGED_FUNCTION task_control_block_t *tick_interrupt_handler(void);

/* Start scheduler */
PRIVILEGED_FUNCTION void run_scheduler(void);

/* Control interrupts */
PRIVILEGED_FUNCTION void timer_irq_enable(void);
PRIVILEGED_FUNCTION void major_alert_irq_enable(void);
PRIVILEGED_FUNCTION void global_irq_disable(void);

/* Assembly context switching function */
PRIVILEGED_FUNCTION void launch_task_asm(task_control_block_t *task_tcb);
void rtos_delay(unsigned int delay_ms);

/* Kernel function to process delay syscalls */
PRIVILEGED_FUNCTION task_control_block_t *syscall_process_delay(unsigned int delay_ms);

#endif // BARE_METAL_RTOS_H
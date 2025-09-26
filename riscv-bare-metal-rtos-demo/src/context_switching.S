# RISC-V Context Switching Assembly Functions
# This file implements low-level context switching for the bare metal RTOS

.section .text
.align 2

# External symbols from C code
.extern current_task_index
.extern task_list
.extern g_tcb_size

# Function: launch_task_asm
# Purpose: Save kernel context on current stack and launch a task
# Parameters: a0 = pointer to task_control_block_t
# Note: This function saves all caller-saved registers and switches to task context

.globl launch_task_asm
.type launch_task_asm, @function

launch_task_asm:
    # Save kernel context on current stack
    # We need to save all registers that the kernel might be using
    
    # Save return address and stack pointer
    addi sp, sp, -128           # Allocate space for register save area
    
    # Save caller-saved registers (ra, t0-t6, a0-a7)
    sw ra, 0(sp)                # Return address
    sw t0, 4(sp)                # Temporary registers
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    sw a1, 32(sp)               # Function arguments (a0 already in use)
    sw a2, 36(sp)
    sw a3, 40(sp)
    sw a4, 44(sp)
    sw a5, 48(sp)
    sw a6, 52(sp)
    sw a7, 56(sp)
    
    # Save callee-saved registers (s0-s11)
    sw s0, 60(sp)               # Saved registers
    sw s1, 64(sp)
    sw s2, 68(sp)
    sw s3, 72(sp)
    sw s4, 76(sp)
    sw s5, 80(sp)
    sw s6, 84(sp)
    sw s7, 88(sp)
    sw s8, 92(sp)
    sw s9, 96(sp)
    sw s10, 100(sp)
    sw s11, 104(sp)
    
    # a0 contains pointer to task_control_block_t
    # Load task's stack pointer from TCB
    # Assuming stack_ptr is at offset 16 in the TCB structure
    lw t0, 0(a0)               # Load task's stack_ptr from TCB
    
    # Switch to task's stack
    mv sp, t0                   # Switch to task stack

    # Restore the task's context and launch the task
    j trap_return

.size launch_task_asm, .-launch_task_asm

# Function: trap_handler_asm
# Purpose: Main trap/exception handler that dispatches syscalls based on a0
# Parameters: a0 = syscall number
# Note: This function handles both interrupts and system calls

.globl trap_handler_asm
.type trap_handler_asm, @function

trap_handler_asm:
    # Save all registers on the stack
    addi sp, sp, -128           # Allocate space for register save
    
    # Save all registers
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    sw a0, 32(sp)               # Save syscall number
    sw a1, 36(sp)
    sw a2, 40(sp)
    sw a3, 44(sp)
    sw a4, 48(sp)
    sw a5, 52(sp)
    sw a6, 56(sp)
    sw a7, 60(sp)
    sw s0, 64(sp)
    sw s1, 68(sp)
    sw s2, 72(sp)
    sw s3, 76(sp)
    sw s4, 80(sp)
    sw s5, 84(sp)
    sw s6, 88(sp)

    sw s7, 92(sp)
    sw s8, 96(sp)
    sw s9, 100(sp)
    sw s10, 104(sp)
    sw s11, 108(sp)

    // Check for Load access fault (mcause=5)
    li t0, 1  // Instr access fault
    csrr t1, mcause
    beq t0, t1, load_access_fault
    li t0, 5  // Load access fault
    beq t0, t1, load_access_fault

    // Save current PC
    csrr t0, mepc               # Read machine exception program counter
    addi t0, t0, 4              # Increment PC to next instruction
    sw t0, 112(sp)              # Save it on the stack

    // Save mstatus register
    csrr t0, mstatus
    sw t0, 116(sp)              # Save mstatus on the stack

    /* Update top of stack pointer */
    la t1, current_task_index  
    lw t1, 0(t1)             # t1 = task index

    la t2, g_tcb_size
    lw t2, 0(t2)             # t2 = tcb size (in bytes)
    mul t0, t1, t2           # t0 = task item offset in task_list
    la t1, task_list
    add t0, t1, t0           # Add base address of TCBs
    addi t2, sp, 128
    sw t2, 0(t0)             # Save stack pointer in TCB

    # Check the cause of the trap
    csrr t0, mcause             # Read machine cause register
    
    # Check if it's an interrupt (MSB set) or exception
    bltz t0, handle_interrupt   # If MSB set, it's an interrupt
    
    # Syscall dispatch table
    # Syscall number is in a7, dispatch based on its value
    beqz a7, syscall_yield      # a0 = 0: task yield
    li t2, 1
    beq a7, t2, syscall_delay   # a0 = 1: delay
    li t2, 2

    /* No more syscalls defined yet */
    
    # Unknown syscall - handle error
    j syscall_unknown

handle_interrupt:
    # Handle timer and other interrupts
    andi t0, t0, 0x7FF          # Mask off interrupt bit
    li t1, 7                    # Machine timer interrupt
    beq t0, t1, timer_interrupt
    
    # Other interrupts - for now just return
    j trap_return

.globl timer_interrupt
timer_interrupt:
    # Call the C timer interrupt handler
    # Preserve stack pointer in a register
    mv s0, sp
    
    # Call tick_interrupt_handler (C function)
    call tick_interrupt_handler

    # Handle task switching if needed
    # a0 holds a boolean indicating if a task switch is needed
    # current_task_index holds the index of the task that needs to be switched to
    
#     # Check if task switch is needed (a0 != 0)
#     beqz a0, no_task_switch     # If a0 is 0, no task switch needed
    
switch_to_task_in_current_task_index:

    # a0 points to the address of current_task_index
    lw sp, 0(a0)              # Load sp

    j trap_return

no_task_switch:
    # Restore stack pointer
    mv sp, s0
    j trap_return

syscall_yield:
    # Task yield syscall - switch to scheduler
    # For now, just return (scheduler would be called here)
    j trap_return

syscall_delay:
    # Delay/sleep syscall
    # a0 contains delay value (already in the right register)
    lw a0, 32(sp)               # Load delay parameter from saved a0
    call syscall_process_delay  # Call C syscall processing function
    bnez a0, switch_to_task_in_current_task_index


    # If syscall_process_delay returns NULL, switch to idle task
    la t0, idle_task  # Load address of idle task function
    csrw mepc, t0
    li t0, 0x1880  # Set MPP to 0b11 (M-mode) and MPIE to 1
    csrw mstatus, t0
    // Idle task does nothing, so no context switch needed
    mret
    

syscall_unknown:
    // Get stuck in an infinite loop for unknown syscalls
    j syscall_unknown

trap_return:
    # If task is privileged, configure PMP
    la t1, current_task_index  
    lw t1, 0(t1)             # t1 = task index

    la t2, g_tcb_size
    lw t2, 0(t2)             # t2 = tcb size (in bytes)
    mul t0, t1, t2           # t0 = task item offset in task_list
    la t1, task_list
    add t0, t1, t0           # t0 = &(task_list[current_task_index])
    addi t0, t0, 8           # t0 = &(task_list[current_task_index].is_privileged)
    lw t0, 0(t0)             # Load is_privileged flag
    bnez t0, no_pmp_config    # If not privileged, skip PMP
    
    call reconfigure_pmp_for_current_task

    /* FI must happen here when switching from Task1 to Task2. */
    /* During the second time when the program reaches this point. */


no_pmp_config:

    # Restore all registers
    addi sp, sp, -128  

    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    lw a0, 32(sp)
    lw a1, 36(sp)
    lw a2, 40(sp)
    lw a3, 44(sp)
    lw a4, 48(sp)
    lw a5, 52(sp)
    lw a6, 56(sp)
    lw a7, 60(sp)
    lw s0, 64(sp)
    lw s1, 68(sp)
    lw s2, 72(sp)
    lw s3, 76(sp)
    lw s4, 80(sp)
    lw s5, 84(sp)
    lw s6, 88(sp)
    lw s7, 92(sp)
    lw s8, 96(sp)
    lw s9, 100(sp)
    lw s10, 104(sp)
    lw s11, 108(sp)
    
    # Restore machine exception program counter
    lw t0, 112(sp)              # Load saved PC
    csrw mepc, t0               # Restore PC

    # Restore machine status register (mstatus)
    lw t0, 116(sp)              # Load saved mstatus
    csrw mstatus, t0            # Restore mstatus

    # Restore stack pointer
    addi sp, sp, 128
    
    # Return from trap
    mret

.size trap_handler_asm, .-trap_handler_asm


# Function: initialize task context
# Purpose: Initialize the task context for a new task
# Parameters: a0 = stack top, a1 = task function pointer, a2 = is_privileged flag
# Note:

.globl task_context_init_asm
.type task_context_init_asm, @function

task_context_init_asm:
    # Initialize the task context
    # a0 points to the stack top for the new task

    # Subtract space for the task context
    addi a0, a0, -128
    
    # Store function pointer in machine exception program counter
    sw a1, 112(a0) 

    bnez a2, task_is_privileged
    # Set the initial machine status register (mstatus)
    li a1, 0x80  # Set MPP to 0b00 (U-mode) and MPIE to 1
    j 1f

task_is_privileged:
    li a1, 0x1880  # Set MPP to 0b11 (M-mode) and MPIE to 1
1:
    sw a1, 116(a0) // mstatus

    # Save beginning of task's stack for sp
    sw a0, 120(a0) // sp

    # Initialize all registers to zero
    sw x0, 0(a0) // ra
    sw x0, 4(a0) // t0
    sw x0, 8(a0) // t1
    sw x0, 12(a0) // t2
    sw x0, 16(a0) // t3
    sw x0, 20(a0) // t4
    sw x0, 24(a0) // t5
    sw x0, 28(a0) // t6
    sw x0, 32(a0) // a0
    sw x0, 36(a0) // a1
    sw x0, 40(a0) // a2
    sw x0, 44(a0) // a3
    sw x0, 48(a0) // a4
    sw x0, 52(a0) // a5
    sw x0, 56(a0) // a6
    sw x0, 60(a0) // a7
    sw x0, 64(a0) // s0
    sw x0, 68(a0) // s1
    sw x0, 72(a0) // s2
    sw x0, 76(a0) // s3
    sw x0, 80(a0) // s4
    sw x0, 84(a0) // s5
    sw x0, 88(a0) // s6
    sw x0, 92(a0) // s7
    sw x0, 96(a0) // s8
    sw x0, 100(a0) // s9
    sw x0, 104(a0) // s10
    sw x0, 108(a0) // s11

    ret                          # Return from function

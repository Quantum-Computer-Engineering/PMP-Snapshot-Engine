#include "rtos_config.h"
#include "bare_metal_rtos.h"
#include "io.h"

void configure_pmp_from_current_tasks_tcb(void)
{
    // This function configures the PMP settings for the current task
    extern int current_task_index;
    extern task_control_block_t task_list[];
    extern unsigned int task_count;

    // Ensure that the current task index is valid
    if (current_task_index == 0)
    {
        write_uart("Error: Idle task (task_index = 0) has no PMP configuration\n");
        return;
    }
    if (current_task_index < 0 || current_task_index > task_count)
    {
        write_uart("Error: Invalid task index for PMP configuration\n");
        return;
    }

    // Get the PMP settings from current task's TCB
    task_control_block_t *current_task = &task_list[current_task_index];
    pmp_settings_t *pmp_settings = &current_task->pmp_settings;

    // Configure PMP address registers in reverse order (15 down to 0)
    // Jump to the first valid region and fall through to configure all regions
    // (GCC’s “computed goto” extension. The grammar is goto *expr;)
    goto *&&pmp_addr_start + (15 - (N_PMP_REGIONS - 1)) * sizeof(void *);

pmp_addr_start:
pmp_addr_15:
    asm volatile("csrw 0x3BF, %0" ::"r"(pmp_settings->pmp_addr[15]));
pmp_addr_14:
    asm volatile("csrw 0x3BE, %0" ::"r"(pmp_settings->pmp_addr[14]));
pmp_addr_13:
    asm volatile("csrw 0x3BD, %0" ::"r"(pmp_settings->pmp_addr[13]));
pmp_addr_12:
    asm volatile("csrw 0x3BC, %0" ::"r"(pmp_settings->pmp_addr[12]));
pmp_addr_11:
    asm volatile("csrw 0x3BB, %0" ::"r"(pmp_settings->pmp_addr[11]));
pmp_addr_10:
    asm volatile("csrw 0x3BA, %0" ::"r"(pmp_settings->pmp_addr[10]));
pmp_addr_9:
    asm volatile("csrw 0x3B9, %0" ::"r"(pmp_settings->pmp_addr[9]));
pmp_addr_8:
    asm volatile("csrw 0x3B8, %0" ::"r"(pmp_settings->pmp_addr[8]));
pmp_addr_7:
    asm volatile("csrw 0x3B7, %0" ::"r"(pmp_settings->pmp_addr[7]));
pmp_addr_6:
    asm volatile("csrw 0x3B6, %0" ::"r"(pmp_settings->pmp_addr[6]));
pmp_addr_5:
    asm volatile("csrw 0x3B5, %0" ::"r"(pmp_settings->pmp_addr[5]));
pmp_addr_4:
    asm volatile("csrw 0x3B4, %0" ::"r"(pmp_settings->pmp_addr[4]));
pmp_addr_3:
    asm volatile("csrw 0x3B3, %0" ::"r"(pmp_settings->pmp_addr[3]));
pmp_addr_2:
    asm volatile("csrw 0x3B2, %0" ::"r"(pmp_settings->pmp_addr[2]));
pmp_addr_1:
    asm volatile("csrw 0x3B1, %0" ::"r"(pmp_settings->pmp_addr[1]));
pmp_addr_0:
    asm volatile("csrw 0x3B0, %0" ::"r"(pmp_settings->pmp_addr[0]));

    // Configure PMP configuration registers in reverse order (3 down to 0)
    // Jump to the first valid config register and fall through
    goto *&&pmp_cfg_start + (3 - ((N_PMP_REGIONS / 4) - 1)) * sizeof(void *);

pmp_cfg_start:
pmp_cfg_3:
    asm volatile("csrw 0x3A3, %0" ::"r"(pmp_settings->pmp_cfg[3])); // pmpcfg3
pmp_cfg_2:
    asm volatile("csrw 0x3A2, %0" ::"r"(pmp_settings->pmp_cfg[2])); // pmpcfg2
pmp_cfg_1:
    asm volatile("csrw 0x3A1, %0" ::"r"(pmp_settings->pmp_cfg[1])); // pmpcfg1
pmp_cfg_0:
    asm volatile("csrw 0x3A0, %0" ::"r"(pmp_settings->pmp_cfg[0])); // pmpcfg0

    // Flush instruction cache and synchronize to ensure PMP changes take effect
    asm volatile("fence.i");
    asm volatile("fence");
}



#if (PSE_ACTIVATED == 1)

void fi_resilient_task_pmp_init(pmp_settings_t *pmp_settings,
                                pmp_settings_t *pmp_settings_duplicate)
{
    extern void pmp_configuration_fault(void);

    // --- Phase 1: addresses (15..0), write from primary and verify against duplicate ---

    // Jump to the first valid region and fall through to configure all regions
    // (GCC’s “computed goto” extension. The grammar is: goto *expr;)
    goto *&&pmp_addr_start + (15 - (N_PMP_REGIONS - 1)) * sizeof(void *);

pmp_addr_start:;
    {
        uintptr_t tmp;
pmp_addr_15:
        asm volatile("csrw 0x3BF, %0" :: "r"(pmp_settings->pmp_addr[15]));
        asm volatile("csrr %0, 0x3BF" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[15]) { pmp_configuration_fault(); }

pmp_addr_14:
        asm volatile("csrw 0x3BE, %0" :: "r"(pmp_settings->pmp_addr[14]));
        asm volatile("csrr %0, 0x3BE" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[14]) { pmp_configuration_fault(); }

pmp_addr_13:
        asm volatile("csrw 0x3BD, %0" :: "r"(pmp_settings->pmp_addr[13]));
        asm volatile("csrr %0, 0x3BD" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[13]) { pmp_configuration_fault(); }

pmp_addr_12:
        asm volatile("csrw 0x3BC, %0" :: "r"(pmp_settings->pmp_addr[12]));
        asm volatile("csrr %0, 0x3BC" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[12]) { pmp_configuration_fault(); }

pmp_addr_11:
        asm volatile("csrw 0x3BB, %0" :: "r"(pmp_settings->pmp_addr[11]));
        asm volatile("csrr %0, 0x3BB" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[11]) { pmp_configuration_fault(); }

pmp_addr_10:
        asm volatile("csrw 0x3BA, %0" :: "r"(pmp_settings->pmp_addr[10]));
        asm volatile("csrr %0, 0x3BA" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[10]) { pmp_configuration_fault(); }

pmp_addr_9:
        asm volatile("csrw 0x3B9, %0" :: "r"(pmp_settings->pmp_addr[9]));
        asm volatile("csrr %0, 0x3B9" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[9]) { pmp_configuration_fault(); }

pmp_addr_8:
        asm volatile("csrw 0x3B8, %0" :: "r"(pmp_settings->pmp_addr[8]));
        asm volatile("csrr %0, 0x3B8" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[8]) { pmp_configuration_fault(); }

pmp_addr_7:
        asm volatile("csrw 0x3B7, %0" :: "r"(pmp_settings->pmp_addr[7]));
        asm volatile("csrr %0, 0x3B7" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[7]) { pmp_configuration_fault(); }

pmp_addr_6:
        asm volatile("csrw 0x3B6, %0" :: "r"(pmp_settings->pmp_addr[6]));
        asm volatile("csrr %0, 0x3B6" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[6]) { pmp_configuration_fault(); }

pmp_addr_5:
        asm volatile("csrw 0x3B5, %0" :: "r"(pmp_settings->pmp_addr[5]));
        asm volatile("csrr %0, 0x3B5" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[5]) { pmp_configuration_fault(); }

pmp_addr_4:
        asm volatile("csrw 0x3B4, %0" :: "r"(pmp_settings->pmp_addr[4]));
        asm volatile("csrr %0, 0x3B4" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[4]) { pmp_configuration_fault(); }

pmp_addr_3:
        asm volatile("csrw 0x3B3, %0" :: "r"(pmp_settings->pmp_addr[3]));
        asm volatile("csrr %0, 0x3B3" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[3]) { pmp_configuration_fault(); }

pmp_addr_2:
        asm volatile("csrw 0x3B2, %0" :: "r"(pmp_settings->pmp_addr[2]));
        asm volatile("csrr %0, 0x3B2" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[2]) { pmp_configuration_fault(); }

pmp_addr_1:
        asm volatile("csrw 0x3B1, %0" :: "r"(pmp_settings->pmp_addr[1]));
        asm volatile("csrr %0, 0x3B1" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[1]) { pmp_configuration_fault(); }

pmp_addr_0:
        asm volatile("csrw 0x3B0, %0" :: "r"(pmp_settings->pmp_addr[0]));
        asm volatile("csrr %0, 0x3B0" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_addr[0]) { pmp_configuration_fault(); }
    }

    // --- Phase 2: configs (3..0), write from primary and verify against duplicate ---

    // Jump to the first valid config register and fall through
    goto *&&pmp_cfg_start + (3 - ((N_PMP_REGIONS / 4) - 1)) * sizeof(void *);

pmp_cfg_start:;
    {
        uintptr_t tmp;
pmp_cfg_3:
        asm volatile("csrw 0x3A3, %0" :: "r"(pmp_settings->pmp_cfg[3])); // pmpcfg3
        asm volatile("csrr %0, 0x3A3" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_cfg[3]) { pmp_configuration_fault(); }

pmp_cfg_2:
        asm volatile("csrw 0x3A2, %0" :: "r"(pmp_settings->pmp_cfg[2])); // pmpcfg2
        asm volatile("csrr %0, 0x3A2" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_cfg[2]) { pmp_configuration_fault(); }

pmp_cfg_1:
        asm volatile("csrw 0x3A1, %0" :: "r"(pmp_settings->pmp_cfg[1])); // pmpcfg1
        asm volatile("csrr %0, 0x3A1" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_cfg[1]) { pmp_configuration_fault(); }

pmp_cfg_0:
        asm volatile("csrw 0x3A0, %0" :: "r"(pmp_settings->pmp_cfg[0])); // pmpcfg0
        asm volatile("csrr %0, 0x3A0" : "=r"(tmp));
        if (tmp != pmp_settings_duplicate->pmp_cfg[0]) { pmp_configuration_fault(); }
    }

    // Ensure PMP changes take effect before snapshotting
    asm volatile("fence.i");
    asm volatile("fence");

    // Redundant snapshot (detect skipped save)
    pse_save_pmp_snapshot();
    pse_save_pmp_snapshot();
}

void pse_switch_pmp_snapshot(void)
{
    extern int current_task_index;

    __asm volatile(
        "csrw 0x7C0, %0" /* 0x7C1: CSR_PMP_SNAPSHOT_APPLY */
        :
        : "r"(current_task_index));
}

void pse_save_pmp_snapshot(void)
{
    __asm volatile(
        "csrw 0x7C1, %0" /* 0x7C1: CSR_PMP_SNAPSHOT_SAVE */
        :
        : "r"(current_task_index));
}

#endif /* ( PSE_ACTIVATED == 1 ) */


// Put at the bottom so it knows the signatures
// (There was an issue with using "include pmp.h" 
// due to circular dependencies)
void reconfigure_pmp_for_current_task(void)
{
    #if (PSE_ACTIVATED == 0)
        configure_pmp_from_current_tasks_tcb();
    #else
        pse_switch_pmp_snapshot();
    #endif
}


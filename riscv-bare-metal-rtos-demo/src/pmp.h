
#ifndef SRC_PMP_H_
#define SRC_PMP_H_

#include "rtos_config.h"

// Macro to convert linker symbol address to PMP address format
// PMP addresses are shifted right by 2 bits (word-aligned addresses)
#define PMP_ADDR(symbol) ((unsigned int)&(symbol) >> 2)

// Helper macros for common PMP configurations
#define PMP_CFG_RWX  0x07  // TOR mode with Read/Write/Execute permissions
#define PMP_CFG_X    0x04  // TOR mode with Read/Execute permissions  
#define PMP_CFG_RW   0x03  // TOR mode with Read/Write permissions

#define PMP_CFG_TOR  0b1000 // TOR mode
#define PMP_CFG_NA4  0b11000 // NA4 mode

#define PMP_CFG_DISABLED 0x00  // Disabled region


typedef struct
{
    unsigned int pmp_addr[N_PMP_REGIONS];
    unsigned int pmp_cfg[N_PMP_REGIONS / 4];
} pmp_settings_t;

void configure_pmp_from_current_tasks_tcb(void);

void fi_resilient_task_pmp_init(pmp_settings_t *pmp_settings, pmp_settings_t *pmp_settings_duplicate);

#if (PSE_ACTIVATED == 1)
void pse_switch_pmp_snapshot(void);
void pse_save_pmp_snapshot(void);
#endif /* ( PSE_ACTIVATED == 1 ) */






#endif // SRC_PMP_H_

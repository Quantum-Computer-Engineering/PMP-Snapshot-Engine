#ifndef RISCY_AES_H
#define RISCY_AES_H

#define RISCY_AES_BASE_ADDR             0x10000000

#define PULPINO_BASE_ADDR             0x10000000

/** SOC PERIPHERALS */
#define SOC_PERIPHERALS_BASE_ADDR     ( PULPINO_BASE_ADDR + 0xA100000 )

#define UART_BASE_ADDR                ( SOC_PERIPHERALS_BASE_ADDR + 0x0000 )
#define GPIO_BASE_ADDR                ( SOC_PERIPHERALS_BASE_ADDR + 0x1000 )
#define SPI_BASE_ADDR                 ( SOC_PERIPHERALS_BASE_ADDR + 0x2000 )
#define TIMER_BASE_ADDR               ( SOC_PERIPHERALS_BASE_ADDR + 0x3000 )
#define EVENT_UNIT_BASE_ADDR          ( SOC_PERIPHERALS_BASE_ADDR + 0x4000 )
#define I2C_BASE_ADDR                 ( SOC_PERIPHERALS_BASE_ADDR + 0x5000 )
#define FLL_BASE_ADDR                 ( SOC_PERIPHERALS_BASE_ADDR + 0x6000 )
#define SOC_CTRL_BASE_ADDR            ( SOC_PERIPHERALS_BASE_ADDR + 0x7000 )


/** Instruction RAM */
#define INSTR_RAM_BASE_ADDR           ( 0x00       )
#define INSTR_RAM_START_ADDR          ( 0x80       )

/** ROM */
#define ROM_BASE_ADDR                 ( 0x8000     )

/** Data RAM */
#define DATA_RAM_BASE_ADDR            ( 0x00100000 )

/** Registers and pointers */
#define REGP(x) ((volatile unsigned int*)(x))
#define REG(x) (*((volatile unsigned int*)(x)))
#define REGP_8(x) (((volatile uint8_t*)(x)))

#define __PSC__(a) *(unsigned volatile int*) (0x2B100000 + a)
/** Boot address register */
#define BOOTREG     __PSC__(0x08)

#define RES_STATUS  __PSC__(0x14)

#endif



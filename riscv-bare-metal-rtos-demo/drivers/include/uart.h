// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/**
 * @file
 * @brief 16750 UART library.
 *
 * Provides UART helper function like setting
 * control registers and reading/writing over
 * the serial interface.
 *
 */
#ifndef _UART_H
#define _UART_H

#include <stdint.h>
#include <pulpino.h>

#define UART_REG_STATUS ( UART_BASE_ADDR + 0x00) // Receiver Buffer Register (Read Only)
#define UART_REG_TX     ( UART_BASE_ADDR + 0x04) // Divisor Latch (LS)
#define UART_REG_RX 	( UART_BASE_ADDR + 0x08) // Transmitter Holding Register (Write Only)

#define STAT_UART 	REGP_8(UART_REG_STATUS)
#define RX_UART 	REGP_8(UART_REG_TX)
#define TX_UART 	REGP_8(UART_REG_RX)



#define UART_FIFO_DEPTH 16

//UART_FIFO_DEPTH but to be compatible with Arduino_libs and also if in future designs it differed
#define SERIAL_RX_BUFFER_SIZE UART_FIFO_DEPTH
#define SERIAL_TX_BUFFER_SIZE UART_FIFO_DEPTH

void uart_set_brate(int brate);

void uart_send(const char* str, unsigned int len);
void uart_sendchar(const char c);
char uart_getchar();

#endif

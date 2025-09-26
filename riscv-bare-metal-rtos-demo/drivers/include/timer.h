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
 * @brief Timer library.
 *
 * Provides Timer function like writing the appropriate
 * timer registers and uttility functions to cycle count
 * certain events. Used in bench.h.
 *
 * @author Florian Zaruba
 *
 * @version 1.0
 *
 * @date 2/10/2015
 *
 */
#ifndef __TIMER_H__
#define __TIMER_H__

#include <memoryMap.h>

#define TIMERA_LOAD           ( TIMER_BASE_ADDR + 0x00 )
#define TIMERA_VAL            ( TIMER_BASE_ADDR + 0x04 )
#define TIMERA_CT    		  ( TIMER_BASE_ADDR + 0x08 )
#define TIMERA_CLR			  ( TIMER_BASE_ADDR + 0x0C )

/* pointer to mem of timer unit - PointerTimer */
#define __PT__(a) *(volatile int*) (TIMER_BASE_ADDR + a)

/** timer A register - contains the actual cycle counter */
#define TILD __PT__(TIMERA_LOAD)

/** timer A control register */
#define TVAL __PT__(TIMERA_VAL)

/** timer A output control register */
#define TCT __PT__(TIMERA_CT)

/** timer A output clear register */
#define TCLR __PT__(TIMERA_CLR)

void reset_timer(int clearmode);

void set_timer_value(int value);

void set_timer_mode(int mode);

int get_time(void);
void start_timer(void);
void configure_timer(int timer_select, int enable, int mode);

#endif

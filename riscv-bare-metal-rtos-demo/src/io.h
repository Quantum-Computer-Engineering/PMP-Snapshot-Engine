#ifndef IO_H
#define IO_H

#include "rtos_config.h"

#define UART0_TX ((volatile unsigned char *)0x10000000)

static inline void write_uart(const char *ptr)
{
        // While \0 not reached, write characters to UART
        while (*ptr)
        {
            #if (SKIP_UART_PRINT == 0)
                while ( !(UART0_TX[5] & 0x20) ) {} // Wait until UART FIFO not full anymore (LSR bit 5)
            #endif

            UART0_TX[0] = *((volatile unsigned char *)ptr);

            // Next character
            ptr++;
        }
}

// Simple number to string conversion for printing via UART
static inline void write_uart_int(unsigned int value) 
{
    char print_str[16];
    unsigned int temp = value;
    int pos = 0;

    if (temp == 0)
    {
        print_str[pos++] = '0';
    }
    else
    {
        char digits[16];
        int digit_count = 0;

        while (temp > 0)
        {
            digits[digit_count++] = '0' + (temp % 10);
            temp /= 10;
        }

        // Reverse the digits
        for (int j = digit_count - 1; j >= 0; j--)
        {
            print_str[pos++] = digits[j];
        }
    }
    print_str[pos] = '\0';

    write_uart(print_str);
}

static inline void write_uart_hex(unsigned int value) 
{
    char print_str[16];
    unsigned int temp = value;
    int pos = 0;

    if (temp == 0)
    {
        print_str[pos++] = '0';
    }
    else
    {
        char digits[16];
        int digit_count = 0;

        while (temp > 0)
        {
            if (temp % 16 < 10)
            {
                digits[digit_count++] = '0' + (temp % 16);
            }
            else
            {
                digits[digit_count++] = 'A' + (temp % 16 - 10);
            }
            temp /= 16;
        }

        // Reverse the digits
        for (int j = digit_count - 1; j >= 0; j--)
        {
            print_str[pos++] = digits[j];
        }
    }
    print_str[pos] = '\0';

    write_uart(print_str);
}

static inline int is_uart_fifo_empty(void)
{
    return (UART0_TX[5] & 0x40) != 0; // LSR bit 6 indicates if FIFO is empty
} 


#endif // IO_H
#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define BAUD 115200
#define TX_PIN 0
#define RX_PIN 1

int main() {
    // Configura GPIO primeiro
    gpio_set_function(TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(RX_PIN, GPIO_FUNC_UART);

    uart_init(UART_ID, BAUD);
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE);

    sleep_ms(2000);

    while (1) {
        // Envia HEADER
        uart_putc_raw(UART_ID, 0xAA);

        // Envia 16x16 matriz de exemplo
        for (int i = 0; i < 16*16; i++) {
            uart_putc_raw(UART_ID, i & 0xFF);
        }

        // Envia FOOTER
        uart_putc_raw(UART_ID, 0x55);

        sleep_ms(500);

        // Recebe dados do FPGA
        while (uart_is_readable(UART_ID)) {
            int c = uart_getc(UART_ID);
            printf("Recebido: 0x%02X\n", c);
        }
    }
}

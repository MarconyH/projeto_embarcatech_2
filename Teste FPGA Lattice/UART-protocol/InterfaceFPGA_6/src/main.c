#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/uart.h"

// TESTE UART ULTRA-SIMPLIFICADO
// Envia 'A' a cada 1 segundo e mostra o que recebe do FPGA

#define UART_ID uart0
#define BAUD_RATE 115200
#define UART_TX_PIN 0  // GP0 -> FPGA RX (D2)
#define UART_RX_PIN 1  // GP1 <- FPGA TX (E2)

int main() {
    // Inicializa stdio USB
    stdio_init_all();
    sleep_ms(2000);
    
    // Configura UART
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE);
    uart_set_fifo_enabled(UART_ID, false);  // DESABILITA FIFO para teste
    
    printf("\n=== TESTE UART SIMPLES ===\n");
    printf("Enviando 'A' a cada 1s\n\n");
    
    // Limpa FIFO RX
    while (uart_is_readable(UART_ID)) {
        uart_getc(UART_ID);
    }
    
    uint32_t contador = 0;
    char caracter = 64;
    
    while (1) {
        // Envia 'A' para o FPGA a cada 1 segundo
        if (contador % 1000 == 0) {
            caracter = caracter + 1;
            uart_putc_raw(UART_ID, caracter);
            printf("[%lu] TX -> %c\n", contador / 1000, caracter);
        }
        
        // Verifica se recebeu algo do FPGA
        if (uart_is_readable(UART_ID)) {
            uint8_t rx = uart_getc(UART_ID);
            printf("      RX <- '%c' (0x%02X)\n", rx, rx);
            
            // Verifica se o echo está correto
            if (rx == caracter) {
                printf("      ✓ ECHO CORRETO!\n\n");
            } else {
                printf("      ✗ ERRO: esperava %c 0X%02X, recebeu 0x%02X\n\n", caracter, caracter, rx);
            }
            while (uart_is_readable(UART_ID)) {
                uart_getc(UART_ID);
            }
        }
        
        sleep_ms(1);
        contador++;
        if (caracter > 'Z')
        {
            caracter = 'A';
        }
    }
}

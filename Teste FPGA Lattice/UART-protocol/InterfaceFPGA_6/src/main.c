#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/uart.h"
#include "hardware/irq.h"


/// \tag::uart_advanced[]

#define UART_ID uart0
#define BAUD_RATE 115200
#define DATA_BITS 8
#define STOP_BITS 1
#define PARITY    UART_PARITY_NONE

// Pinos UART para comunicação com FPGA
// TX_PIN (GP0) -> RX do FPGA (D2)
// RX_PIN (GP1) -> TX do FPGA (E2)
#define UART_TX_PIN 0
#define UART_RX_PIN 1

static int chars_rxed = 0;
static int chars_sent = 0;
static volatile bool echo_received = false;
static volatile uint8_t last_echo = 0;

// RX interrupt handler - recebe echo do FPGA e seta flag
void on_uart_rx() {
    while (uart_is_readable(UART_ID)) {
        last_echo = uart_getc(UART_ID);
        echo_received = true;
        chars_rxed++;
    }
    
    // CRÍTICO: Limpa flag de interrupção explicitamente
    uart_get_hw(UART_ID)->icr = UART_UARTICR_RXIC_BITS;
}

int main() {
    // Inicializa stdio para terminal USB
    stdio_init_all();
    
    // Aguarda 2 segundos para o terminal USB conectar
    sleep_ms(2000);
    
    // CRÍTICO: Inicializar GPIO antes de configurar UART
    gpio_init(UART_TX_PIN);
    gpio_init(UART_RX_PIN);
    
    // Set up our UART with a basic baud rate.
    uart_init(UART_ID, BAUD_RATE);

    // Set the TX and RX pins by using the function select on the GPIO
    // TX_PIN (GP0): Envia para FPGA RX (D2)
    // RX_PIN (GP1): Recebe do FPGA TX (E2)
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    
    // Garante que TX está em HIGH (idle) - IMPORTANTE!
    gpio_set_pulls(UART_TX_PIN, true, false);  // Pull-up no TX

    // Set UART flow control CTS/RTS, we don't want these, so turn them off
    uart_set_hw_flow(UART_ID, false, false);

    // Set our data format
    uart_set_format(UART_ID, DATA_BITS, STOP_BITS, PARITY);

    // Turn off FIFO's - we want to do this character by character
    uart_set_fifo_enabled(UART_ID, true);  // ATIVAR FIFO para evitar travamentos
    
    // Configura threshold do FIFO RX
    hw_write_masked(&uart_get_hw(UART_ID)->ifls,
                    1 << UART_UARTIFLS_RXIFLSEL_LSB,
                    UART_UARTIFLS_RXIFLSEL_BITS);  // Trigger com 1 byte

    // Set up a RX interrupt
    // We need to set up the handler first
    // Select correct interrupt for the UART we are using
    int UART_IRQ = UART_ID == uart0 ? UART0_IRQ : UART1_IRQ;

    // And set up and enable the interrupt handlers
    irq_set_exclusive_handler(UART_IRQ, on_uart_rx);
    irq_set_enabled(UART_IRQ, true);

    // Now enable the UART to send interrupts - RX only
    uart_set_irq_enables(UART_ID, true, false);

    // Mensagem inicial no terminal USB
    printf("\n============================================\n");
    printf("  TESTE ECHO: Raspberry <-> FPGA\n");
    printf("============================================\n");
    printf("UART: %d baud, 8N1\n", BAUD_RATE);
    printf("TX: GP%d -> FPGA RX (D2)\n", UART_TX_PIN);
    printf("RX: GP%d <- FPGA TX (E2)\n\n", UART_RX_PIN);
    printf("Digite caracteres no terminal.\n");
    printf("O FPGA ira enviar de volta (echo).\n\n");
    
    // TESTE: Envia byte de teste imediato
    printf("Enviando byte de teste 0xAA...\n");
    uart_putc_raw(UART_ID, 0xAA);
    sleep_ms(100);
    printf("Byte teste enviado!\n\n");

    // Loop principal: lê do terminal USB e envia para FPGA
    while (1) {
        // Verifica se recebemos echo na interrupção
        if (echo_received) {
            printf("ECHO recebido do FPGA: '%c' (0x%02X)\n", last_echo, last_echo);
            echo_received = false;
        }
        
        // Verifica se há caractere do terminal USB (stdin)
        int ch = getchar_timeout_us(10000);  // 10ms timeout
        
        if (ch != PICO_ERROR_TIMEOUT && ch >= 0) {
            // Aguarda UART estar pronto
            while (!uart_is_writable(UART_ID)) {
                tight_loop_contents();
            }
            
            // Envia caractere para o FPGA usando função RAW
            uart_putc_raw(UART_ID, (uint8_t)ch);
            chars_sent++;
            
            printf("Enviado para FPGA: '%c' (0x%02X)\n", (uint8_t)ch, (uint8_t)ch);
        }
    }
}

/// \end:uart_advanced[]
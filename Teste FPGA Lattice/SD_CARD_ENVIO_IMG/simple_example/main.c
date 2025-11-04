#include "pico/stdlib.h"
#include "diskio_test.h"
#include "hardware/uart.h"
#include <stdio.h>

// === Definições UART ===
#define UART_ID uart0
#define BAUD_RATE 9600
#define UART_TX_PIN 0
#define UART_RX_PIN 1

// === LEDs de status ===
#define LED_GREEN 11
#define LED_BLUE  12
#define LED_RED   13

/**
 * @brief Inicializa UART e GPIOs
 */
static void setup_uart_and_leds(void) {
    // Inicializa UART
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);

    stdio_init_all();
    sleep_ms(10000);
    printf("\n[PICO] UART inicializada a %d bps.\n", BAUD_RATE);

    // LEDs
    gpio_init(LED_GREEN);
    gpio_init(LED_BLUE);
    gpio_init(LED_RED);
    gpio_set_dir(LED_GREEN, GPIO_OUT);
    gpio_set_dir(LED_BLUE, GPIO_OUT);
    gpio_set_dir(LED_RED, GPIO_OUT);
    gpio_put(LED_GREEN, 0);
    gpio_put(LED_BLUE, 0);
    gpio_put(LED_RED, 0);
}

int main() {
    setup_uart_and_leds();

    printf("[PICO] Sistema iniciado.\n");
    sleep_ms(1000);

    // Executa teste SD e envio BMP
    bool ok = diskio_test();

    if (ok) {
        printf("[PICO] Execução concluída com sucesso.\n");
    } else {
        printf("[PICO][ERRO] Falha na execução.\n");
    }

    while (true) {
        tight_loop_contents();
    }
}

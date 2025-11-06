#include "pico/stdlib.h"
#include "diskio_test.h"
#include "fpga_comm.h"
#include <stdio.h>

// === Definições UART ===
#define BAUD_RATE 115200
#define UART_TX_PIN 0
#define UART_RX_PIN 1

// === LEDs de status ===
#define LED_GREEN 11
#define LED_BLUE  12
#define LED_RED   13

/**
 * @brief Inicializa UART e GPIOs
 */
static void setup(void) {

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

     // UART FPGA
    fpga_uart_init(BAUD_RATE, UART_TX_PIN, UART_RX_PIN);
    sleep_ms(10000);
    printf("[PICO] Sistema iniciado.\n");
}

int main() {
    stdio_init_all();
    setup();

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

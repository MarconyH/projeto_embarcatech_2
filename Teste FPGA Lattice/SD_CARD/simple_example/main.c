#include "pico/stdlib.h"
#include <stdio.h>
#include "diskio_test.h"  

#define LED_PIN 11

int main() {
    stdio_init_all();
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    printf("\n=== SD BMP Reader Test ===\n");

    // Pisca LED 3 vezes para indicar start
    for (int i = 0; i < 3; i++) {
        gpio_put(LED_PIN, 1);
        sleep_ms(200);
        gpio_put(LED_PIN, 0);
        sleep_ms(200);
    }

    // Executa teste do SD e leitura BMP
    diskio_test();

    // Loop de status
    while (1) {
        gpio_put(LED_PIN, 1);
        sleep_ms(500);
        gpio_put(LED_PIN, 0);
        sleep_ms(500);
    }
}

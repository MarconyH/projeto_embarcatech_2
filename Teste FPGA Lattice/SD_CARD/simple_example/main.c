#include "pico/stdlib.h"
#include "pico/time.h"
#include "diskio_test.h"
#include "pico/stdio_usb.h"
#include <stdio.h>

// === LEDs de status ===
#define LED_GREEN   11
#define LED_BLUE    12
#define LED_RED     13

// === Função auxiliar para piscar LEDs ===
void blink_led(uint led_pin, int times, int delay_ms) {
    for (int i = 0; i < times; i++) {
        gpio_put(led_pin, 1);
        sleep_ms(delay_ms);
        gpio_put(led_pin, 0);
        sleep_ms(delay_ms);
    }
}

// === Função para aguardar conexão USB com timeout ===
void wait_for_usb_connection(uint timeout_ms) {
    absolute_time_t start = get_absolute_time();
    printf("[INIT] Aguardando conexão USB...\n");
    while (!stdio_usb_connected()) {
        if (absolute_time_diff_us(start, get_absolute_time()) / 1000 > timeout_ms) {
            printf("[INIT] USB não detectado (modo autônomo).\n");
            return;
        }
        sleep_ms(100);
    }
    printf("[INIT] USB conectado!\n");
}

// === Função principal ===
int main(void) {
    stdio_init_all();

    // Inicializa LEDs
    gpio_init(LED_GREEN);
    gpio_init(LED_BLUE);
    gpio_init(LED_RED);
    gpio_set_dir(LED_GREEN, GPIO_OUT);
    gpio_set_dir(LED_BLUE, GPIO_OUT);
    gpio_set_dir(LED_RED, GPIO_OUT);

    // Indica início (pisca todos)
    blink_led(LED_GREEN, 1, 150);
    blink_led(LED_BLUE, 1, 150);
    blink_led(LED_RED, 1, 150);

    // Aguarda conexão USB (até 10 segundos)
    wait_for_usb_connection(10000);

    printf("\n=== SD BMP Reader Test (v2.0) ===\n");

    // Indica fase de leitura SD (LED azul)
    gpio_put(LED_BLUE, 1);
    printf("[MAIN] Iniciando teste de leitura SD...\n");
    diskio_test();
    gpio_put(LED_BLUE, 0);

    // Finalização com sucesso (LED verde) ou erro (LED vermelho)
    // Aqui você pode diferenciar com base no retorno de diskio_test se desejar.
    printf("[MAIN] Teste concluído, entrando em loop de status.\n");

    // Pisca LED verde para indicar "OK"
    while (true) {
        blink_led(LED_GREEN, 1, 300);
        sleep_ms(700);
    }

    return 0;
}

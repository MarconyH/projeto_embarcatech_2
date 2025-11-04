#include "diskio_test.h"
#include "pico/stdlib.h"
#include "ff.h"
#include "hw_config.h"
#include "bmp_reader.h"
#include "hardware/uart.h"
#include <stdio.h>

#define UART_ID uart0
#define LED_GREEN 11
#define LED_BLUE  12
#define LED_RED   13

static FATFS fs;

// Buffer temporário grande suficiente para imagens pequenas/médias
#define MAX_IMAGE_SIZE (320*240)
static uint8_t img_buffer[MAX_IMAGE_SIZE];

/**
 * @brief Lê BMP 24 bits, converte para grayscale e envia pixel a pixel via UART
 */
static bool send_bmp_pixels_over_uart(const char *filename) {
    uint32_t width, height;

    if (!bmp_read_to_grayscale(filename, img_buffer, sizeof(img_buffer), &width, &height)) {
        printf("[BMP][ERRO] Falha ao ler e converter BMP para grayscale\n");
        return false;
    }

    // Cabeçalho de início da transmissão
    uart_putc_raw(UART_ID, 0xF1);
    uart_putc_raw(UART_ID, 0xF2);
    uart_putc_raw(UART_ID, 0xF3);
    uart_putc_raw(UART_ID, 0xF4);

    // Envia largura e altura (4 bytes cada)
    for (int i = 3; i >= 0; i--) uart_putc_raw(UART_ID, (width >> (8*i)) & 0xFF);
    for (int i = 3; i >= 0; i--) uart_putc_raw(UART_ID, (height >> (8*i)) & 0xFF);

    printf("[UART] Enviando pixels (%lux%lu)...\n", width, height);

    for (uint32_t i = 0; i < width * height; i++) {
        uart_putc_raw(UART_ID, img_buffer[i]);
        sleep_us(30); // Pequeno delay para o FPGA processar
    }

    // Final da transmissão
    uart_putc_raw(UART_ID, 0xFA);
    uart_putc_raw(UART_ID, 0xFB);
    uart_putc_raw(UART_ID, 0xFC);
    uart_putc_raw(UART_ID, 0xFD);

    printf("[UART] Total de %lu pixels enviados.\n", width*height);
    return true;
}

bool diskio_test(void) {
    FRESULT fr;
    bool success = false;

    printf("\n[DISKIO] === Inicializando SPI e SD ===\n");
    gpio_put(LED_BLUE, 1);

    // Inicializa hardware SPI
    sd_spi_hw_init();
    sd_card_t *pSD = sd_get_by_num(0);
    if (!pSD) {
        printf("[DISKIO][ERRO] Nenhuma interface SD encontrada!\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    fr = f_mount(&fs, "0:", 1);
    if (fr != FR_OK) {
        printf("[DISKIO][ERRO] Falha ao montar SD (%d)\n", fr);
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    printf("[DISKIO] SD montado com sucesso!\n");

    // Envia BMP via UART
    success = send_bmp_pixels_over_uart("img_estrada_1.bmp");

    f_mount(NULL, "0:", 1);
    gpio_put(LED_BLUE, 0);
    gpio_put(LED_GREEN, success);
    gpio_put(LED_RED, !success);

    return success;
}

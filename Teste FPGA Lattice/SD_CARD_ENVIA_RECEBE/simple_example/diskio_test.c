#include "diskio_test.h"
#include "pico/stdlib.h"
#include "ff.h"
#include "hw_config.h"
#include "bmp_reader.h"
#include "fpga_comm.h"
#include <stdio.h>

#define LED_GREEN 11
#define LED_BLUE  12
#define LED_RED   13

#define MAX_IMAGE_SIZE 65536  // ajuste conforme necessidade

static FATFS fs;

bool diskio_test(void) {
    FRESULT fr;
    bool success = false;

    printf("\n[DISKIO] === Inicializando SPI e SD ===\n");
    gpio_put(LED_BLUE, 1);

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

    // 1. Lê BMP e converte para grayscale
    static uint8_t image_buffer[MAX_IMAGE_SIZE];
    uint32_t width, height;
    if (!bmp_read_to_grayscale("img_estrada_1.bmp", image_buffer, MAX_IMAGE_SIZE, &width, &height)) {
        printf("[DISKIO][ERRO] Falha na leitura do BMP.\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    // 2. Envia para FPGA
    if (!fpga_send_image(image_buffer, width, height)) {
        printf("[DISKIO][ERRO] Falha ao enviar imagem para FPGA.\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    // 3. Recebe imagem processada do FPGA
    /*static uint8_t result_buffer[MAX_IMAGE_SIZE];
    uint32_t w, h;
    if (!fpga_receive_image(result_buffer, MAX_IMAGE_SIZE, &w, &h)) {
        printf("[DISKIO][ERRO] Falha ao receber imagem do FPGA.\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }*/

    uint16_t rho, theta;
    if (!fpga_receive_result(&rho, &theta)) {
        printf("[DISKIO][ERRO] Falha ao receber resultado do FPGA.\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }
    printf("[DISKIO] Resultado do FPGA: rho=%u, theta=%u\n", rho, theta);

    // LEDs de status
    gpio_put(LED_BLUE, 0);
    gpio_put(LED_GREEN, 1);
    gpio_put(LED_RED, 0);

    f_mount(NULL, "0:", 1);
    return true;
}

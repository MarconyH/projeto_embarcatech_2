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
#define MAX_IMAGE_SIZE 65536

static FATFS fs;

bool diskio_test(void) {
    printf("\n[DISKIO] === Inicializando SPI e SD ===\n");
    gpio_put(LED_BLUE, 1);

    sd_spi_hw_init();
    sd_card_t *pSD = sd_get_by_num(0);
    if (!pSD) {
        printf("[DISKIO][ERRO] Nenhum SD detectado!\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    FRESULT fr = f_mount(&fs, "0:", 1);
    if (fr != FR_OK) {
        printf("[DISKIO][ERRO] Falha ao montar SD (FR=%d)\n", fr);
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    printf("[DISKIO] SD montado com sucesso!\n");

    static uint8_t img[MAX_IMAGE_SIZE];
    uint32_t width, height;
    if (!bmp_read_to_grayscale("img_estrada_1.bmp", img, MAX_IMAGE_SIZE, &width, &height)) {
        printf("[DISKIO][ERRO] Falha na leitura do BMP.\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    printf("[DISKIO] Enviando imagem ao FPGA em blocos...\n");
    if (!fpga_send_image_blocks(img, width, height, 16, 16)) {
        printf("[DISKIO][ERRO] Falha ao enviar imagem em blocos.\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    uint16_t rho, theta;
    if (!fpga_receive_result(&rho, &theta)) {
        printf("[DISKIO][ERRO] Falha ao receber resultado do FPGA.\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    printf("[DISKIO] Resultado do FPGA: rho=%u, theta=%u\n", rho, theta);
    gpio_put(LED_BLUE, 0);
    gpio_put(LED_GREEN, 1);
    gpio_put(LED_RED, 0);
    f_mount(NULL, "0:", 1);
    return true;
}

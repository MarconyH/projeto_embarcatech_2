#include "pico/stdlib.h"
#include "ff.h"
#include "hw_config.h"
#include "bmp_reader.h"
#include <stdio.h>

static FATFS fs;

void diskio_test(void) {
    FRESULT fr;
    sd_card_t *pSD = sd_get_by_num(0);

    printf("[DISKIO] Inicializando interface SPI e cartão SD...\n");
    sd_spi_hw_init();

    printf("[DISKIO] Montando sistema de arquivos...\n");
    fr = f_mount(&fs, "0:", 1);
    if (fr != FR_OK) {
        printf("[DISKIO] Falha ao montar SD (%d)\n", fr);
        return;
    }

    printf("[DISKIO] SD montado com sucesso!\n");

    // Testa leitura de arquivo BMP
    if (!bmp_read_and_info("test.bmp")) {
        printf("[DISKIO] Erro ao ler arquivo BMP.\n");
    } else {
        printf("[DISKIO] Arquivo BMP lido com sucesso.\n");
    }

    // Desmonta o SD
    f_mount(NULL, "0:", 1);
    printf("[DISKIO] SD desmontado.\n");
}

#include "pico/stdlib.h"
#include "ff.h"
#include "hw_config.h"
#include "bmp_reader.h"
#include <stdio.h>
#include <stdbool.h>

// === LEDs de status (mesmos do main.c) ===
#define LED_GREEN   11
#define LED_BLUE    12
#define LED_RED     13

// === Sistema de arquivos global ===
static FATFS fs;

/**
 * @brief Monta o SD e tenta ler o arquivo BMP.
 * 
 * Indica o status com LEDs:
 * - Azul: atividade SD
 * - Verde: sucesso
 * - Vermelho: erro
 * 
 * @return true se tudo ocorreu bem, false caso contrário.
 */
bool diskio_test(void) {
    FRESULT fr;
    bool success = false;

    printf("\n[DISKIO] === Inicializando interface SPI e SD ===\n");

    // Ativa LED azul para indicar atividade SD
    gpio_put(LED_BLUE, 1);

    // Inicializa SPI
    sd_spi_hw_init();
    sd_card_t *pSD = sd_get_by_num(0);

    if (!pSD) {
        printf("[DISKIO][ERRO] Nenhuma interface SD encontrada!\n");
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    printf("[DISKIO] Montando sistema de arquivos...\n");
    fr = f_mount(&fs, "0:", 1);
    if (fr != FR_OK) {
        printf("[DISKIO][ERRO] Falha ao montar SD (%d)\n", fr);
        gpio_put(LED_RED, 1);
        gpio_put(LED_BLUE, 0);
        return false;
    }

    printf("[DISKIO] SD montado com sucesso!\n");

    // Lista arquivos do diretório raiz (debug opcional)
    printf("[DISKIO] Listando arquivos no diretório raiz:\n");
    DIR dir;
    FILINFO fno;
    if (f_opendir(&dir, "0:") == FR_OK) {
        while (true) {
            fr = f_readdir(&dir, &fno);
            if (fr != FR_OK || fno.fname[0] == 0)
                break;
            printf("   - %s%s\n", fno.fname, (fno.fattrib & AM_DIR) ? "/" : "");
        }
        f_closedir(&dir);
    } else {
        printf("   (Falha ao abrir diretório raiz)\n");
    }

    // Testa leitura de arquivo BMP
    printf("[DISKIO] Tentando abrir 'img_estrada_1.bmp'...\n");
    if (!bmp_read_and_info("img_estrada_1.bmp")) {
        printf("[DISKIO][ERRO] Falha ao ler arquivo BMP.\n");
        gpio_put(LED_RED, 1);
    } else {
        printf("[DISKIO] Arquivo BMP lido com sucesso.\n");
        success = true;
    }

    // Desmonta o SD
    f_mount(NULL, "0:", 1);
    printf("[DISKIO] SD desmontado.\n");

    // Indicação visual final
    gpio_put(LED_BLUE, 0);
    gpio_put(LED_RED, !success);
    gpio_put(LED_GREEN, success);

    return success;
}

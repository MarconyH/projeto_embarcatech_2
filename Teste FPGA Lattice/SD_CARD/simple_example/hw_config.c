#include "pico/stdlib.h"
#include "hardware/spi.h"
#include "hw_config.h"
#include "diskio.h"
#include <stdio.h>

// === Definições fixas do hardware do SD Card ===
#define SPI_PORT spi0
#define PIN_MISO 16
#define PIN_CS   17
#define PIN_SCK  18
#define PIN_MOSI 19

// Estruturas esperadas pela biblioteca FatFs_SPI
static spi_t spi = {
    .hw_inst = SPI_PORT,
    .miso_gpio = PIN_MISO,
    .mosi_gpio = PIN_MOSI,
    .sck_gpio = PIN_SCK,
    .baud_rate = 1000 * 1000, // 1 MHz durante init
    .set_drive_strength = false
};

static sd_card_t sd = {
    .spi = &spi,
    .use_card_detect = false,
    .ss_gpio = PIN_CS,
    .card_detect_gpio = 0,
    .card_detected_true = 0,
    .m_Status = STA_NOINIT
};

// === Funções esperadas pelo FatFs_SPI ===
size_t spi_get_num() {
    return 1; // apenas 1 interface SPI
}

spi_t *spi_get_by_num(size_t num) {
    return (num == 0) ? &spi : NULL;
}

size_t sd_get_num() {
    return 1; // apenas 1 cartão SD
}

sd_card_t *sd_get_by_num(size_t num) {
    return (num == 0) ? &sd : NULL;
}

// === Inicialização de hardware SPI ===
void sd_spi_hw_init(void) {
    printf("[HW_CONFIG] Inicializando SPI SD nos pinos MISO=%d, MOSI=%d, SCK=%d, CS=%d\n",
           PIN_MISO, PIN_MOSI, PIN_SCK, PIN_CS);

    // Inicializa SPI0
    spi_init(SPI_PORT, 1000 * 1000);
    spi_set_format(SPI_PORT, 8, SPI_CPOL_0, SPI_CPHA_0, SPI_MSB_FIRST);

    // Define GPIOs como função SPI
    gpio_set_function(PIN_MISO, GPIO_FUNC_SPI);
    gpio_set_function(PIN_MOSI, GPIO_FUNC_SPI);
    gpio_set_function(PIN_SCK, GPIO_FUNC_SPI);

    // Configura Chip Select
    gpio_init(PIN_CS);
    gpio_set_dir(PIN_CS, GPIO_OUT);
    gpio_put(PIN_CS, 1);

    printf("[HW_CONFIG] SPI SD pronto para uso.\n");
}

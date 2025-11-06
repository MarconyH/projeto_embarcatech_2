#include "fpga_comm.h"
#include "hardware/uart.h"
#include "pico/stdlib.h"
#include <stdio.h>
#include <string.h>

#define UART_ID uart0
#define FPGA_START_BYTE 0xF1
#define FPGA_ACK_BYTE   0xAA
#define FPGA_NACK_BYTE  0x55
#define FPGA_END_BYTE   0xF2

#define TIMEOUT_MS 2000

void fpga_uart_init(uint32_t baudrate, uint32_t tx_pin, uint32_t rx_pin) {
    uart_init(UART_ID, baudrate);
    gpio_set_function(tx_pin, GPIO_FUNC_UART);
    gpio_set_function(rx_pin, GPIO_FUNC_UART);
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE);
    uart_set_fifo_enabled(UART_ID, true);
    printf("[FPGA_COMM] UART configurada (TX=%d, RX=%d, %lu bps)\n", tx_pin, rx_pin, baudrate);
}

// Função auxiliar para esperar byte com timeout
static bool uart_wait_for_byte(uint8_t expected, uint32_t timeout_ms) {
    absolute_time_t deadline = make_timeout_time_ms(timeout_ms);
    while (absolute_time_diff_us(get_absolute_time(), deadline) > 0) {
        if (uart_is_readable(UART_ID)) {
            uint8_t rx = uart_getc(UART_ID);
            if (rx == expected)
                return true;
        }
    }
    return false;
}

// Envio simples (como antes)
bool fpga_send_image(const uint8_t *buffer, uint32_t width, uint32_t height) {
    printf("[FPGA_COMM] Enviando imagem completa (%lux%lu)...\n", width, height);
    uart_putc_raw(UART_ID, FPGA_START_BYTE);
    uart_putc_raw(UART_ID, width & 0xFF);
    uart_putc_raw(UART_ID, height & 0xFF);
    uart_putc_raw(UART_ID, (width >> 8) & 0xFF);
    uart_putc_raw(UART_ID, (height >> 8) & 0xFF);

    for (uint32_t i = 0; i < width * height; i++) {
        uart_putc_raw(UART_ID, buffer[i]);
    }

    uart_putc_raw(UART_ID, FPGA_END_BYTE);
    printf("[FPGA_COMM] Imagem enviada para FPGA.\n");
    return true;
}

// Novo método: envio por blocos menores (ex: 16x16)
bool fpga_send_image_blocks(const uint8_t *buffer, uint32_t width, uint32_t height,
                            uint32_t block_w, uint32_t block_h) {
    printf("[FPGA_COMM] Enviando imagem em blocos de %lux%lu...\n", block_w, block_h);

    for (uint32_t by = 0; by < height; by += block_h) {
        for (uint32_t bx = 0; bx < width; bx += block_w) {
            uint32_t w = (bx + block_w <= width) ? block_w : (width - bx);
            uint32_t h = (by + block_h <= height) ? block_h : (height - by);

            uart_putc_raw(UART_ID, FPGA_START_BYTE);
            uart_putc_raw(UART_ID, w & 0xFF);
            uart_putc_raw(UART_ID, h & 0xFF);
            uart_putc_raw(UART_ID, bx & 0xFF);
            uart_putc_raw(UART_ID, by & 0xFF);

            for (uint32_t y = 0; y < h; y++) {
                for (uint32_t x = 0; x < w; x++) {
                    uint32_t idx = (by + y) * width + (bx + x);
                    uart_putc_raw(UART_ID, buffer[idx]);
                }
            }

            uart_putc_raw(UART_ID, FPGA_END_BYTE);
            printf("[FPGA_COMM] Bloco enviado (%lu,%lu) tamanho=%lux%lu\n", bx, by, w, h);
            sleep_ms(5);
        }
    }

    printf("[FPGA_COMM] Todos os blocos enviados.\n");
    return true;
}

// Recebe resultado rho/theta do FPGA
bool fpga_receive_result(uint16_t *rho, uint16_t *theta) {
    uint8_t data[4];
    uint32_t count = 0;
    absolute_time_t deadline = make_timeout_time_ms(TIMEOUT_MS);

    printf("[FPGA_COMM] Aguardando resultado do FPGA...\n");

    while (absolute_time_diff_us(get_absolute_time(), deadline) > 0) {
        if (uart_is_readable(UART_ID)) {
            data[count++] = uart_getc(UART_ID);
            if (count >= 4) break;
        }
    }

    if (count < 4) {
        printf("[FPGA_COMM][ERRO] Timeout esperando rho/theta\n");
        return false;
    }

    *rho = (data[0] << 8) | data[1];
    *theta = (data[2] << 8) | data[3];
    printf("[FPGA_COMM] Resultado recebido: rho=%u, theta=%u\n", *rho, *theta);
    return true;
}

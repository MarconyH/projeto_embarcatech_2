#include "fpga_comm.h"
#include "pico/stdlib.h"
#include "hardware/uart.h"
#include <stdio.h>

#define UART_ID uart0
#define RX_TIMEOUT_US 200000  // 20 segundos

void fpga_uart_init(uint32_t baudrate, uint32_t tx_pin, uint32_t rx_pin) {
    uart_init(UART_ID, baudrate);
    gpio_set_function(tx_pin, GPIO_FUNC_UART);
    gpio_set_function(rx_pin, GPIO_FUNC_UART);
    printf("[FPGA_COMM] UART inicializada a %d bps\n", baudrate);
}

bool fpga_send_image(const uint8_t *buffer, uint32_t width, uint32_t height) {
    // Envia header
    uart_putc_raw(UART_ID, 0xF1);
    uart_putc_raw(UART_ID, 0xF2);
    uart_putc_raw(UART_ID, 0xF3);
    uart_putc_raw(UART_ID, 0xF4);

    // Envia largura e altura
    for (int i = 3; i >= 0; i--) uart_putc_raw(UART_ID, (width >> (8*i)) & 0xFF);
    for (int i = 3; i >= 0; i--) uart_putc_raw(UART_ID, (height >> (8*i)) & 0xFF);

    // Envia pixels
    for (uint32_t i = 0; i < width*height; i++) {
        uart_putc_raw(UART_ID, buffer[i]);
        sleep_us(30);
    }

    // Envia footer
    uart_putc_raw(UART_ID, 0xFA);
    uart_putc_raw(UART_ID, 0xFB);
    uart_putc_raw(UART_ID, 0xFC);
    uart_putc_raw(UART_ID, 0xFD);

    printf("[FPGA_COMM] Imagem (%lux%lu) enviada para FPGA\n", width, height);
    return true;
}

bool fpga_receive_result(uint16_t *rho, uint16_t *theta) {
    uint32_t timeout = 0;
    uint8_t rx_buf[2];

    // Espera primeiro byte de rho
    while (!uart_is_readable(UART_ID)) {
        timeout++;
        sleep_us(100);
        if (timeout > RX_TIMEOUT_US) {
            printf("[FPGA_COMM][ERRO] Timeout esperando rho\n");
            return false;
        }
    }
    rx_buf[0] = uart_getc(UART_ID);

    // Segundo byte de rho
    timeout = 0;
    while (!uart_is_readable(UART_ID)) {
        timeout++;
        sleep_us(100);
        if (timeout > RX_TIMEOUT_US) {
            printf("[FPGA_COMM][ERRO] Timeout esperando rho LSB\n");
            return false;
        }
    }
    rx_buf[1] = uart_getc(UART_ID);

    *rho = ((uint16_t)rx_buf[0]) | (((uint16_t)rx_buf[1]) << 8);

    // Theta (somente LSB, FPGA envia fixo 16'd90)
    timeout = 0;
    while (!uart_is_readable(UART_ID)) {
        timeout++;
        sleep_us(100);
        if (timeout > RX_TIMEOUT_US) {
            printf("[FPGA_COMM][ERRO] Timeout esperando theta\n");
            return false;
        }
    }
    *theta = uart_getc(UART_ID);

    printf("[FPGA_COMM] Resultado recebido do FPGA: rho=%u, theta=%u\n", *rho, *theta);
    return true;
}

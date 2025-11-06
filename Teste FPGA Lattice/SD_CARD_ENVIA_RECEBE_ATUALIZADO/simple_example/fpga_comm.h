#pragma once
#include <stdbool.h>
#include <stdint.h>

// Inicializa UART para comunicação com FPGA
void fpga_uart_init(uint32_t baudrate, uint32_t tx_pin, uint32_t rx_pin);

// Envia imagem completa (como antes)
bool fpga_send_image(const uint8_t *buffer, uint32_t width, uint32_t height);

// Envia imagem em blocos (novo método)
bool fpga_send_image_blocks(const uint8_t *buffer, uint32_t width, uint32_t height, uint32_t block_w, uint32_t block_h);

// Recebe resultado simples (rho, theta)
bool fpga_receive_result(uint16_t *rho, uint16_t *theta);

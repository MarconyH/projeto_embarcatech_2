#pragma once
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Inicializa UART para comunicação com FPGA
 */
void fpga_uart_init(uint32_t baudrate, uint32_t tx_pin, uint32_t rx_pin);

/**
 * @brief Envia imagem (grayscale) para FPGA
 * @param buffer Ponteiro para pixels
 * @param width Largura da imagem
 * @param height Altura da imagem
 */
bool fpga_send_image(const uint8_t *buffer, uint32_t width, uint32_t height);

/**
 * @brief Recebe resultado do FPGA (rho e theta)
 * @param rho Ponteiro para rho
 * @param theta Ponteiro para theta
 */
bool fpga_receive_result(uint16_t *rho, uint16_t *theta);

#ifdef __cplusplus
}
#endif

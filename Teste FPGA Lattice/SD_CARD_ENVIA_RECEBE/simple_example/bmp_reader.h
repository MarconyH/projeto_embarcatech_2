#pragma once
#include "ff.h"
#include <stdint.h>
#include <stdbool.h>

typedef struct __attribute__((packed)) {
    uint16_t bfType;
    uint32_t bfSize;
    uint16_t bfReserved1;
    uint16_t bfReserved2;
    uint32_t bfOffBits;
} BMPFileHeader;

typedef struct __attribute__((packed)) {
    uint32_t biSize;
    int32_t  biWidth;
    int32_t  biHeight;
    uint16_t biPlanes;
    uint16_t biBitCount;
    uint32_t biCompression;
    uint32_t biSizeImage;
    int32_t  biXPelsPerMeter;
    int32_t  biYPelsPerMeter;
    uint32_t biClrUsed;
    uint32_t biClrImportant;
} BMPInfoHeader;

/**
 * @brief Lê um BMP 24 bits e converte para 8 bits grayscale.
 * @param filename Caminho do BMP (ex: "img.bmp")
 * @param buffer Buffer para armazenar pixels em grayscale (1 byte por pixel)
 * @param max_size Tamanho máximo do buffer
 * @param width Retorna a largura da imagem
 * @param height Retorna a altura da imagem
 * @return true se leitura e conversão foram bem-sucedidas
 */
bool bmp_read_to_grayscale(const char *filename, uint8_t *buffer, uint32_t max_size,
                           uint32_t *width, uint32_t *height);

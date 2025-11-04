/**
 * @file bmp_reader.h
 * @brief Leitor simples de arquivos BMP no cartão SD (FatFs).
 *
 * Este módulo abre e lê cabeçalhos de arquivos BMP 24 bits (sem compressão)
 * armazenados no cartão SD, exibindo informações básicas e parte dos dados brutos.
 */

#pragma once

#include "ff.h"
#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Estrutura simplificada do cabeçalho BMP (24 bits sem compressão).
 */
typedef struct __attribute__((packed)) {
    uint16_t bfType;      // Deve ser 'BM' (0x4D42)
    uint32_t bfSize;      // Tamanho total do arquivo
    uint16_t bfReserved1; // Reservado
    uint16_t bfReserved2; // Reservado
    uint32_t bfOffBits;   // Offset para os dados de pixel
} BMPFileHeader;

typedef struct __attribute__((packed)) {
    uint32_t biSize;          // Tamanho desta estrutura (40 bytes)
    int32_t  biWidth;         // Largura em pixels
    int32_t  biHeight;        // Altura em pixels
    uint16_t biPlanes;        // Deve ser 1
    uint16_t biBitCount;      // Bits por pixel
    uint32_t biCompression;   // Tipo de compressão (esperado: 0)
    uint32_t biSizeImage;     // Tamanho da imagem em bytes
    int32_t  biXPelsPerMeter;
    int32_t  biYPelsPerMeter;
    uint32_t biClrUsed;
    uint32_t biClrImportant;
} BMPInfoHeader;

/**
 * @brief Abre um arquivo BMP e imprime suas informações.
 * @param filename Caminho do arquivo BMP (ex: "test.bmp")
 * @return true se lido com sucesso, false em caso de erro.
 */
bool bmp_read_and_info(const char *filename);

#include "bmp_reader.h"
#include <stdio.h>
#include <stdint.h>

static uint8_t line_buffer[2048]; // Buffer temporário para leitura de linha (R,G,B)

bool bmp_read_to_grayscale(const char *filename, uint8_t *buffer, uint32_t max_size,
                           uint32_t *width, uint32_t *height) {
    FIL file;
    FRESULT fr;
    UINT bytes_read;

    printf("\n[BMP] Abrindo arquivo: %s\n", filename);

    fr = f_open(&file, filename, FA_READ);
    if (fr != FR_OK) {
        printf("[BMP][ERRO] Falha ao abrir arquivo: %d\n", fr);
        return false;
    }

    BMPFileHeader file_header;
    BMPInfoHeader info_header;

    // Lê cabeçalhos
    f_read(&file, &file_header, sizeof(file_header), &bytes_read);
    f_read(&file, &info_header, sizeof(info_header), &bytes_read);

    if (file_header.bfType != 0x4D42) {
        printf("[BMP][ERRO] Arquivo não é BMP válido.\n");
        f_close(&file);
        return false;
    }

    printf("[BMP] Dimensões: %ld x %ld, Bits por pixel: %u\n",
           info_header.biWidth, info_header.biHeight, info_header.biBitCount);

    if (info_header.biBitCount != 24) {
        printf("[BMP][AVISO] Convertendo apenas BMP 24 bits!\n");
    }

    *width = info_header.biWidth;
    *height = info_header.biHeight;

    uint32_t row_size = ((info_header.biWidth * 3 + 3) & ~3); // Alinhamento 4 bytes
    uint32_t img_size = info_header.biWidth * info_header.biHeight;

    if (img_size > max_size) {
        printf("[BMP][ERRO] Buffer insuficiente (%lu bytes necessários, max %lu)\n",
               img_size, max_size);
        f_close(&file);
        return false;
    }

    f_lseek(&file, file_header.bfOffBits);

    // BMPs são armazenados de baixo para cima
    for (int y = info_header.biHeight - 1; y >= 0; y--) {
        fr = f_read(&file, line_buffer, row_size, &bytes_read);
        if (fr != FR_OK || bytes_read != row_size) {
            printf("[BMP][ERRO] Falha ao ler linha %d\n", y);
            f_close(&file);
            return false;
        }

        for (int x = 0; x < info_header.biWidth; x++) {
            uint8_t b = line_buffer[x*3 + 0];
            uint8_t g = line_buffer[x*3 + 1];
            uint8_t r = line_buffer[x*3 + 2];
            buffer[y * info_header.biWidth + x] = (r + g + b) / 3; // Grayscale simples
        }
    }

    f_close(&file);
    printf("[BMP] Conversão para grayscale concluída (%lu bytes).\n", img_size);
    return true;
}

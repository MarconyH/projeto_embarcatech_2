#include "bmp_reader.h"
#include <stdio.h>
#include <string.h>

// Buffer temporário para leitura
static uint8_t buffer[512];

bool bmp_read_and_info(const char *filename) {
    FIL file;
    FRESULT fr;
    UINT bytes_read;

    printf("\n[BMP] Abrindo arquivo: %s\n", filename);

    fr = f_open(&file, filename, FA_READ);
    if (fr != FR_OK) {
        printf("[BMP] Erro ao abrir arquivo: %d\n", fr);
        return false;
    }

    BMPFileHeader file_header;
    BMPInfoHeader info_header;

    // Lê cabeçalhos
    f_read(&file, &file_header, sizeof(file_header), &bytes_read);
    f_read(&file, &info_header, sizeof(info_header), &bytes_read);

    // Valida assinatura BMP
    if (file_header.bfType != 0x4D42) {
        printf("[BMP] Arquivo não é BMP válido.\n");
        f_close(&file);
        return false;
    }

    printf("[BMP] Tamanho total do arquivo: %lu bytes\n", file_header.bfSize);
    printf("[BMP] Offset dos dados: %lu bytes\n", file_header.bfOffBits);
    printf("[BMP] Dimensões: %ld x %ld\n", info_header.biWidth, info_header.biHeight);
    printf("[BMP] Bits por pixel: %u\n", info_header.biBitCount);
    printf("[BMP] Compressão: %lu (0 = sem compressão)\n", info_header.biCompression);
    printf("[BMP] Tamanho da imagem: %lu bytes\n", info_header.biSizeImage);

    // Move ponteiro para o início dos dados de imagem
    f_lseek(&file, file_header.bfOffBits);

    // Lê e imprime os primeiros 64 bytes da imagem (em hexadecimal)
    printf("\n[BMP] Dados iniciais da imagem (64 bytes):\n");
    fr = f_read(&file, buffer, 64, &bytes_read);
    if (fr == FR_OK && bytes_read > 0) {
        for (uint32_t i = 0; i < bytes_read; i++) {
            printf("%02X ", buffer[i]);
            if ((i + 1) % 16 == 0) printf("\n");
        }
        printf("\n");
    } else {
        printf("[BMP] Falha ao ler dados da imagem.\n");
    }

    f_close(&file);
    printf("[BMP] Leitura concluída.\n");
    return true;
}

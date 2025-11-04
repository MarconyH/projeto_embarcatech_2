#ifndef DISKIO_TEST_H
#define DISKIO_TEST_H

#include <stdbool.h>

/**
 * @brief Testa montagem do SD e leitura do arquivo BMP.
 * 
 * - LED Azul: atividade SD
 * - LED Verde: sucesso
 * - LED Vermelho: erro
 */
bool diskio_test(void);

#endif

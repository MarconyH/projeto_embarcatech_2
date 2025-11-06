#pragma once
#include "ff.h"
#include "sd_card.h"
#include "spi.h"

#ifdef __cplusplus
extern "C" {
#endif

spi_t *spi_get_by_num(size_t num);
sd_card_t *sd_get_by_num(size_t num);
void sd_spi_hw_init(void);

#ifdef __cplusplus
}
#endif

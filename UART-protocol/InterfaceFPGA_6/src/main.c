#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define BAUD_RATE 9600
#define UART_TX_PIN 0
#define UART_RX_PIN 1
#define WIDTH 16
#define LENGHT 16
#define HEADER_BYTE 0xAA  // Byte de sincronização

volatile uint8_t queue[WIDTH*LENGHT];
volatile int counter = 0;
volatile bool synced = false;
volatile bool header_echo_received = false;  // NOVA FLAG

void send_image_16x16_raw(uint8_t img[WIDTH][LENGHT]);

void on_uart_rx() {
    while (uart_is_readable(UART_ID)) {
        int rv = uart_getc(UART_ID);
        if (rv < 0) break;
        uint8_t byte = (uint8_t)rv;

        // aguarda o primeiro header (sincroniza)
        if (!synced) {
            if (byte == HEADER_BYTE) {
                synced = true;
                header_echo_received = false;
                counter = 0;
            }
            continue; // descarta tudo até o primeiro header
        }

        // descartamos quaisquer 0xAA adicionais (echo repetido)
        if (!header_echo_received) {
            if (byte == HEADER_BYTE) {
                // pula headers repetidos
                continue;
            } else {
                // primeiro byte não-header após a sincronização é o primeiro dado
                header_echo_received = true;
                // cai para armazenar este byte abaixo
            }
        }

        // armazena bytes de dados (apenas dados reais; headers iniciais já removidos)
        if (counter < (WIDTH * LENGHT)) {
            queue[counter++] = byte;
        }
    }
}

int main() {
    stdio_usb_init();
    sleep_ms(2000);

    uint8_t matrix[WIDTH][LENGHT];
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i == j) ? 255 : 0;
        }
    }
    
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE);
    uart_set_fifo_enabled(UART_ID, true);
    
    printf("\n=== TESTE UART 16x16 COM SINCRONIZACAO ===\n");
    printf("Header: 0x%02X\n", HEADER_BYTE);
    printf("Enviando matriz com delay de 2ms/byte...\n\n");
    
    // Limpa buffer UART múltiplas vezes
    for (int clear = 0; clear < 5; clear++) {
        while (uart_is_readable(UART_ID)) uart_getc(UART_ID);
        sleep_ms(20);
    }
    
    counter = 0;
    synced = false;
    header_echo_received = false;  // RESET DA FLAG

    int UART_IRQ = (UART_ID == uart0) ? UART0_IRQ : UART1_IRQ;
    irq_set_exclusive_handler(UART_IRQ, on_uart_rx);
    irq_set_enabled(UART_IRQ, true);
    uart_set_irq_enables(UART_ID, true, false);
    
    // ENVIA HEADER PRIMEIRO
    uart_putc_raw(UART_ID, HEADER_BYTE);
    sleep_ms(10);  // Espera header ser processado
    
    // Depois envia a imagem
    send_image_16x16_raw(matrix);

    uint32_t start_ms = to_ms_since_boot(get_absolute_time());
    const uint32_t timeout_ms = 10000;
    while ((counter < (WIDTH * LENGHT)) && 
           ((to_ms_since_boot(get_absolute_time()) - start_ms) < timeout_ms)) {
        sleep_ms(1);
    }

    sleep_ms(100);
    uart_set_irq_enables(UART_ID, false, false);
    irq_set_enabled(UART_IRQ, false);

    printf("Matriz Original:\n");
    for (int i = 0; i < WIDTH; i++) {
        printf("[%02d] ", i);
        for (int j = 0; j < LENGHT; j++) {
            printf("|0x%02X| ", matrix[i][j]);
        }
        printf("\n");
    }

    printf("\nRecebidos %d byte(s) (synced=%d, header_echo=%d):\n", 
           counter, synced, header_echo_received);
    if (counter == 0) {
        printf("Nenhuma resposta do FPGA.\n");
    } else {
        int correct = 0;
        for (int i = 0; i < WIDTH; i++) {
            printf("[%02d] ", i);
            for (int j = 0; j < LENGHT; j++) {
                int idx = i * LENGHT + j;
                uint8_t v = (idx < counter) ? queue[idx] : 0x00;
                printf("|0x%02X| ", v);
                if (v == matrix[i][j]) correct++;
            }
            printf("\n");
        }
        printf("\nBytes corretos: %d/%d (%.1f%%)\n", correct, WIDTH*LENGHT, 
               100.0*correct/(WIDTH*LENGHT));
    }
    while (1) tight_loop_contents();
    
    // int c;
    // while (1) {
    //         if (uart_is_readable(UART_ID)) {
    //             c = uart_getc(UART_ID);
    //             if (c >= 0) {
    //                 uint8_t b = (uint8_t)c;
    //                 if (b >= 32 && b <= 126) {
    //                     printf("RX: 0x%02X '%c'\n", b, b);
    //                 } else {
    //                     printf("RX: 0x%02X\n", b);
    //                 }
    //             }
    //         } else {
    //             sleep_ms(10);
    //         }
    // };
}

void send_image_16x16_raw(uint8_t img[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            uint8_t b = img[i][j];
            while (!uart_is_writable(UART_ID)) tight_loop_contents();
            uart_putc_raw(UART_ID, b);
            sleep_ms(2);  // 2ms por byte
        }
    }
}
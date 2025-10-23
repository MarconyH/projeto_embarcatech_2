#include <stdio.h>
#include <string.h>
#include "pico/stdlib.h"
#include "pico/multicore.h"
#include "pico/sem.h"

// FreeRTOS includes
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "queue.h"

// UART includes
#include "hardware/uart.h"
#include "hardware/irq.h" 

// --- CONFIGURAÇÕES DE HARDWARE E COMUNICAÇÃO ---
// Usamos uart0 diretamente na chamada de IRQ, mas a macro é mantida para uart_init
#define UART_ID             uart0
#define BAUD_RATE           115200

// Pinos UART
#define UART_TX_PIN         0
#define UART_RX_PIN         1

// Parâmetros da Imagem
#define IMG_WIDTH           1280
#define IMG_HEIGHT          720
#define HOUGH_RESULT_SIZE   8 

// --- BUFFER DE DADOS COMPARTILHADOS ---
uint8_t hough_result_buffer[HOUGH_RESULT_SIZE];
volatile bool tx_done = false;
volatile bool rx_result_ready = false;
SemaphoreHandle_t xResultSemaphore = NULL; 

// Buffer simulado 8x8 (64 pixels * 3 bytes)
uint8_t image_test_buffer[64 * 3]; 

// =======================================================
// === PROTÓTIPOS DE FUNÇÕES (MOVENDO PARA O TOPO) ===
// =======================================================

// Funções de Tarefas FreeRTOS
void vTaskCommunicate(void *pvParameters);
void vTaskReceiveResult(void *pvParameters);

// Função de Interrupção (ISR) - Deve ser declarada antes de ser usada por irq_set_exclusive_handler
void on_uart_rx(); 

// Função de Teste
void generate_test_image_8x8();

// <<< PROTÓTIPO FORÇADO PARA RESOLVER O ERRO DE DECLARAÇÃO IMPLÍCITA >>>
// Esta função é definida em hardware/uart.h, mas o compilador não a vê.
void __attribute__((weak)) uart_set_irq_en(uart_inst_t *uart, bool rx_en, bool tx_en);



// =======================================================
// === IMPLEMENTAÇÕES DE AUXILIARES ===
// =======================================================

void generate_test_image_8x8() {
    // Cria uma linha vertical escura na coluna 4 (índice 3*4=12)
    for (int i = 0; i < 64 * 3; i++) {
        image_test_buffer[i] = 200; // Fundo cinza claro
    }
    
    for (int y = 0; y < 8; y++) {
        // Localiza o início do pixel na coluna 4
        size_t index = (y * 8 * 3) + (4 * 3);
        image_test_buffer[index + 0] = 50; 
        image_test_buffer[index + 1] = 50; 
        image_test_buffer[index + 2] = 50;
    }
}


// =======================================================
// === IMPLEMENTAÇÃO DA ISR ===
// =======================================================

void on_uart_rx() {
    static uint8_t rx_byte_count = 0;
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    while (uart_is_readable(UART_ID)) {
        uint8_t ch = uart_getc(UART_ID);
        
        if (rx_byte_count < HOUGH_RESULT_SIZE) {
            hough_result_buffer[rx_byte_count] = ch;
            rx_byte_count++;
        }
        
        if (rx_byte_count == HOUGH_RESULT_SIZE) {
            rx_result_ready = true;
            rx_byte_count = 0;
            
            xSemaphoreGiveFromISR(xResultSemaphore, &xHigherPriorityTaskWoken);
        }
    }
    
    if (xHigherPriorityTaskWoken == pdTRUE) {
        portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
    }
}


// =======================================================
// === IMPLEMENTAÇÃO DA TASK 2: RECEPTOR UART (ISR) ===
// =======================================================

void vTaskReceiveResult(void *pvParameters) {
    
    // --- CORREÇÃO DO ERRO ---
    // Usamos 'uart0' (que é a instância struct*) em vez de 'UART_ID' (macro)
    // para garantir que o compilador encontre a definição correta do protótipo
    uart_set_irq_en(uart0, true, false); 
    
    irq_set_exclusive_handler(UART0_IRQ, on_uart_rx); 
    irq_set_enabled(UART0_IRQ, true);
    
    printf("Pico RX Task: Listening for FPGA response.\n");
    
    while(1) {
        vTaskDelay(pdMS_TO_TICKS(100)); // Cede CPU
    }
}


// =======================================================
// === IMPLEMENTAÇÃO DA TASK 1: COMUNICADOR ===
// =======================================================

void vTaskCommunicate(void *pvParameters) {
    // 1. Iniciar UART
    uart_init(UART_ID, BAUD_RATE);
    uart_set_hw_flow(UART_ID, false, false); // Desabilita RTS/CTS
    
    // Configurar formato: 8 data bits, 1 stop bit, No parity
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE); 
    
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    
    printf("Pico Comm Task: UART Initialized (%d baud)\n", BAUD_RATE);
    
    generate_test_image_8x8(); 
    
    while (1) {
        printf("Pico Comm Task: Sending image data (%d bytes)...\n", 64 * 3);
        
        // ENVIO DO QUADRO (Bloqueante)
        uart_write_blocking(UART_ID, image_test_buffer, 64 * 3);
        
        tx_done = true;
        printf("Pico Comm Task: Image TX complete. Waiting for FPGA processing...\n");
        
        // ESPERA PELO RESULTADO (5 segundos de timeout)
        if (xSemaphoreTake(xResultSemaphore, pdMS_TO_TICKS(5000)) == pdTRUE) {
            
            uint32_t rho;
            uint32_t theta;

            // Decodifica Little Endian
            rho   = hough_result_buffer[0] | (hough_result_buffer[1] << 8) | (hough_result_buffer[2] << 16) | (hough_result_buffer[3] << 24);
            theta = hough_result_buffer[4] | (hough_result_buffer[5] << 8) | (hough_result_buffer[6] << 16) | (hough_result_buffer[7] << 24);

            printf("\n--- RESULTS RECEIVED ---\n");
            printf("Final Rho (X Position): %lu\n", rho);
            printf("Final Theta (Index 2/90 deg): %lu\n", theta);
            printf("--------------------------\n\n");
            
            rx_result_ready = false; 
            
        } else {
            printf("Pico Comm Task: Timeout reached.\n");
        }
        
        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}


// =======================================================
// === MAIN SETUP ===
// =======================================================

int main() {
    stdio_init_all();
    
    xResultSemaphore = xSemaphoreCreateBinary();
    
    if (xResultSemaphore == NULL) {
        printf("Failed to create semaphore.\n");
        while(1);
    }

    // Aumentando stack size para a CommTask devido ao printf e à complexidade
    xTaskCreate(vTaskCommunicate, "CommTask", configMINIMAL_STACK_SIZE + 512, NULL, 1, NULL); 
    xTaskCreate(vTaskReceiveResult, "RxTask", configMINIMAL_STACK_SIZE, NULL, 2, NULL);

    printf("Starting FreeRTOS Scheduler...\n");
    vTaskStartScheduler();

    while (1);
    return 0;
}
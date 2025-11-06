#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define BAUD_RATE 9600
#define UART_TX_PIN 16
#define UART_RX_PIN 17
#define WIDTH 16
#define LENGHT 16
#define HEADER_BYTE 0xAA  // Byte de sincronização
#define IMG_BYTES_PACKED 32  // 16×16 bits = 256 bits = 32 bytes empacotados

volatile uint8_t queue[256];  // Buffer para receber resposta do FPGA
volatile int counter = 0;

void send_image_16x16_packed(uint8_t img[WIDTH][LENGHT]);
void convert_to_packed_format(uint8_t img[WIDTH][LENGHT], uint8_t packed[IMG_BYTES_PACKED]);

void on_uart_rx() {
    while (uart_is_readable(UART_ID)) {
        int rv = uart_getc(UART_ID);
        if (rv < 0) break;
        uint8_t byte = (uint8_t)rv;

        // ========== CORREÇÃO: ARMAZENA TUDO DIRETAMENTE ==========
        // O FPGA não envia header de volta, envia direto os dados
        // Primeiro byte = num_lines, depois [rho, theta, votes] * num_lines
        
        if (counter < 256) {
            queue[counter++] = byte;
            printf("RX[%d]: 0x%02X (%d)\n", counter-1, byte, byte);
        }
    }
}

// Converte matriz 16×16 para formato empacotado (32 bytes)
// Cada byte contém 8 pixels (1 bit por pixel)
void convert_to_packed_format(uint8_t img[WIDTH][LENGHT], uint8_t packed[IMG_BYTES_PACKED]) {
    for (int byte_idx = 0; byte_idx < IMG_BYTES_PACKED; byte_idx++) {
        uint8_t packed_byte = 0x00;
        
        // Cada byte empacota 8 pixels consecutivos
        for (int bit_idx = 0; bit_idx < 8; bit_idx++) {
            int pixel_idx = byte_idx * 8 + bit_idx;
            int row = pixel_idx / LENGHT;
            int col = pixel_idx % LENGHT;
            
            // Se pixel é branco (!=0), liga o bit correspondente
            if (img[row][col] != 0x00) {
                packed_byte |= (1 << bit_idx);
            }
        }
        
        packed[byte_idx] = packed_byte;
    }
}

// Envia imagem no formato empacotado (32 bytes)
void send_image_16x16_packed(uint8_t img[WIDTH][LENGHT]) {
    uint8_t packed[IMG_BYTES_PACKED];
    
    // Converte para formato empacotado
    convert_to_packed_format(img, packed);
    
    // ========== DEBUG: MOSTRA BYTES EMPACOTADOS ==========
    printf("\n📦 Bytes empacotados enviados (HEX):\n");
    for (int i = 0; i < IMG_BYTES_PACKED; i++) {
        // Imprime em binário (MSB -> LSB)
        for (int bit = 7; bit >= 0; bit--) {
            printf("%d", (packed[i] >> bit) & 1);
        }
        printf(" ");
        if ((i + 1) % 8 == 0) printf("\n");
    }
    printf("\n");
    
    printf("📦 Bytes empacotados enviados (BINÁRIO):\n");
    for (int i = 0; i < IMG_BYTES_PACKED; i++) {
        for (int bit = 0; bit < 8; bit++) {
            printf("%d", (packed[i] >> bit) & 1);
        }
        printf(" ");
        if ((i + 1) % 4 == 0) printf("\n");
    }
    printf("\n");
    // ====================================================
    
    // Envia os 32 bytes empacotados
    for (int i = 0; i < IMG_BYTES_PACKED; i++) {
        while (!uart_is_writable(UART_ID)) tight_loop_contents();
        uart_putc_raw(UART_ID, packed[i]);
        sleep_ms(2);  // 2ms por byte
    }
}

// ========== FUNÇÕES PARA CRIAR DIFERENTES PADRÕES DE TESTE ==========

// Teste 1: Diagonal principal (45°)
void create_diagonal(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i == j) ? 255 : 0;
        }
    }
}

// Teste 2: Linha vertical no centro (x=8)
void create_vertical(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (j == 8) ? 255 : 0;
        }
    }
}

// Teste 3: Linha horizontal no centro (y=8)
void create_horizontal(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i == 8) ? 255 : 0;
        }
    }
}

// Teste 4: Anti-diagonal (135°) - linha de canto superior direito ao inferior esquerdo
void create_antidiagonal(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i + j == WIDTH - 1) ? 255 : 0;
        }
    }
}

// Teste 5: Duas linhas verticais paralelas
void create_two_verticals(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (j == 5 || j == 10) ? 255 : 0;
        }
    }
}

// Teste 6: Cruz (vertical + horizontal)
void create_cross(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i == 8 || j == 8) ? 255 : 0;
        }
    }
}

// Teste 7: Quadrado (bordas da imagem)
void create_square(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i == 0 || i == WIDTH-1 || j == 0 || j == LENGHT-1) ? 255 : 0;
        }
    }
}

// Teste 8: X (duas diagonais)
void create_x_pattern(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i == j || i + j == WIDTH - 1) ? 255 : 0;
        }
    }
}

// Teste 9: Linha vertical na borda esquerda
void create_vertical_left(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (j == 0) ? 255 : 0;
        }
    }
}

// Teste 10: Linha horizontal na borda superior
void create_horizontal_top(uint8_t matrix[WIDTH][LENGHT]) {
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            matrix[i][j] = (i == 0) ? 255 : 0;
        }
    }
}

int main() {
    stdio_usb_init();
    sleep_ms(2000);

    uint8_t matrix[WIDTH][LENGHT];
    const char* test_name;
    const char* expected_angle;
    
    // ========== ESCOLHA O TESTE AQUI ==========
    // Descomente APENAS UMA linha abaixo:
    
    // create_diagonal(matrix);
    // test_name = "Diagonal Principal (0,0)→(15,15)";
    // expected_angle = "θ ≈ 135° (normal à linha 45°)";
    
    // create_vertical(matrix);
    // test_name = "Linha Vertical no Centro (x=8)";
    // expected_angle = "θ ≈ 90° (normal à linha vertical)";
    
    create_horizontal(matrix);
    test_name = "Linha Horizontal no Centro (y=8)";
    expected_angle = "θ ≈ 0° ou 180° (normal à linha horizontal)";
    
    // create_antidiagonal(matrix);
    // test_name = "Anti-diagonal (15,0)→(0,15)";
    // expected_angle = "θ ≈ 45° (normal à linha 135°)";
    
    // create_two_verticals(matrix);
    // test_name = "Duas Linhas Verticais Paralelas (x=5 e x=10)";
    // expected_angle = "θ ≈ 90° para ambas";
    
    // create_cross(matrix);
    // test_name = "Cruz (Vertical + Horizontal)";
    // expected_angle = "θ ≈ 0° e 90° (2 linhas detectadas)";
    
    // create_square(matrix);
    // test_name = "Quadrado (Bordas da Imagem)";
    // expected_angle = "4 linhas: θ ≈ 0°, 90°, 0°, 90°";
    
    // create_x_pattern(matrix);
    // test_name = "Padrão X (Duas Diagonais)";
    // expected_angle = "θ ≈ 45° e 135° (2 linhas)";
    
    // create_vertical_left(matrix);
    // test_name = "Linha Vertical na Borda Esquerda (x=0)";
    // expected_angle = "θ ≈ 90°";
    
    // create_horizontal_top(matrix);
    // test_name = "Linha Horizontal na Borda Superior (y=0)";
    // expected_angle = "θ ≈ 0° ou 180°";
    
    // ==========================================
    
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE);
    uart_set_fifo_enabled(UART_ID, true);
    
    printf("\n╔════════════════════════════════════════════════════╗\n");
    printf("║    TESTE HOUGH TRANSFORM - DETECÇÃO DE LINHAS     ║\n");
    printf("╚════════════════════════════════════════════════════╝\n");
    printf("Header: 0x%02X | Formato: 32 bytes empacotados\n", HEADER_BYTE);
    printf("Imagem: 16×16 pixels (8 pixels/byte)\n\n");
    
    printf("🔍 TESTE SELECIONADO: %s\n", test_name);
    printf("📐 Ângulo Esperado: %s\n\n", expected_angle);
    
    // Mostra a matriz original
    printf("Matriz Original (16x16):\n");
    for (int i = 0; i < WIDTH; i++) {
        for (int j = 0; j < LENGHT; j++) {
            printf("%s", matrix[i][j] ? "█" : "·");
        }
        printf("\n");
    }
    printf("\n");
    
    // Limpa buffer UART múltiplas vezes
    for (int clear = 0; clear < 5; clear++) {
        while (uart_is_readable(UART_ID)) uart_getc(UART_ID);
        sleep_ms(20);
    }
    
    counter = 0;

    int UART_IRQ = (UART_ID == uart0) ? UART0_IRQ : UART1_IRQ;
    irq_set_exclusive_handler(UART_IRQ, on_uart_rx);
    
    // ========== CORREÇÃO: NÃO HABILITA IRQ AINDA ==========
    // Envia TUDO primeiro (header + imagem)
    // Só depois habilita IRQ para receber resposta
    
    // ENVIA HEADER PRIMEIRO
    printf("Enviando header 0xAA...\n");
    uart_putc_raw(UART_ID, HEADER_BYTE);
    sleep_ms(10);  // Espera header ser processado
    
    // Depois envia a imagem no formato empacotado (32 bytes)
    printf("Enviando imagem empacotada (32 bytes)...\n");
    send_image_16x16_packed(matrix);
    
    // ========== AGORA SIM: HABILITA IRQ ==========
    // Neste ponto, header + imagem já foram enviados
    // Qualquer dado recebido agora é a resposta do FPGA
    printf("Habilitando IRQ para receber resposta...\n");
    irq_set_enabled(UART_IRQ, true);
    uart_set_irq_enables(UART_ID, true, false);

    printf("Aguardando resposta do FPGA...\n");
    
    // Aguarda tempo suficiente para Hough processar + transmitir resposta
    // Hough: ~500ms, Transmissão: ~100ms @ 9600 baud
    sleep_ms(1000);
    uart_set_irq_enables(UART_ID, false, false);
    irq_set_enabled(UART_IRQ, false);

    printf("\n=== RESULTADO ===\n");
    printf("Bytes recebidos: %d\n", counter);
    
    if (counter == 0) {
        printf("❌ Nenhuma resposta do FPGA.\n");
    } else {
        printf("✅ FPGA RESPONDEU!\n\n");
        
        // Interpreta resposta: num_lines + [rho, theta, votes] * num_lines
        uint8_t num_lines = queue[0];
        printf("Primeiro byte (num_lines): %d (0x%02X)\n", num_lines, num_lines);
        
        // Diagnóstico: verifica se formato parece correto
        int expected_bytes = 1 + (num_lines * 3);
        if (num_lines <= 4 && counter >= expected_bytes) {
            printf("✓ Formato parece válido (%d bytes esperados, %d recebidos)\n", 
                   expected_bytes, counter);
        } else {
            printf("⚠ Formato inesperado (esperava %d bytes para %d linhas)\n", 
                   expected_bytes, num_lines);
        }
        
        if (num_lines > 0 && num_lines <= 4) {
            printf("\n📊 Linhas detectadas:\n");
            for (int i = 0; i < num_lines; i++) {
                int idx = 1 + i * 3;  // 1 byte num_lines + 3 bytes por linha
                
                if (idx + 2 < counter) {
                    uint8_t rho = queue[idx];
                    uint8_t theta = queue[idx + 1];
                    uint8_t votes = queue[idx + 2];
                    
                    printf("  Linha %d: ρ=%3d (dist), θ=%3d°, votos=%3d\n", 
                           i + 1, rho, theta, votes);
                }
            }
        } else if (num_lines == 0) {
            printf("\n⚠ FPGA não detectou nenhuma linha!\n");
            printf("Possíveis causas:\n");
            printf("  - Threshold muito alto (verificar hough_transform.sv)\n");
            printf("  - Imagem não chegou corretamente ao FPGA\n");
            printf("  - Problema no processamento Hough\n");
        } else {
            printf("\n⚠ num_lines inválido: %d (esperado: 0-4)\n", num_lines);
        }
        
        printf("\n📦 Dados brutos recebidos (HEX):\n");
        for (int i = 0; i < counter; i++) {
            printf("0x%02X ", queue[i]);
            if ((i + 1) % 8 == 0) printf("\n");
        }
        if (counter % 8 != 0) printf("\n");
        
        printf("\n📦 Dados brutos recebidos (DECIMAL):\n");
        for (int i = 0; i < counter; i++) {
            printf("%3d ", queue[i]);
            if ((i + 1) % 8 == 0) printf("\n");
        }
        if (counter % 8 != 0) printf("\n");
    }
    uart_set_irq_enables(UART_ID, true, false);
    irq_set_enabled(UART_IRQ, true);
    while (1) {

    };
    
}
#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/uart.h"
#include <math.h>
#include <stdlib.h>

// ========== CONFIGURAÇÃO: ESCOLHA O MODO ==========
// Descomente UMA das linhas abaixo:
// #define MODE_16x16   // Modo original: testa padrões 16×16
#define MODE_64x64   // Modo estendido: processa imagens 64×64 em tiles
// ==================================================

#define UART_ID uart0
#define BAUD_RATE 9600
#define UART_TX_PIN 16
#define UART_RX_PIN 17
#define WIDTH 16
#define LENGHT 16
#define HEADER_BYTE 0xAA  // Byte de sincronização
#define IMG_BYTES_PACKED 32  // 16×16 bits = 256 bits = 32 bytes empacotados

#ifdef MODE_64x64
#define GLOBAL_SIZE 64
#define TILE_SIZE 16
#define GRID_SIZE 4  // 64/16 = 4 tiles por dimensão
#define MAX_LINES_TOTAL 64  // Máximo de linhas detectadas em toda imagem 64×64
#endif

volatile uint8_t queue[256];  // Buffer para receber resposta do FPGA
volatile int counter = 0;

void send_image_16x16_packed(uint8_t img[WIDTH][LENGHT]);
void convert_to_packed_format(uint8_t img[WIDTH][LENGHT], uint8_t packed[IMG_BYTES_PACKED]);

#ifdef MODE_64x64
// ========== ESTRUTURAS E FUNÇÕES PARA MODO 64×64 ==========

typedef struct {
    uint8_t rho, theta, votes;  // Dados recebidos do FPGA
    int tile_x, tile_y;          // Posição do tile no grid 4×4
    float global_rho;            // ρ convertido para coordenadas globais 64×64
    float global_x_intercept;    // Interseção com eixo X (para visualização)
    float global_y_intercept;    // Interseção com eixo Y (para visualização)
} DetectedLine;

uint8_t global_image[GLOBAL_SIZE][GLOBAL_SIZE];  // Imagem 64×64
DetectedLine all_lines[MAX_LINES_TOTAL];         // Todas as linhas detectadas
int total_lines_detected = 0;

// Extrai tile 16×16 da imagem global
void extract_tile(int tile_x, int tile_y, uint8_t tile[TILE_SIZE][TILE_SIZE]) {
    int offset_x = tile_x * TILE_SIZE;
    int offset_y = tile_y * TILE_SIZE;
    
    for (int y = 0; y < TILE_SIZE; y++) {
        for (int x = 0; x < TILE_SIZE; x++) {
            tile[y][x] = global_image[offset_y + y][offset_x + x];
        }
    }
}

// Converte tile para formato empacotado
void tile_to_packed(uint8_t tile[TILE_SIZE][TILE_SIZE], uint8_t packed[IMG_BYTES_PACKED]) {
    for (int byte_idx = 0; byte_idx < IMG_BYTES_PACKED; byte_idx++) {
        uint8_t packed_byte = 0x00;
        for (int bit_idx = 0; bit_idx < 8; bit_idx++) {
            int pixel_idx = byte_idx * 8 + bit_idx;
            int row = pixel_idx / TILE_SIZE;
            int col = pixel_idx % TILE_SIZE;
            if (tile[row][col] != 0x00) {
                packed_byte |= (1 << bit_idx);
            }
        }
        packed[byte_idx] = packed_byte;
    }
}

// Converte coordenadas locais do tile para globais
void convert_to_global_coordinates(DetectedLine* line) {
    int offset_x = line->tile_x * TILE_SIZE;
    int offset_y = line->tile_y * TILE_SIZE;
    
    float theta_rad = (line->theta * M_PI) / 180.0f;
    float cos_theta = cosf(theta_rad);
    float sin_theta = sinf(theta_rad);
    
    // CORREÇÃO: ρ_global = offset_x*cos(θ) + offset_y*sin(θ) + ρ_local
    // A fórmula correta é calcular ρ a partir da ORIGEM GLOBAL do tile
    // O ρ_local já está na escala correta do FPGA (0-15)
    line->global_rho = (offset_x * cos_theta) + (offset_y * sin_theta) + line->rho;
    
    // Calcula interseções para visualização
    if (fabs(cos_theta) > 0.01f) {
        line->global_x_intercept = line->global_rho / cos_theta;
    } else {
        line->global_x_intercept = 999.0f;  // Infinito (linha horizontal)
    }
    
    if (fabs(sin_theta) > 0.01f) {
        line->global_y_intercept = line->global_rho / sin_theta;
    } else {
        line->global_y_intercept = 999.0f;  // Infinito (linha vertical)
    }
}

// Processa um tile no FPGA e armazena resultados
int process_tile_on_fpga(int tile_x, int tile_y) {
    uint8_t tile[TILE_SIZE][TILE_SIZE];
    uint8_t packed[IMG_BYTES_PACKED];
    
    // Extrai tile da imagem global
    extract_tile(tile_x, tile_y, tile);
    tile_to_packed(tile, packed);
    
    // Limpa buffer UART
    counter = 0;
    while (uart_is_readable(UART_ID)) uart_getc(UART_ID);
    
    // Envia header + tile
    uart_putc_raw(UART_ID, HEADER_BYTE);
    sleep_ms(10);
    
    for (int i = 0; i < IMG_BYTES_PACKED; i++) {
        uart_putc_raw(UART_ID, packed[i]);
        sleep_ms(2);
    }
    
    // Aguarda resposta
    sleep_ms(800);  // FPGA processa + transmite
    
    if (counter == 0) return 0;
    
    // Interpreta resposta
    uint8_t num_lines = queue[0];
    if (num_lines > 4) num_lines = 4;
    
    for (int i = 0; i < num_lines && total_lines_detected < MAX_LINES_TOTAL; i++) {
        int idx = 1 + i * 3;
        if (idx + 2 < counter) {
            DetectedLine* line = &all_lines[total_lines_detected++];
            line->rho = queue[idx];
            line->theta = queue[idx + 1];
            line->votes = queue[idx + 2];
            line->tile_x = tile_x;
            line->tile_y = tile_y;
            convert_to_global_coordinates(line);
        }
    }
    
    return num_lines;
}

// Visualiza imagem 64×64 com linhas detectadas
void print_image_with_lines() {
    char display[GLOBAL_SIZE][GLOBAL_SIZE];
    
    // Inicializa display
    for (int y = 0; y < GLOBAL_SIZE; y++) {
        for (int x = 0; x < GLOBAL_SIZE; x++) {
            display[y][x] = global_image[y][x] ? '#' : '.';
        }
    }
    
    // Desenha linhas detectadas
    for (int i = 0; i < total_lines_detected; i++) {
        DetectedLine* line = &all_lines[i];
        float theta_rad = (line->theta * M_PI) / 180.0f;
        float cos_theta = cosf(theta_rad);
        float sin_theta = sinf(theta_rad);
        
        // Desenha linha percorrendo tanto X quanto Y para melhor cobertura
        // Para linhas verticais (θ≈90°), percorre Y
        // Para linhas horizontais (θ≈0°), percorre X
        
        if (fabs(sin_theta) > 0.5f) {
            // Linha mais vertical: percorre Y
            for (int y = 0; y < GLOBAL_SIZE; y++) {
                if (fabs(sin_theta) > 0.01f) {
                    float x = (line->global_rho - y * sin_theta) / cos_theta;
                    int x_int = (int)(x + 0.5f);
                    if (x_int >= 0 && x_int < GLOBAL_SIZE) {
                        if (display[y][x_int] == '.') display[y][x_int] = '|';
                        else if (display[y][x_int] == '#') display[y][x_int] = '+';
                        else if (display[y][x_int] == '-') display[y][x_int] = '+';
                    }
                }
            }
        } else {
            // Linha mais horizontal: percorre X
            for (int x = 0; x < GLOBAL_SIZE; x++) {
                if (fabs(cos_theta) > 0.01f) {
                    float y = (line->global_rho - x * cos_theta) / sin_theta;
                    int y_int = (int)(y + 0.5f);
                    if (y_int >= 0 && y_int < GLOBAL_SIZE) {
                        if (display[y_int][x] == '.') display[y_int][x] = '-';
                        else if (display[y_int][x] == '#') display[y_int][x] = '+';
                        else if (display[y_int][x] == '|') display[y_int][x] = '+';
                    }
                }
            }
        }
    }
    
    // Imprime resultado
    printf("\n64x64 Image with Detected Lines:\n");
    for (int y = 0; y < GLOBAL_SIZE; y++) {
        for (int x = 0; x < GLOBAL_SIZE; x++) {
            printf("%c", display[y][x]);
        }
        printf("\n");
    }
}

// ========== PADRÕES DE TESTE 64×64 ==========

void create_test_cross_64x64() {
    for (int y = 0; y < GLOBAL_SIZE; y++) {
        for (int x = 0; x < GLOBAL_SIZE; x++) {
            global_image[y][x] = (x == 32 || y == 32) ? 255 : 0;
        }
    }
}

void create_test_diagonal_64x64() {
    for (int y = 0; y < GLOBAL_SIZE; y++) {
        for (int x = 0; x < GLOBAL_SIZE; x++) {
            global_image[y][x] = (x == y) ? 255 : 0;
        }
    }
}

void create_test_rectangle_64x64() {
    for (int y = 0; y < GLOBAL_SIZE; y++) {
        for (int x = 0; x < GLOBAL_SIZE; x++) {
            global_image[y][x] = ((x >= 20 && x <= 44 && (y == 12 || y == 52)) ||
                                  (y >= 12 && y <= 52 && (x == 20 || x == 44))) ? 255 : 0;
        }
    }
}

void create_test_x_pattern_64x64() {
    for (int y = 0; y < GLOBAL_SIZE; y++) {
        for (int x = 0; x < GLOBAL_SIZE; x++) {
            global_image[y][x] = (x == y || x + y == GLOBAL_SIZE - 1) ? 255 : 0;
        }
    }
}

#endif  // MODE_64x64

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

#ifdef MODE_16x16
    // ========== MODO 16×16: TESTES ORIGINAIS ==========
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
#endif

#ifdef MODE_64x64
    // ========== MODO 64×64: PROCESSAMENTO POR TILES ==========
    
    // Escolha o padrão de teste (descomente UMA linha):
    create_test_cross_64x64();        // Cruz no centro
    // create_test_diagonal_64x64();     // Diagonal principal
    // create_test_rectangle_64x64();    // Retângulo
    // create_test_x_pattern_64x64();    // Padrão X
    
    printf("\n╔════════════════════════════════════════════════════╗\n");
    printf("║   PROCESSAMENTO 64×64 EM TILES 16×16 - HOUGH     ║\n");
    printf("╚════════════════════════════════════════════════════╝\n");
    printf("Grid: 4×4 tiles (16 tiles de 16×16)\n");
    printf("Tempo estimado: ~13 segundos (800ms/tile)\n\n");
    
    // Mostra imagem original
    printf("Imagem Original 64×64:\n");
    for (int y = 0; y < GLOBAL_SIZE; y++) {
        for (int x = 0; x < GLOBAL_SIZE; x++) {
            printf("%c", global_image[y][x] ? '#' : '.');
        }
        printf("\n");
    }
    printf("\n");
#endif
    
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
    uart_set_format(UART_ID, 8, 1, UART_PARITY_NONE);
    uart_set_fifo_enabled(UART_ID, true);
    
    int UART_IRQ = (UART_ID == uart0) ? UART0_IRQ : UART1_IRQ;
    irq_set_exclusive_handler(UART_IRQ, on_uart_rx);

#ifdef MODE_16x16
    // ========== PROCESSAMENTO 16×16 ==========
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
    
    // ENVIA HEADER PRIMEIRO
    printf("Enviando header 0xAA...\n");
    uart_putc_raw(UART_ID, HEADER_BYTE);
    sleep_ms(10);  // Espera header ser processado
    
    // Depois envia a imagem no formato empacotado (32 bytes)
    printf("Enviando imagem empacotada (32 bytes)...\n");
    send_image_16x16_packed(matrix);
    
    // Habilita IRQ para receber resposta
    printf("Habilitando IRQ para receber resposta...\n");
    irq_set_enabled(UART_IRQ, true);
    uart_set_irq_enables(UART_ID, true, false);

    printf("Aguardando resposta do FPGA...\n");
    
    // Aguarda tempo suficiente para Hough processar + transmitir resposta
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
#endif

#ifdef MODE_64x64
    // ========== PROCESSAMENTO 64×64 EM TILES ==========
    
    // Habilita IRQ para receber dados durante processamento
    irq_set_enabled(UART_IRQ, true);
    uart_set_irq_enables(UART_ID, true, false);
    
    printf("Iniciando processamento dos 16 tiles...\n\n");
    
    total_lines_detected = 0;
    int tiles_processed = 0;
    
    for (int ty = 0; ty < GRID_SIZE; ty++) {
        for (int tx = 0; tx < GRID_SIZE; tx++) {
            tiles_processed++;
            printf("[Tile %d/16] Posição (%d,%d) - ", tiles_processed, tx, ty);
            
            int lines_in_tile = process_tile_on_fpga(tx, ty);
            
            if (lines_in_tile > 0) {
                printf("%d linhas detectadas\n", lines_in_tile);
            } else {
                printf("Nenhuma linha detectada\n");
            }
            
            sleep_ms(200);  // Intervalo entre tiles
        }
    }
    
    uart_set_irq_enables(UART_ID, false, false);
    irq_set_enabled(UART_IRQ, false);
    
    printf("\n=== RESULTADO BRUTO ===\n");
    printf("Total de detecções: %d\n\n", total_lines_detected);
    
    // ========== FILTRAGEM: AGRUPA LINHAS SIMILARES ==========
    // Considera similares se |Δρ| < 3 e |Δθ| < 15°
    DetectedLine filtered_lines[MAX_LINES_TOTAL];
    int num_filtered = 0;
    
    for (int i = 0; i < total_lines_detected; i++) {
        bool is_duplicate = false;
        
        for (int j = 0; j < num_filtered; j++) {
            float rho_diff = fabsf(all_lines[i].global_rho - filtered_lines[j].global_rho);
            int theta_diff = abs((int)all_lines[i].theta - (int)filtered_lines[j].theta);
            
            // Considera duplicata se ρ e θ muito próximos
            if (rho_diff < 3.0f && theta_diff < 15) {
                is_duplicate = true;
                // Mantém a linha com mais votos
                if (all_lines[i].votes > filtered_lines[j].votes) {
                    filtered_lines[j] = all_lines[i];
                }
                break;
            }
        }
        
        if (!is_duplicate && num_filtered < MAX_LINES_TOTAL) {
            filtered_lines[num_filtered++] = all_lines[i];
        }
    }
    
    printf("\n=== RESULTADO FILTRADO ===\n");
    printf("Linhas únicas: %d (após agrupar similares)\n\n", num_filtered);
    
    if (num_filtered > 0) {
        printf("Linhas principais detectadas:\n");
        for (int i = 0; i < num_filtered; i++) {
            DetectedLine* line = &filtered_lines[i];
            printf("  Linha %d: ρ_global=%.2f, θ=%d°, votos=%d\n",
                   i + 1, line->global_rho, line->theta, line->votes);
        }
        
        printf("\n");
        
        // Copia linhas filtradas de volta para visualização
        for (int i = 0; i < num_filtered; i++) {
            all_lines[i] = filtered_lines[i];
        }
        total_lines_detected = num_filtered;
        
        print_image_with_lines();
    } else {
        printf("Nenhuma linha detectada em toda a imagem.\n");
    }
#endif
    
    uart_set_irq_enables(UART_ID, true, false);
    irq_set_enabled(UART_IRQ, true);
    
    while (1) {
        tight_loop_contents();
    }
    
    return 0;
}
// uart_example_colorlight_i9.sv
// Exemplo UART otimizado para Colorlight i9 (Clock 25 MHz)
// 
// Diferenças em relação ao uart_example_fpga.sv:
//   - Ajustado para CLK_FREQ_HZ = 25_000_000 (clock real do Colorlight i9)
//   - CLKS_PER_BIT = 217 para 115200 baud @ 25 MHz
//   - Pinagem conforme uart_colorlight_i9.lpf

module uart_example_colorlight_i9 (
    // Clock e Reset (conforme LPF)
    input  logic       clk_50mhz,       // P3 - Na verdade é 25 MHz no Colorlight i9
    input  logic       reset_n,         // D1 - Botão de reset (ativo baixo)
    
    // UART (conexão com Raspberry Pi Pico)
    input  logic       uart_rx,         // D2 - Conectar ao TX do Pico (GP0)
    output logic       uart_tx,         // E2 - Conectar ao RX do Pico (GP1)
    
    // LEDs de controle (array de 4 LEDs)
    output logic [3:0] leds,            // B1, C2, C1, D3 - Controlados por UART
    
    // LEDs de status UART
    output logic       led_rx_active,   // E3 - Pisca quando recebe
    output logic       led_tx_active    // F3 - Pisca quando transmite
);

    // ========================================================================
    // IMPORTANTE: O Colorlight i9 tem clock de 25 MHz, não 50 MHz!
    // Ajuste o parâmetro CLK_FREQ_HZ para 25_000_000
    // CLKS_PER_BIT = 25_000_000 / 115200 = 217 (aproximadamente)
    // ========================================================================

    // Sinais da interface UART
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active, tx_done;
    logic       rx_dv;
    logic [7:0] rx_byte;
    
    // Instancia o módulo UART configurado para 25 MHz
    uart_top #(
        .CLK_FREQ_HZ(25_000_000),  // Clock real do Colorlight i9
        .BAUD_RATE(115200)          // Baud rate padrão
    ) uart_inst (
        .i_clk       (clk_50mhz),   // Nome mantido, mas é 25 MHz
        .i_rst_n     (reset_n),
        .i_uart_rx   (uart_rx),
        .o_uart_tx   (uart_tx),
        .i_tx_dv     (tx_dv),
        .i_tx_byte   (tx_byte),
        .o_tx_active (tx_active),
        .o_tx_done   (tx_done),
        .o_rx_dv     (rx_dv),
        .o_rx_byte   (rx_byte)
    );
    
    // Máquina de estados para processar comandos
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        PROCESS = 2'b01,
        RESPOND = 2'b10
    } state_t;
    
    state_t state;
    
    // Lógica de controle dos LEDs via UART
    always_ff @(posedge clk_50mhz or negedge reset_n) begin
        if (!reset_n) begin
            leds    <= 4'b0000;
            tx_dv   <= 1'b0;
            tx_byte <= 8'h00;
            state   <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    tx_dv <= 1'b0;
                    
                    if (rx_dv) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    // Interpreta comandos recebidos do Raspberry Pi Pico
                    case (rx_byte)
                        8'h00: leds <= 4'b0000;  // Apaga todos os LEDs
                        8'h01: leds <= 4'b0001;  // LED 0 ON
                        8'h02: leds <= 4'b0011;  // LEDs 0-1 ON
                        8'h03: leds <= 4'b0111;  // LEDs 0-2 ON
                        8'h04: leds <= 4'b1111;  // Todos os LEDs ON
                        8'h10: leds <= ~leds;    // Inverte estado dos LEDs
                        8'hFF: leds <= 4'b1010;  // Padrão de teste (alternado)
                        default: ; // Comando desconhecido, ignora
                    endcase
                    
                    state <= RESPOND;
                end
                
                RESPOND: begin
                    // Envia confirmação de volta ao Pico (ACK)
                    tx_byte <= 8'hAA;  // Código de sucesso
                    tx_dv   <= 1'b1;
                    state   <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Indicadores visuais de atividade UART
    assign led_rx_active = rx_dv;
    assign led_tx_active = tx_active;

endmodule


// ============================================================================
// NOTAS IMPORTANTES PARA COLORLIGHT I9:
// ============================================================================
//
// 1. CLOCK:
//    - O Colorlight i9 possui oscilador de 25 MHz no pino P3
//    - Não é necessário PLL para 115200 baud
//    - Se precisar de 50 MHz no futuro, use PLL da Lattice (EHXPLLL)
//
// 2. PINAGEM (conforme uart_colorlight_i9.lpf):
//    - Clock:  P3  (25 MHz)
//    - Reset:  D1  (botão, pull-up)
//    - TX:     E2  (FPGA -> Pico RX/GP1)
//    - RX:     D2  (FPGA <- Pico TX/GP0, pull-up)
//    - LEDs:   B1, C2, C1, D3
//    - RX LED: E3
//    - TX LED: F3
//
// 3. CONEXÃO COM RASPBERRY PI PICO:
//    ┌──────────────────┐           ┌─────────────────────┐
//    │  Colorlight i9   │           │  Raspberry Pi Pico  │
//    ├──────────────────┤           ├─────────────────────┤
//    │ TX (E2)  ────────┼──────────>│ RX (GP1)           │
//    │ RX (D2)  <───────┼───────────│ TX (GP0)           │
//    │ GND      ────────┼───────────│ GND                │
//    └──────────────────┘           └─────────────────────┘
//
// 4. TESTE:
//    - Executar flash_uart.bat para gravar o FPGA
//    - Carregar test_fpga_uart.py no Raspberry Pi Pico
//    - LEDs devem responder aos comandos do Pico
//    - led_rx_active pisca ao receber
//    - led_tx_active pisca ao transmitir
//
// 5. COMANDOS UART (enviados pelo Pico):
//    0x00 - Apaga todos os LEDs
//    0x01 - Acende LED 0
//    0x02 - Acende LEDs 0-1
//    0x03 - Acende LEDs 0-2
//    0x04 - Acende todos os LEDs
//    0x10 - Inverte estado dos LEDs
//    0xFF - Padrão de teste (0b1010)
//
//    Resposta do FPGA: 0xAA (sucesso)
//
// ============================================================================

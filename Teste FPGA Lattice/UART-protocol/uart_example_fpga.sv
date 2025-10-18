// uart_example_fpga.sv
// Exemplo Prático: FPGA como Controlador de LEDs via UART
// 
// Protocolo simples:
//   Pico envia: 0x01 = Acende LED
//   Pico envia: 0x00 = Apaga LED
//   FPGA responde: 0xAA = Comando executado com sucesso

module uart_example_fpga (
    // Clock e Reset
    input  logic       clk_50mhz,      // Clock principal 50 MHz
    input  logic       reset_n,         // Reset ativo baixo
    
    // UART (conexão com Raspberry Pi Pico)
    input  logic       uart_rx,         // Conectar ao TX do Pico
    output logic       uart_tx,         // Conectar ao RX do Pico
    
    // LEDs de controle
    output logic [3:0] leds,            // 4 LEDs controlados por UART
    
    // Status visual
    output logic       led_rx_active,   // LED pisca quando recebe dado
    output logic       led_tx_active    // LED pisca quando transmite dado
);

    // Sinais da interface UART
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active, tx_done;
    logic       rx_dv;
    logic [7:0] rx_byte;
    
    // Instancia o módulo UART
    uart_top #(
        .CLK_FREQ_HZ(50_000_000),
        .BAUD_RATE(115200)
    ) uart_inst (
        .i_clk       (clk_50mhz),
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
                    // Interpreta comandos recebidos
                    case (rx_byte)
                        8'h00: leds <= 4'b0000;  // Apaga todos os LEDs
                        8'h01: leds <= 4'b0001;  // LED 0 ON
                        8'h02: leds <= 4'b0011;  // LEDs 0-1 ON
                        8'h03: leds <= 4'b0111;  // LEDs 0-2 ON
                        8'h04: leds <= 4'b1111;  // Todos os LEDs ON
                        8'h10: leds <= ~leds;    // Inverte estado dos LEDs
                        8'hFF: leds <= 4'b1010;  // Padrão de teste
                        default: ; // Comando desconhecido, ignora
                    endcase
                    
                    state <= RESPOND;
                end
                
                RESPOND: begin
                    // Envia confirmação de volta ao Pico
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


// ==================== CÓDIGO PARA RASPBERRY PI PICO ====================
//
// MicroPython - Testar comunicação com FPGA
// Salvar como: test_fpga_uart.py
//
// from machine import UART, Pin
// import time
// 
// # Configurar UART
// uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
// 
// def send_command(cmd):
//     """Envia comando para FPGA e aguarda resposta"""
//     uart.write(bytes([cmd]))
//     time.sleep(0.01)  # Aguarda 10ms
//     
//     if uart.any():
//         response = uart.read(1)
//         if response[0] == 0xAA:
//             print(f"Comando 0x{cmd:02X} executado com sucesso!")
//             return True
//     print(f"Erro ao executar comando 0x{cmd:02X}")
//     return False
// 
// # Teste sequencial
// print("=== Teste FPGA-Pico UART ===")
// 
// send_command(0x00)  # Apaga LEDs
// time.sleep(1)
// 
// send_command(0x01)  # LED 0
// time.sleep(1)
// 
// send_command(0x02)  # LEDs 0-1
// time.sleep(1)
// 
// send_command(0x03)  # LEDs 0-2
// time.sleep(1)
// 
// send_command(0x04)  # Todos os LEDs
// time.sleep(1)
// 
// send_command(0x10)  # Inverte
// time.sleep(1)
// 
// send_command(0xFF)  # Padrão teste
// time.sleep(1)
// 
// send_command(0x00)  # Apaga
// print("Teste concluído!")
//
// ========================================================================

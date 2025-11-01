// uart_rx.sv
// UART Receiver Module - SystemVerilog
// Otimizado para comunicação FPGA <-> Raspberry Pi Pico
//
// Configuração padrão: 115200 baud, 8N1 (8 bits, No parity, 1 stop bit)
// Clock: 50 MHz
// CLKS_PER_BIT = 50_000_000 / 115200 = 434 (aproximadamente)

module uart_rx #(
    parameter CLKS_PER_BIT = 434,  // Para 115200 baud @ 50MHz
    parameter CLK_FREQ_HZ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic       i_clk,        // Clock do sistema
    input  logic       i_rst_n,      // Reset assíncrono ativo baixo
    input  logic       i_rx_serial,  // Sinal UART RX (conectar ao Pico TX)
    
    output logic       o_rx_dv,      // Data Valid: pulso quando dado pronto
    output logic [7:0] o_rx_byte     // Byte recebido
);

    // Estados da máquina de estados
    typedef enum logic [2:0] {
        IDLE         = 3'b000,
        START_BIT    = 3'b001,
        DATA_BITS    = 3'b010,
        STOP_BIT     = 3'b011,
        CLEANUP      = 3'b100,
        WAIT_IDLE    = 3'b101  // Aguarda linha retornar a IDLE (HIGH)
    } state_t;
    
    state_t state;
    
    // Registradores para metastabilidade (triple-flop + majority vote)
    logic rx_data_r1, rx_data_r2, rx_data_r3;
    logic rx_filtered;
    
    // Registradores internos
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] rx_byte;
    logic rx_line_was_high;  // Flag para garantir transição HIGH->LOW válida
    logic frame_valid;       // Flag indicando se o frame é válido
    
    // Triple-flop para evitar metastabilidade
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rx_data_r1 <= 1'b1;
            rx_data_r2 <= 1'b1;
            rx_data_r3 <= 1'b1;
        end else begin
            rx_data_r1 <= i_rx_serial;
            rx_data_r2 <= rx_data_r1;
            rx_data_r3 <= rx_data_r2;
        end
    end
    
    // Majority vote filter (reduz ruído)
    always_comb begin
        rx_filtered = (rx_data_r1 & rx_data_r2) | 
                      (rx_data_r2 & rx_data_r3) | 
                      (rx_data_r1 & rx_data_r3);
    end
    
    // Máquina de estados - Recepção UART
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state              <= IDLE;
            o_rx_dv            <= 1'b0;
            o_rx_byte          <= '0;
            clk_count          <= '0;
            bit_index          <= '0;
            rx_byte            <= '0;
            rx_line_was_high   <= 1'b1;
            frame_valid        <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    o_rx_dv           <= 1'b0;
                    clk_count         <= '0;
                    bit_index         <= '0;
                    frame_valid       <= 1'b1;  // Assume válido até provar contrário
                    
                    // Rastreia se a linha está em HIGH
                    if (rx_filtered == 1'b1) begin
                        rx_line_was_high <= 1'b1;
                    end
                    
                    // Detecta start bit APENAS após linha ter estado em HIGH
                    // Isso garante transição HIGH -> LOW válida
                    if (rx_filtered == 1'b0 && rx_line_was_high) begin
                        state <= START_BIT;
                        rx_line_was_high <= 1'b0;
                    end
                end
                
                START_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                        
                        // VALIDAÇÃO: Checa se start bit AINDA está em LOW no MEIO
                        if (clk_count == (CLKS_PER_BIT / 2)) begin
                            if (rx_filtered != 1'b0) begin
                                // Start bit inválido - marca frame como inválido
                                frame_valid <= 1'b0;
                            end
                        end
                    end else begin
                        clk_count <= '0;
                        // SEMPRE vai para DATA_BITS, mesmo se start bit foi inválido
                        state <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                        
                        // AMOSTRA LIGEIRAMENTE ANTES DO MEIO (compensação de delay)
                        // Em vez de CLKS_PER_BIT/2, usa (CLKS_PER_BIT/2 - 4)
                        if (clk_count == ((CLKS_PER_BIT / 2) - 4)) begin
                            rx_byte[bit_index] <= rx_filtered;
                        end
                    end else begin
                        clk_count <= '0;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= '0;
                            state     <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                        
                        // VALIDAÇÃO: Checa stop bit no meio do período
                        if (clk_count == (CLKS_PER_BIT / 2)) begin
                            // Só aceita se frame_valid E stop bit correto
                            if (frame_valid && rx_filtered == 1'b1) begin
                                // Frame completo e válido
                                o_rx_dv   <= 1'b1;
                                o_rx_byte <= rx_byte;
                            end else begin
                                // Frame inválido - descarta silenciosamente
                                o_rx_dv <= 1'b0;
                            end
                        end
                    end else begin
                        clk_count <= '0;
                        state     <= CLEANUP;
                    end
                end
                
                CLEANUP: begin
                    state   <= WAIT_IDLE;
                    o_rx_dv <= 1'b0;
                end
                
                WAIT_IDLE: begin
                    // Aguarda linha voltar a HIGH (idle) antes de aceitar novo start bit
                    if (rx_filtered == 1'b1) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

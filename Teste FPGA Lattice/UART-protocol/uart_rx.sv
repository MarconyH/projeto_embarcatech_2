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
        CLEANUP      = 3'b100
    } state_t;
    
    state_t state;
    
    // Registradores para metastabilidade (double-flop)
    logic rx_data_r1, rx_data_r2;
    
    // Registradores internos
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] rx_byte;
    
    // Double-flop para evitar metastabilidade
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rx_data_r1 <= 1'b1;
            rx_data_r2 <= 1'b1;
        end else begin
            rx_data_r1 <= i_rx_serial;
            rx_data_r2 <= rx_data_r1;
        end
    end
    
    // Máquina de estados - Recepção UART
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state     <= IDLE;
            o_rx_dv   <= 1'b0;
            o_rx_byte <= '0;
            clk_count <= '0;
            bit_index <= '0;
            rx_byte   <= '0;
        end else begin
            case (state)
                IDLE: begin
                    o_rx_dv   <= 1'b0;
                    clk_count <= '0;
                    bit_index <= '0;
                    
                    // Detecta start bit (transição HIGH -> LOW)
                    if (rx_data_r2 == 1'b0) begin
                        state <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    // Amostra no meio do start bit para validar
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx_data_r2 == 1'b0) begin
                            // Start bit válido
                            clk_count <= '0;
                            state     <= DATA_BITS;
                        end else begin
                            // Falso start bit (ruído)
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        
                        // Amostra o bit no meio do período
                        rx_byte[bit_index] <= rx_data_r2;
                        
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
                    end else begin
                        clk_count <= '0;
                        o_rx_dv   <= 1'b1;     // Sinaliza dado válido
                        o_rx_byte <= rx_byte;  // Disponibiliza byte recebido
                        state     <= CLEANUP;
                    end
                end
                
                CLEANUP: begin
                    state   <= IDLE;
                    o_rx_dv <= 1'b0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

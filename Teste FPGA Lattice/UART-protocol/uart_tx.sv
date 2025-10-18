// uart_tx.sv
// UART Transmitter Module - SystemVerilog
// Otimizado para comunicação FPGA <-> Raspberry Pi Pico
//
// Configuração padrão: 115200 baud, 8N1 (8 bits, No parity, 1 stop bit)
// Clock: 50 MHz
// CLKS_PER_BIT = 50_000_000 / 115200 = 434 (aproximadamente)

module uart_tx #(
    parameter CLKS_PER_BIT = 434,  // Para 115200 baud @ 50MHz
    parameter CLK_FREQ_HZ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic       i_clk,        // Clock do sistema
    input  logic       i_rst_n,      // Reset assíncrono ativo baixo
    input  logic       i_tx_dv,      // Data Valid: pulso para iniciar transmissão
    input  logic [7:0] i_tx_byte,    // Byte a ser transmitido
    
    output logic       o_tx_serial,  // Sinal UART TX (conectar ao Pico RX)
    output logic       o_tx_active,  // '1' quando transmitindo
    output logic       o_tx_done     // Pulso quando termina transmissão
);

    // Estados da máquina de estados
    typedef enum logic [2:0] {
        IDLE         = 3'b000,
        START_BIT    = 3'b001,
        DATA_BITS    = 3'b010,
        STOP_BIT     = 3'b011,
        CLEANUP      = 3'b100
    } state_t;
    
    state_t state, next_state;
    
    // Registradores internos
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] tx_data;
    
    // Máquina de estados - Lógica sequencial
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state       <= IDLE;
            o_tx_serial <= 1'b1;  // UART idle é HIGH
            o_tx_active <= 1'b0;
            o_tx_done   <= 1'b0;
            clk_count   <= '0;
            bit_index   <= '0;
            tx_data     <= '0;
        end else begin
            case (state)
                IDLE: begin
                    o_tx_serial <= 1'b1;  // Linha idle em HIGH
                    o_tx_done   <= 1'b0;
                    o_tx_active <= 1'b0;
                    clk_count   <= '0;
                    bit_index   <= '0;
                    
                    if (i_tx_dv) begin
                        tx_data     <= i_tx_byte;
                        o_tx_active <= 1'b1;
                        state       <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    o_tx_serial <= 1'b0;  // Start bit = 0
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= '0;
                        state     <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    o_tx_serial <= tx_data[bit_index];
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
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
                    o_tx_serial <= 1'b1;  // Stop bit = 1
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count   <= '0;
                        o_tx_done   <= 1'b1;
                        o_tx_active <= 1'b0;
                        state       <= CLEANUP;
                    end
                end
                
                CLEANUP: begin
                    o_tx_done <= 1'b1;
                    state     <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

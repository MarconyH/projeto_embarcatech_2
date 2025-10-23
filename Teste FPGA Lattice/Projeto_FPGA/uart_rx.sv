// uart_rx.sv

module uart_rx #(
    parameter CLKS_PER_BIT = 217
) (
    input  logic       i_clk,        
    input  logic       i_rst_n,      
    input  logic       i_rx_serial,  
    
    output logic       o_rx_dv,      
    output logic [7:0] o_rx_byte     
);

    // Estados da máquina de estados
    typedef enum logic [2:0] {
        IDLE, START_BIT, DATA_BITS, STOP_BIT, CLEANUP
    } state_t;
    
    state_t state;
    
    // Registradores para metastabilidade (double-flop)
    logic rx_data_r1, rx_data_r2;
    
    // Registradores internos
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] rx_byte_reg;
    
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
    
    assign o_rx_byte = rx_byte_reg;
    
    // Máquina de estados - Recepção UART
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state     <= IDLE;
            o_rx_dv   <= 1'b0;
            rx_byte_reg <= '0;
            clk_count <= '0;
            bit_index <= '0;
        end else begin
            o_rx_dv <= 1'b0;
            
            case (state)
                IDLE: begin
                    clk_count <= '0;
                    bit_index <= '0;
                    
                    // Detecta start bit (transição HIGH -> LOW)
                    if (rx_data_r2 == 1'b0) begin
                        // Pula para o meio do start bit
                        clk_count <= (CLKS_PER_BIT - 1) / 2;
                        state <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    // Amostra no meio do start bit
                    if (clk_count == 0) begin
                        if (rx_data_r2 == 1'b0) begin
                            // Start bit válido - Começa a contar para o 1º bit de dado
                            clk_count <= CLKS_PER_BIT - 1;
                            state <= DATA_BITS;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count - 1'b1;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_count == 0) begin
                        clk_count <= CLKS_PER_BIT - 1;
                        
                        // Amostra o bit no meio do período
                        rx_byte_reg[bit_index] <= rx_data_r2; // LSB first
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= '0;
                            state <= STOP_BIT;
                        end
                    end else begin
                        clk_count <= clk_count - 1'b1;
                    end
                end
                
                STOP_BIT: begin
                    if (clk_count == 0) begin
                        if (rx_data_r2 == 1'b1) begin
                            o_rx_dv <= 1'b1; // Sinaliza dado válido
                        end
                        state <= CLEANUP;
                    end else begin
                        clk_count <= clk_count - 1'b1;
                    end
                end
                
                CLEANUP: begin
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
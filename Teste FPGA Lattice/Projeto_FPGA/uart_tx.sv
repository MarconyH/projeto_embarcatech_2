// uart_tx.sv 

module uart_tx #(
    parameter CLKS_PER_BIT = 217 // Valor passado pelo Top
) (
    input  logic       i_clk,        
    input  logic       i_rst_n,      
    input  logic       i_tx_dv,      
    input  logic [7:0] i_tx_byte,    
    
    output logic       o_tx_serial,  
    output logic       o_tx_active,  
    output logic       o_tx_done     
);

    // Estados da máquina de estados
    typedef enum logic [3:0] {
        IDLE, START_BIT, DATA_BITS, STOP_BIT
    } state_t;
    
    state_t state;
    
    // Registradores internos
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] tx_data;
    
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state       <= IDLE;
            o_tx_serial <= 1'b1;  
            o_tx_active <= 1'b0;
            o_tx_done   <= 1'b0;
            clk_count   <= '0;
            bit_index   <= '0;
        end else begin
            o_tx_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    o_tx_serial <= 1'b1;
                    if (i_tx_dv) begin
                        tx_data     <= i_tx_byte;
                        o_tx_active <= 1'b1;
                        clk_count   <= CLKS_PER_BIT - 1;
                        state       <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    o_tx_serial <= 1'b0;
                    if (clk_count == 0) begin
                        clk_count <= CLKS_PER_BIT - 1;
                        bit_index <= 0;
                        state     <= DATA_BITS;
                    end else begin
                        clk_count <= clk_count - 1'b1;
                    end
                end
                
                DATA_BITS: begin
                    o_tx_serial <= tx_data[bit_index];
                    if (clk_count == 0) begin
                        if (bit_index == 7) begin
                            clk_count <= CLKS_PER_BIT - 1;
                            state     <= STOP_BIT;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            clk_count <= CLKS_PER_BIT - 1;
                        end
                    end else begin
                        clk_count <= clk_count - 1'b1;
                    end
                end
                
                STOP_BIT: begin
                    o_tx_serial <= 1'b1;
                    if (clk_count == 0) begin
                        o_tx_done   <= 1'b1;
                        o_tx_active <= 1'b0;
                        state       <= IDLE;
                    end else begin
                        clk_count <= clk_count - 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
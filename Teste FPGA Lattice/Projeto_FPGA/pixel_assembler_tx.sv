// pixel_assembler_tx.sv
// Gerencia a serialização de line_rho (32bit) e line_theta (32bit) em 8 bytes.

module pixel_assembler_tx (
    input  logic clk,
    input  logic reset,
    
    // Dados de entrada (Resultado Hough)
    input  int line_rho,
    input  int line_theta,
    
    // Controle
    input  logic tx_request,  // Pulso para iniciar a sequência de TX
    input  logic tx_busy,     // Da UART TX
    
    // Saída para UART TX
    output logic [7:0] tx_data_out,
    output logic tx_start_out,
    output logic tx_done_seq
);

    localparam int NUM_BYTES = 8; // 4 bytes (rho) + 4 bytes (theta)
    
    typedef enum logic [3:0] {
        IDLE, BYTE0, BYTE1, BYTE2, BYTE3, BYTE4, BYTE5, BYTE6, BYTE7, DONE
    } tx_seq_state_t;
    tx_seq_state_t tx_seq_state;
    
    logic [7:0] data_to_send;
    
    // Concatena Rho e Theta (64 bits total)
    logic [63:0] result_packet;
    assign result_packet = {line_rho, line_theta}; // Assume 32 bits por int

    always_comb begin
        // Default: LSB first (Rho LSB -> Rho MSB -> Theta LSB -> Theta MSB)
        case (tx_seq_state)
            BYTE0: data_to_send = result_packet[7:0];   // Rho LSB
            BYTE1: data_to_send = result_packet[15:8];
            BYTE2: data_to_send = result_packet[23:16];
            BYTE3: data_to_send = result_packet[31:24]; // Rho MSB
            BYTE4: data_to_send = result_packet[39:32]; // Theta LSB
            BYTE5: data_to_send = result_packet[47:40];
            BYTE6: data_to_send = result_packet[55:48];
            BYTE7: data_to_send = result_packet[63:56]; // Theta MSB
            default: data_to_send = 8'h00;
        endcase
    end
    
    assign tx_data_out = data_to_send;
    assign tx_done_seq = (tx_seq_state == DONE);
    
    // FSM para sequência de transmissão de 8 bytes
    always_ff @(posedge clk) begin
        if (reset) begin
            tx_seq_state <= IDLE;
            tx_start_out <= 0;
        end else begin
            tx_start_out <= 0;
            
            case (tx_seq_state)
                IDLE: begin
                    if (tx_request) begin
                        tx_seq_state <= BYTE0;
                        tx_start_out <= 1; // Inicia a TX do Byte 0
                    end
                end
                
                BYTE0, BYTE1, BYTE2, BYTE3, BYTE4, BYTE5, BYTE6: begin
                    // Espera o byte atual terminar (tx_busy cair)
                    if (!tx_busy) begin
                        tx_start_out <= 1;
                        tx_seq_state <= tx_seq_state + 1;
                    end
                end
                
                BYTE7: begin
                    if (!tx_busy) begin
                        tx_seq_state <= DONE;
                    end
                end
                
                DONE: tx_seq_state <= IDLE;
            endcase
        end
    end

endmodule
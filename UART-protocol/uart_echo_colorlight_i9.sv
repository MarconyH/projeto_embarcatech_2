module uart_echo_colorlight_i9 #(
    parameter clk_freq = 25_000_000,
    parameter baud_rate = 9600,
    parameter IMG_SIZE = 16,           // Imagem 16x16
    parameter MAX_LINES = 4            // Máximo de linhas detectadas
)(
    input  logic       clk,
    input  logic       reset_n,
    input  logic       uart_rx,
    output logic       uart_tx
);

    // `define TESTE_TX_MANUAL

    logic       rx_dv;
    logic [7:0] rx_byte;      
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active, tx_done;
    
    // Sinais da Transformada de Hough
    logic        hough_start;
    logic        hough_done;
    logic        hough_busy;
    logic        hough_wr_en;
    logic [7:0]  hough_wr_addr;
    logic [7:0]  hough_wr_data;
    logic [7:0]  hough_num_lines;
    
    // Sinais flat para as linhas detectadas
    logic [7:0]  hough_line_rho_0, hough_line_rho_1, hough_line_rho_2, hough_line_rho_3;
    logic [7:0]  hough_line_theta_0, hough_line_theta_1, hough_line_theta_2, hough_line_theta_3;
    logic [7:0]  hough_line_votes_0, hough_line_votes_1, hough_line_votes_2, hough_line_votes_3;
    
    // Arrays locais para facilitar acesso
    logic [7:0]  hough_line_rho   [0:MAX_LINES-1];
    logic [7:0]  hough_line_theta [0:MAX_LINES-1];
    logic [7:0]  hough_line_votes [0:MAX_LINES-1];
    
    // Mapeamento dos sinais flat para arrays
    assign hough_line_rho[0]   = hough_line_rho_0;
    assign hough_line_rho[1]   = hough_line_rho_1;
    assign hough_line_rho[2]   = hough_line_rho_2;
    assign hough_line_rho[3]   = hough_line_rho_3;
    assign hough_line_theta[0] = hough_line_theta_0;
    assign hough_line_theta[1] = hough_line_theta_1;
    assign hough_line_theta[2] = hough_line_theta_2;
    assign hough_line_theta[3] = hough_line_theta_3;
    assign hough_line_votes[0] = hough_line_votes_0;
    assign hough_line_votes[1] = hough_line_votes_1;
    assign hough_line_votes[2] = hough_line_votes_2;
    assign hough_line_votes[3] = hough_line_votes_3;
    
    uart_top #(
        .CLK_FREQ_HZ(clk_freq),
        .BAUD_RATE(baud_rate)

    ) uart_inst (
        .i_clk(clk),
        .i_rst_n(reset_n),
        .i_uart_rx(uart_rx),
        .o_uart_tx(uart_tx),
        .i_tx_dv(tx_dv),
        .i_tx_byte(tx_byte),
        .o_tx_active(tx_active),
        .o_tx_done(tx_done),
        .o_rx_dv(rx_dv),
        .o_rx_byte(rx_byte)
    );
    
    // Instancia Transformada de Hough
    hough_transform #(
        .IMG_SIZE(IMG_SIZE),
        .RHO_BINS(16),      // Redução agressiva: 64 → 16 (1 pixel por bin)
        .THETA_BINS(16),    // Redução agressiva: 90 → 16 (~11° por bin)
        .MAX_LINES(MAX_LINES)
    ) hough_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(hough_start),
        .done(hough_done),
        .busy(hough_busy),
        .wr_en(hough_wr_en),
        .wr_addr(hough_wr_addr),
        .wr_data(hough_wr_data),
        .num_lines(hough_num_lines),
        .line_rho_0(hough_line_rho_0),
        .line_theta_0(hough_line_theta_0),
        .line_votes_0(hough_line_votes_0),
        .line_rho_1(hough_line_rho_1),
        .line_theta_1(hough_line_theta_1),
        .line_votes_1(hough_line_votes_1),
        .line_rho_2(hough_line_rho_2),
        .line_theta_2(hough_line_theta_2),
        .line_votes_2(hough_line_votes_2),
        .line_rho_3(hough_line_rho_3),
        .line_theta_3(hough_line_theta_3),
        .line_votes_3(hough_line_votes_3)
    );
    
`ifdef TESTE_TX_MANUAL
    logic [31:0] timer_counter;
    logic [7:0]  test_char;
    localparam TIMER_500MS = 25_000_000 / 2;
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            timer_counter <= 32'd0;
            test_char <= 8'd65;
            tx_dv <= 1'b0;
            tx_byte <= 8'h00;
        end else begin
            tx_dv <= 1'b0;
            if (timer_counter < TIMER_500MS) begin
                timer_counter <= timer_counter + 1'b1;
            end else begin
                timer_counter <= 32'd0;
                if (!tx_active) begin
                    tx_dv <= 1'b1;
                    tx_byte <= test_char;
                    if (test_char < 8'd90) begin
                        test_char <= test_char + 1'b1;
                    end else begin
                        test_char <= 8'd65;
                    end
                end
            end
        end
    end
    
`else
    // ========== FSM PRINCIPAL: RECEBER IMAGEM -> HOUGH -> ENVIAR RESULTADO ==========
    localparam HEADER_BYTE = 8'hAA;
    localparam IMG_BYTES = (IMG_SIZE * IMG_SIZE) / 8;  // 16x16 = 256 bits = 32 bytes
    
    typedef enum logic [2:0] {
        WAIT_HEADER,        // Aguarda header de sincronização
        RECV_IMAGE,         // Recebe 32 bytes da imagem
        PROCESS_HOUGH,      // Executa Transformada de Hough
        SEND_NUM_LINES,     // Envia número de linhas detectadas
        SEND_LINE_DATA,     // Envia dados de cada linha (ρ, θ, votes)
        CLEANUP             // Estado de limpeza
    } state_t;
    
    state_t state;
    logic [7:0] recv_count;     // Contador de bytes recebidos (0..31)
    logic [2:0] send_line_idx;  // Índice da linha sendo enviada
    logic [1:0] send_byte_idx;  // Índice do byte dentro da linha (0=ρ, 1=θ, 2=votes)
    logic       prev_tx_done;
    logic       tx_done_rising;
    
    // Detecção de borda ascendente de tx_done
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            prev_tx_done <= 1'b0;
        end else begin
            prev_tx_done <= tx_done;
        end
    end
    assign tx_done_rising = tx_done && !prev_tx_done;

    // FSM Principal
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= WAIT_HEADER;
            tx_dv <= 1'b0;
            tx_byte <= 8'h00;
            recv_count <= 8'd0;
            send_line_idx <= 3'd0;
            send_byte_idx <= 2'd0;
            hough_start <= 1'b0;
            hough_wr_en <= 1'b0;
            hough_wr_addr <= 8'd0;
            hough_wr_data <= 8'd0;
            
        end else begin
            // Defaults
            tx_dv <= 1'b0;
            hough_start <= 1'b0;
            hough_wr_en <= 1'b0;

            case (state)
                WAIT_HEADER: begin
                    // Aguarda header (0xAA)
                    hough_wr_en <= 1'b0;
                    if (rx_dv && rx_byte == HEADER_BYTE) begin
`ifdef SIMULATION
                        $display("[HEADER] Detectado header 0xAA, mudando para RECV_IMAGE");
`endif
                        recv_count <= 8'd0;
                        state <= RECV_IMAGE;
                    end
                end
                
                RECV_IMAGE: begin
                    // Recebe 32 bytes da imagem e armazena no módulo Hough
                    if (rx_dv) begin
`ifdef SIMULATION
                        $display("[UART_RX] rx_dv PULSE! Byte %0d = 0x%02h (recv_count=%0d)", recv_count, rx_byte, recv_count);
`endif
                        // Escreve byte na memória do Hough
                        hough_wr_en <= 1'b1;
                        hough_wr_addr <= recv_count;
                        hough_wr_data <= rx_byte;
                        
                        if (recv_count < IMG_BYTES - 1) begin
                            recv_count <= recv_count + 1'b1;
                        end else begin
                            // Recebeu toda a imagem
                            hough_wr_en <= 1'b0;
                            recv_count <= 8'd0;
                            state <= PROCESS_HOUGH;
                        end
                    end else begin
                        hough_wr_en <= 1'b0;
                    end
                end
                
                PROCESS_HOUGH: begin
                    // Inicia processamento da Transformada de Hough
                    if (!hough_busy) begin
                        hough_start <= 1'b1;
                        state <= PROCESS_HOUGH;  // Permanece aqui até done
                    end
                    
                    // Aguarda conclusão
                    if (hough_done) begin
                        hough_start <= 1'b0;  // Limpa start antes de prosseguir
                        send_line_idx <= 3'd0;
                        send_byte_idx <= 2'd0;
                        state <= SEND_NUM_LINES;
                    end
                end
                
                SEND_NUM_LINES: begin
                    // Envia número de linhas detectadas
                    if (!tx_active) begin
                        tx_dv <= 1'b1;
                        tx_byte <= hough_num_lines;
                    end else begin
                        tx_dv <= 1'b0;  // Zera tx_dv após iniciar transmissão
                    end
                    
                    if (tx_done_rising) begin
                        tx_dv <= 1'b0;  // Garante que está zerado
                        if (hough_num_lines > 0) begin
                            state <= SEND_LINE_DATA;
                        end else begin
                            state <= CLEANUP;
                        end
                    end
                end
                
                SEND_LINE_DATA: begin
                    // Envia dados de cada linha: [ρ] [θ] [votes]
                    if (!tx_active && send_line_idx < hough_num_lines[2:0]) begin
                        case (send_byte_idx)
                            2'd0: tx_byte <= hough_line_rho[send_line_idx];
                            2'd1: tx_byte <= hough_line_theta[send_line_idx];
                            2'd2: tx_byte <= hough_line_votes[send_line_idx];
                            default: tx_byte <= 8'h00;
                        endcase
                        tx_dv <= 1'b1;
                    end else begin
                        tx_dv <= 1'b0;  // Zera tx_dv após iniciar transmissão
                    end
                    
                    if (tx_done_rising) begin
                        tx_dv <= 1'b0;  // Garante que está zerado
                        if (send_byte_idx < 2'd2) begin
                            send_byte_idx <= send_byte_idx + 1'b1;
                        end else begin
                            send_byte_idx <= 2'd0;
                            if (send_line_idx < hough_num_lines[2:0] - 1) begin
                                send_line_idx <= send_line_idx + 1'b1;
                            end else begin
                                state <= CLEANUP;
                            end
                        end
                    end
                end
                
                CLEANUP: begin
                    // Volta ao estado inicial
                    state <= WAIT_HEADER;
                end
                
                default: state <= WAIT_HEADER;
            endcase
        end
    end
`endif

endmodule
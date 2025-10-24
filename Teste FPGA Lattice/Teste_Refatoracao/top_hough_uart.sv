// Top level: Implementação de Hough/Sobel via comunicação UART (Colorlight i9)
// Comunicação: 115200 baud @ 25 MHz CLK

module top_hough_uart (
    input  logic clk,             // P3, 25 MHz
    input  logic I3_RESET,        // C2 (Reset)
    input  logic I1_START,        // D1 (UART RX)
    output logic O1_M1,           // E2 (UART TX)
    output logic [2:0] led        // LEDS de status
);

    // --- Parâmetros ---
    localparam int IMG_WIDTH    = 1280;
    localparam int IMG_HEIGHT   = 720;
    localparam int PIXEL_BITS   = 24;
    localparam int MEM_DEPTH    = IMG_WIDTH * IMG_HEIGHT;
    localparam int ADDR_WIDTH   = $clog2(MEM_DEPTH);
    localparam int BAUD_RATE    = 115200;
    localparam int CLK_FREQ     = 25000000;
    
    // Conversores de Pinos
    logic reset;
    assign reset = I3_RESET; 
    logic pico_tx = I1_START; 
    logic fpga_tx;
    assign O1_M1 = fpga_tx; 
    
    // --- Sinais UART ---
    logic [7:0] rx_byte;
    logic rx_valid;
    logic rx_busy;
    logic [7:0] tx_byte;
    logic tx_start;
    logic tx_busy;
    logic tx_done_seq; // Fim da sequência de 8 bytes (Rho + Theta)

    // --- Frame Buffer Control ---
    logic [ADDR_WIDTH-1:0] fb_wr_addr;
    logic [PIXEL_BITS-1:0] fb_wr_data;
    logic fb_wr_en;
    logic [ADDR_WIDTH-1:0] fb_rd_addr;
    logic [PIXEL_BITS-1:0] fb_rd_data;
    
    // --- Sobel/Hough Signals ---
    logic sobel_output_edge;
    int x_coord_proc, y_coord_proc;
    int line_rho;
    int line_theta;
    logic line_detected;
    
    // --- RX Buffer ---
    logic [1:0] byte_cnt; 
    logic [23:0] pixel_assembler;

    // --- FSM Control ---
    typedef enum logic [2:0] {
        IDLE,             
        RECEIVING_FRAME,  
        PROCESSING,       
        TRANSMITTING_RESULTS 
    } state_t;
    state_t state;
    
    int pixel_cnt_rx; 
    int pixel_cnt_proc;
    
    // =======================================================
    // INSTANCIAS
    // =======================================================
    
    // 1. UART TOP (RX e TX)
    uart_top #(
        .CLK_FREQ_HZ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)
    ) uart_top_inst (
        .i_clk(clk), .i_rst_n(~reset), 
        .i_uart_rx(pico_tx), .o_uart_tx(fpga_tx),
        .i_tx_dv(tx_start), .i_tx_byte(tx_byte),
        .o_tx_active(), .o_tx_done(tx_busy), // tx_done aqui é usado para tx_busy/wait
        .o_rx_dv(rx_valid), .o_rx_byte(rx_byte)
    );

    // 2. Frame Buffer
    frame_buffer_24bit #(
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT)
    ) fb_inst (
        .clk(clk), .reset(reset), 
        .wr_addr(fb_wr_addr), .wr_data(fb_wr_data), .wr_en(fb_wr_en),
        .rd_addr(fb_rd_addr), .rd_data(fb_rd_data) 
    );
    
    // 3. Sobel Processor
    sobel_processor sobel_inst (
        .clk(clk), .reset(reset),
        .x_center(x_coord_proc), .y_center(y_coord_proc),
        .bram_rd_addr(fb_rd_addr), .bram_rd_data(fb_rd_data),
        .edge_detected(sobel_output_edge)
    );
    
    // 4. Hough Tracker
    hough_tracker hough_inst (
        .clk(clk), .reset(reset),
        // Simulação dos sinais de vídeo para o tracker
        .vs_in(state == PROCESSING), 
        .de_in(state == PROCESSING),
        .edge_detected(sobel_output_edge),
        .x_coord(x_coord_proc),
        .y_coord(y_coord_proc),
        .processing(),
        .line_detected(line_detected),
        .line_rho(line_rho),
        .line_theta(line_theta)
    );

    // 5. Serializador de Resultados TX
    pixel_assembler_tx tx_asm_inst (
        .clk(clk), .reset(reset),
        .line_rho(line_rho),
        .line_theta(line_theta),
        .tx_request(tx_request_start), // Pulso interno
        .tx_busy(tx_busy),
        .tx_data_out(tx_byte),
        .tx_start_out(tx_start),
        .tx_done_seq(tx_done_seq)
    );
    
    // Sinal interno para iniciar sequência TX
    logic tx_request_start;
    
    // =======================================================
    // FSM e Controle de Dados
    // =======================================================
    
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            fb_wr_en <= 0;
            byte_cnt <= 0;
            pixel_cnt_rx <= 0;
            pixel_cnt_proc <= 0;
            tx_request_start <= 0;
            led <= 3'b000;
        end else begin
            
            tx_request_start <= 0;
            
            case (state)
                IDLE: begin
                    // Espera pelo primeiro byte para iniciar
                    if (rx_valid) begin 
                        state <= RECEIVING_FRAME;
                        pixel_cnt_rx <= 0;
                        fb_wr_addr <= 0;
                        byte_cnt <= 0;
                        led <= 3'b001; // LED 1: RX Ativo
                    end
                end

                RECEIVING_FRAME: begin
                    fb_wr_en <= 0; 

                    if (rx_valid) begin
                        // 1. Montagem do Pixel (3 bytes)
                        case (byte_cnt)
                            2'b00: pixel_assembler[7:0]  <= rx_byte; // B
                            2'b01: pixel_assembler[15:8] <= rx_byte; // G
                            2'b10: begin
                                pixel_assembler[23:16] <= rx_byte; // R
                                // 2. Escrita na BRAM
                                fb_wr_data <= pixel_assembler;
                                fb_wr_en <= 1;
                                fb_wr_addr <= fb_wr_addr + 1; 
                                
                                pixel_cnt_rx <= pixel_cnt_rx + 1;
                            end
                        endcase
                        byte_cnt <= byte_cnt + 1;

                        // 3. Transição de Estado
                        if (pixel_cnt_rx == (MEM_DEPTH - 1)) begin
                            state <= PROCESSING;
                            pixel_cnt_proc <= 0;
                            x_coord_proc <= -2; // Inicializa fora da borda Sobel
                            y_coord_proc <= -2; 
                            fb_wr_en <= 0;
                            led <= 3'b010; // LED 2: Processando
                        end
                    end
                end

                PROCESSING: begin
                    // 1. Avança 1 pixel por ciclo. Sobel e Hough rodam em pipeline.
                    if (pixel_cnt_proc < MEM_DEPTH) begin
                        pixel_cnt_proc <= pixel_cnt_proc + 1;
                        
                        // Atualiza (x, y) para o Sobel Processor e Hough Tracker
                        if (x_coord_proc < IMG_WIDTH - 1) begin
                            x_coord_proc <= x_coord_proc + 1;
                        end else begin
                            x_coord_proc <= 0;
                            y_coord_proc <= y_coord_proc + 1;
                        end
                    end else begin
                        // Processamento concluído
                        state <= TRANSMITTING_RESULTS;
                        tx_request_start <= 1; // Inicia a serialização dos resultados
                        led <= 3'b100; // LED 3: TX Ativo
                    end
                end
                
                TRANSMITTING_RESULTS: begin
                    // Espera a sequência de 8 bytes terminar
                    if (tx_done_seq) begin
                        state <= IDLE;
                        led <= 3'b000;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
    
endmodule
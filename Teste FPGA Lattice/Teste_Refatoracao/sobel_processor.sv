// Gerencia a leitura de 9 pixels da BRAM, aplica Sobel e gera a borda.

module sobel_processor #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720,
    parameter PIXEL_BITS = 24,
    parameter ADDR_WIDTH = 20
) (
    input  logic clk,
    input  logic reset,
    
    // Coordenadas do Pixel Central
    input  int x_center,
    input  int y_center,
    
    // BRAM Interface (Usa o parâmetro ADDR_WIDTH)
    output logic [ADDR_WIDTH-1:0] bram_rd_addr,
    input  logic [PIXEL_BITS-1:0] bram_rd_data,
    
    // Saída do Sobel
    output logic edge_detected
);
    
    // Buffer para 9 pixels (3x3)
    logic [PIXEL_BITS-1:0] pixel_matrix [8:0]; // 0=LT, 4=CC, 8=RB
    
    // FSM para leitura sequencial dos 9 endereços na BRAM
    typedef enum logic [3:0] { 
        READ_P0, READ_P1, READ_P2, READ_P3, READ_P4, 
        READ_P5, READ_P6, READ_P7, READ_P8, CALC
    } read_state_t;
    read_state_t read_state;
    
    // Sobel G^2
    logic [27:0] g_x_2, g_y_2;
    logic [12:0] g_sum_2_limited;
    logic [7:0] lum_new; // Resultado da SQRT/ROM
    
    // --- Gerador de Endereços 3x3 ---
    // Mapeamento 3x3 para endereço linear
    function automatic [ADDR_WIDTH-1:0] get_addr;
        input int x;
        input int y;
        input int x_offset;
        input int y_offset;
        
        // Tipos internos
        integer final_x;
        integer final_y;
        integer linear_addr;
        
        // 1. Cálculo com offsets
        final_x = x + x_offset;
        final_y = y + y_offset;

        // 2. Clamp bounds
        if (final_x < 0) final_x = 0;
        if (final_x >= IMG_WIDTH) final_x = IMG_WIDTH - 1;
        if (final_y < 0) final_y = 0;
        if (final_y >= IMG_HEIGHT) final_y = IMG_HEIGHT - 1;
        
        // 3. Cálculo do Endereço Linear
        linear_addr = (final_y * IMG_WIDTH) + final_x;
        
        // 4. Atribuição de Retorno (usando o nome da função)
        get_addr = linear_addr;
    endfunction
    
    // Endereço de leitura atual (calculado na transição de estado)
    always_comb begin
        case (read_state)
            READ_P0: bram_rd_addr = get_addr(x_center, y_center, -1, -1); // LT
            READ_P1: bram_rd_addr = get_addr(x_center, y_center, 0, -1);  // CT
            READ_P2: bram_rd_addr = get_addr(x_center, y_center, 1, -1);  // RT
            READ_P3: bram_rd_addr = get_addr(x_center, y_center, -1, 0);  // LC
            READ_P4: bram_rd_addr = get_addr(x_center, y_center, 0, 0);   // CC (Pixel Central)
            READ_P5: bram_rd_addr = get_addr(x_center, y_center, 1, 0);   // RC
            READ_P6: bram_rd_addr = get_addr(x_center, y_center, -1, 1);  // LB
            READ_P7: bram_rd_addr = get_addr(x_center, y_center, 0, 1);   // CB
            READ_P8: bram_rd_addr = get_addr(x_center, y_center, 1, 1);  // RB
            default: bram_rd_addr = 0;
        endcase
    end
    
    // FSM de Leitura Sequencial
    always_ff @(posedge clk) begin
        if (reset) begin
            read_state <= READ_P0;
            edge_detected <= 0;
        end else begin
            case (read_state)
                READ_P0, READ_P1, READ_P2, READ_P3, READ_P4, 
                READ_P5, READ_P6, READ_P7: begin
                    // Armazena o pixel lido (com 1 ciclo de latência da BRAM)
                    pixel_matrix[read_state] <= bram_rd_data;
                    read_state <= read_state + 1;
                end
                
                READ_P8: begin
                    pixel_matrix[read_state] <= bram_rd_data;
                    read_state <= CALC;
                end
                
                CALC: begin
                    // Processamento Sobel pipeline começa
                    read_state <= READ_P0; // Prepara para o próximo (x,y)
                    // ... A lógica Sobel é executada em pipeline nos próximos ciclos
                end
            endcase
        end
    end
    
    // --- INSTANCIAS SOBEL (G_X e G_Y) ---
    // NOTA: Estes módulos G_MATRIX operam em pipeline de 2 ciclos.
    
    // Gx (Vertical Edge Detection)
    g_matrix gx_inst (
        .clk(clk), .reset(reset),
        .in_p1a(pixel_matrix[2]), .in_p2(pixel_matrix[5]), .in_p1b(pixel_matrix[8]),  // +1, +2, +1 (Right)
        .in_m1a(pixel_matrix[0]), .in_m2(pixel_matrix[3]), .in_m1b(pixel_matrix[6]),  // -1, -2, -1 (Left)
        .data_out(g_x_2)
    );
    
    // Gy (Horizontal Edge Detection)
    g_matrix gy_inst (
        .clk(clk), .reset(reset),
        .in_p1a(pixel_matrix[0]), .in_p2(pixel_matrix[1]), .in_p1b(pixel_matrix[2]),  // +1, +2, +1 (Top)
        .in_m1a(pixel_matrix[6]), .in_m2(pixel_matrix[7]), .in_m1b(pixel_matrix[8]),  // -1, -2, -1 (Bottom)
        .data_out(g_y_2)
    );
    
    // --- Soma, Limitação e SQRT ---
    logic [27:0] g_sum_2;
    
    always_ff @(posedge clk) begin
        // Estágio de Soma G^2 = Gx^2 + Gy^2
        g_sum_2 <= g_x_2 + g_y_2;
        
        // Limitação e Escalonamento (dividido por 8192, limitando a 8191, para 13 bits de endereço da ROM)
        if (g_sum_2 > (8191 * 8192)) begin
            g_sum_2_limited <= 13'h1FFF; // Máximo valor (8191)
        end else begin
            g_sum_2_limited <= g_sum_2 / 8192; // 13 bits (0 a 8191)
        end
    end
    
    g_root_lut sqrt_inst (
        .clk(clk),
        .address(g_sum_2_limited),
        .q(lum_new) // lum_new = 255 - sqrt(G^2)
    );

    // Detecção de Borda (Output)
    // Threshold ajustado para 128
    always_comb begin
        edge_detected = (lum_new < 8'd128); 
    end

endmodule
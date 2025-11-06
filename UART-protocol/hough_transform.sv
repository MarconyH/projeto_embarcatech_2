// hough_transform.sv
// Transformada de Hough para detecção de linhas em imagem 16x16
// Recebe matriz de bordas (1=borda, 0=fundo) e detecta linhas dominantes
//
// Algoritmo:
// 1. Para cada pixel de borda (x,y):
//    2. Para cada ângulo θ (0° a 180°, steps de 2°):
//       3. Calcula ρ = x×cos(θ) + y×sin(θ)
//       4. Incrementa accumulator[ρ][θ]
// 5. Encontra picos no acumulador (linhas detectadas)
// 6. Retorna top-N linhas como [ρ, θ, votes]

module hough_transform #(
    parameter IMG_SIZE = 16,        // Imagem 16x16
    parameter RHO_BINS = 16,        // Bins para ρ (muito reduzido!)
    parameter THETA_BINS = 16,      // Bins para θ (0° a 180°, step ~11°)
    parameter MAX_LINES = 4         // Número máximo de linhas a detectar
)(
    input  logic        clk,
    input  logic        reset_n,
    
    // Interface de controle
    input  logic        start,      // Pulso para iniciar processamento
    output logic        done,       // Pulso quando termina
    output logic        busy,       // '1' durante processamento
    
    // Matriz de entrada (1 bit por pixel: 1=borda, 0=fundo)
    // Recebida byte a byte: cada byte contém 8 pixels
    input  logic        wr_en,      // Pulso para escrever byte
    input  logic [7:0]  wr_addr,    // Endereço do byte (0..31)
    input  logic [7:0]  wr_data,    // 8 pixels empacotados
    
    // Resultado: linhas detectadas (packed arrays para compatibilidade)
    output logic [7:0]  num_lines,          // Quantidade de linhas detectadas (0..MAX_LINES)
    output logic [7:0]  line_rho_0,         // ρ da linha 0
    output logic [7:0]  line_theta_0,       // θ da linha 0
    output logic [7:0]  line_votes_0,       // votos da linha 0
    output logic [7:0]  line_rho_1,         // ρ da linha 1
    output logic [7:0]  line_theta_1,       // θ da linha 1
    output logic [7:0]  line_votes_1,       // votos da linha 1
    output logic [7:0]  line_rho_2,         // ρ da linha 2
    output logic [7:0]  line_theta_2,       // θ da linha 2
    output logic [7:0]  line_votes_2,       // votos da linha 2
    output logic [7:0]  line_rho_3,         // ρ da linha 3
    output logic [7:0]  line_theta_3,       // θ da linha 3
    output logic [7:0]  line_votes_3        // votos da linha 3
);

    // Arrays internos para manipulação
    logic [7:0] line_rho   [0:MAX_LINES-1];
    logic [7:0] line_theta [0:MAX_LINES-1];
    logic [7:0] line_votes [0:MAX_LINES-1];
    
    // Mapeamento dos arrays internos para portas flat
    assign line_rho_0   = line_rho[0];
    assign line_theta_0 = line_theta[0];
    assign line_votes_0 = line_votes[0];
    assign line_rho_1   = line_rho[1];
    assign line_theta_1 = line_theta[1];
    assign line_votes_1 = line_votes[1];
    assign line_rho_2   = line_rho[2];
    assign line_theta_2 = line_theta[2];
    assign line_votes_2 = line_votes[2];
    assign line_rho_3   = line_rho[3];
    assign line_theta_3 = line_theta[3];
    assign line_votes_3 = line_votes[3];

    // ========== MEMÓRIA DA IMAGEM ==========
    // 16x16 = 256 bits = 32 bytes
    logic [7:0] image_mem [0:31];  // 32 bytes, cada byte = 8 pixels
    
    // ========== ACUMULADOR HOUGH ==========
    // RHO_BINS x THETA_BINS = 16x16 = 256 células
    // Linearizado para inferência de BRAM
    (* ram_style = "block" *) logic [5:0] accumulator [0:255];  // 256 células linearizadas
    
    // ========== LUT SENO/COSSENO (ROM) ==========
    // Valores pré-calculados em fixed-point (16 bits, escala 256)
    // sin(θ) × 256, cos(θ) × 256 para θ = 0°, 11.25°, 22.5°, ..., 168.75° (16 valores)
    // Step: 180° / 16 = 11.25° por índice
    
    function signed [15:0] get_sin_lut;
        input integer idx;
        case (idx)
            0: get_sin_lut = 16'sd0;      // 0°
            1: get_sin_lut = 16'sd50;     // 11.25°
            2: get_sin_lut = 16'sd98;     // 22.5°
            3: get_sin_lut = 16'sd142;    // 33.75°
            4: get_sin_lut = 16'sd181;    // 45°
            5: get_sin_lut = 16'sd213;    // 56.25°
            6: get_sin_lut = 16'sd237;    // 67.5°
            7: get_sin_lut = 16'sd251;    // 78.75°
            8: get_sin_lut = 16'sd256;    // 90°
            9: get_sin_lut = 16'sd251;    // 101.25°
            10: get_sin_lut = 16'sd237;   // 112.5°
            11: get_sin_lut = 16'sd213;   // 123.75°
            12: get_sin_lut = 16'sd181;   // 135°
            13: get_sin_lut = 16'sd142;   // 146.25°
            14: get_sin_lut = 16'sd98;    // 157.5°
            15: get_sin_lut = 16'sd50;    // 168.75°
            default: get_sin_lut = 16'sd0;
        endcase
    endfunction
    
    function signed [15:0] get_cos_lut;
        input integer idx;
        case (idx)
            0: get_cos_lut = 16'sd256;    // 0°
            1: get_cos_lut = 16'sd251;    // 11.25°
            2: get_cos_lut = 16'sd237;    // 22.5°
            3: get_cos_lut = 16'sd213;    // 33.75°
            4: get_cos_lut = 16'sd181;    // 45°
            5: get_cos_lut = 16'sd142;    // 56.25°
            6: get_cos_lut = 16'sd98;     // 67.5°
            7: get_cos_lut = 16'sd50;     // 78.75°
            8: get_cos_lut = 16'sd0;      // 90°
            9: get_cos_lut = -16'sd50;    // 101.25°
            10: get_cos_lut = -16'sd98;   // 112.5°
            11: get_cos_lut = -16'sd142;  // 123.75°
            12: get_cos_lut = -16'sd181;  // 135°
            13: get_cos_lut = -16'sd213;  // 146.25°
            14: get_cos_lut = -16'sd237;  // 157.5°
            15: get_cos_lut = -16'sd251;  // 168.75°
            default: get_cos_lut = 16'sd256;
        endcase
    endfunction
    
    // ========== FSM ==========
    typedef enum logic [2:0] {
        IDLE,
        CLEAR_ACC,      // Zera acumulador
        VOTE,           // Processa pixels e vota no acumulador
        FIND_PEAKS,     // Encontra picos (linhas)
        DONE_STATE
    } state_t;
    
    state_t state;
    
    // ========== CONTADORES E REGISTRADORES ==========
    logic [7:0]  pixel_x, pixel_y;      // Coordenadas do pixel atual (0..15)
    logic [6:0]  theta_idx;             // Índice do ângulo (0..89)
    logic [15:0] clear_count;           // Contador para limpar acumulador (precisa ir até 5760)
    logic [3:0]  peak_count;            // Contador de picos encontrados
    
    // Registradores temporários para cálculo de ρ
    logic signed [15:0] rho_scaled;
    logic [5:0] rho_bin;
    logic signed [31:0] temp_prod_x, temp_prod_y, temp_sum;  // Temporários para aritmética signed
    logic signed [15:0] rho_calc;  // Resultado do cálculo combinacional
    logic [5:0] rho_bin_calc;      // Bin calculado combinacionalmente
    
    // Variáveis temporárias para cálculos
    integer byte_addr, bit_pos;
    integer clear_r, clear_t;
    integer acc_addr;  // Endereço linearizado do acumulador
    logic pixel_bit;   // Bit individual do pixel (para workaround de IVerilog)
    logic debug_printed;  // Flag para imprimir acumulador apenas 1 vez
    
    // ========== CÁLCULO DE RHO (COMBINACIONAL) ==========
    always_comb begin
        // Multiplicações e soma signed
        temp_prod_x = $signed({24'd0, pixel_x}) * $signed(get_cos_lut(theta_idx));
        temp_prod_y = $signed({24'd0, pixel_y}) * $signed(get_sin_lut(theta_idx));
        temp_sum = temp_prod_x + temp_prod_y;
        rho_calc = temp_sum / $signed(16'd256);
        
        // Saturação
        if (rho_calc < 0) begin
            rho_bin_calc = 6'd0;
        end else if (rho_calc >= 16) begin
            rho_bin_calc = 6'd15;
        end else begin
            rho_bin_calc = 6'd0 + rho_calc[5:0];  // Force 6-bit width
        end
    end
    
    // ========== ESCRITA DA IMAGEM ==========
    always_ff @(posedge clk) begin
        if (wr_en && wr_addr < 32) begin
            image_mem[wr_addr] <= wr_data;
`ifdef SIMULATION
            $display("[WR_MEM] Byte %0d = 0x%02h", wr_addr, wr_data);
`endif
        end
    end
    
    // CORREÇÃO CRÍTICA: Inicialização explícita da memória
    initial begin
        for (int i = 0; i < 32; i = i + 1) begin
            image_mem[i] = 8'd0;
        end
    end
    
    // ========== MÁQUINA DE ESTADOS PRINCIPAL ==========
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            pixel_x <= 8'd0;
            pixel_y <= 8'd0;
            theta_idx <= 7'd0;
            clear_count <= 16'd0;
            peak_count <= 4'd0;
            num_lines <= 8'd0;
            debug_printed <= 1'b0;
            
            // Inicializa arrays de saída
            line_rho[0] <= 8'd0;
            line_rho[1] <= 8'd0;
            line_rho[2] <= 8'd0;
            line_rho[3] <= 8'd0;
            line_theta[0] <= 8'd0;
            line_theta[1] <= 8'd0;
            line_theta[2] <= 8'd0;
            line_theta[3] <= 8'd0;
            line_votes[0] <= 8'd0;
            line_votes[1] <= 8'd0;
            line_votes[2] <= 8'd0;
            line_votes[3] <= 8'd0;
            
        end else begin
            // Default: done é pulso de 1 ciclo
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        clear_count <= 8'd0;
                        state <= CLEAR_ACC;
                    end
                end
                
                CLEAR_ACC: begin
                    // Zera acumulador (precisa de RHO_BINS × THETA_BINS = 16×16 = 256 ciclos)
                    debug_printed <= 1'b0;  // Reseta flag de debug
                    if (clear_count < RHO_BINS * THETA_BINS) begin
                        accumulator[clear_count] <= 6'd0;
                        clear_count <= clear_count + 1'b1;
                    end else begin
                        pixel_x <= 8'd0;
                        pixel_y <= 8'd0;
                        theta_idx <= 7'd0;
                        
                        // DEBUG: Imprime imagem desempacotada (APENAS EM SIMULAÇÃO)
                        `ifdef SIMULATION
                        $display("\n=== IMAGEM DESEMPACOTADA NO FPGA ===");
                        for (integer debug_y = 0; debug_y < IMG_SIZE; debug_y++) begin
                            for (integer debug_x = 0; debug_x < IMG_SIZE; debug_x++) begin
                                integer debug_pixel_idx = debug_y * IMG_SIZE + debug_x;
                                integer debug_byte_addr = debug_pixel_idx / 8;
                                integer debug_bit_pos = debug_pixel_idx % 8;
                                if (image_mem[debug_byte_addr][debug_bit_pos])
                                    $write("█");
                                else
                                    $write("·");
                            end
                            $display("");
                        end
                        $display("====================================\n");
                        
                        // DEBUG: Mostra memória após recepção UART
                        $display("[DEBUG] Conteúdo da memória após UART:");
                        for (int dbg_i = 0; dbg_i < 16; dbg_i++) begin
                            $display("  Bytes %2d-%2d: %02h %02h", dbg_i*2, dbg_i*2+1, 
                                     image_mem[dbg_i*2], image_mem[dbg_i*2+1]);
                        end
                        $display("");
                        `endif
                        
                        state <= VOTE;
                    end
                end
                
                VOTE: begin
                    // Processa cada pixel da imagem
                    // Para cada pixel de borda, vota em todos os θ
                    
                    // ========== CORREÇÃO: DESEMPACOTAMENTO CORRETO ==========
                    // Formato do C: pixel_idx = row * WIDTH + col
                    //                byte_idx = pixel_idx / 8
                    //                bit_idx = pixel_idx % 8
                    // Cada byte contém 8 pixels, LSB first
                    // Exemplo: byte 0, bit 0 = pixel (0,0)
                    //          byte 0, bit 1 = pixel (0,1)
                    //          byte 2, bit 0 = pixel (1,0)
                    integer pixel_linear_idx;
                    pixel_linear_idx = pixel_y * IMG_SIZE + pixel_x;
                    byte_addr = pixel_linear_idx / 8;
                    bit_pos = pixel_linear_idx % 8;
                    // =======================================================
                    
                    // Verifica se é pixel de borda
                    // CORREÇÃO CRÍTICA: Usa case para acessar bit (workaround para IVerilog)
                    case (bit_pos)
                        0: pixel_bit = image_mem[byte_addr][0];
                        1: pixel_bit = image_mem[byte_addr][1];
                        2: pixel_bit = image_mem[byte_addr][2];
                        3: pixel_bit = image_mem[byte_addr][3];
                        4: pixel_bit = image_mem[byte_addr][4];
                        5: pixel_bit = image_mem[byte_addr][5];
                        6: pixel_bit = image_mem[byte_addr][6];
                        7: pixel_bit = image_mem[byte_addr][7];
                        default: pixel_bit = 1'b0;
                    endcase
                    
                    if (pixel_bit) begin
                        // Usa valores calculados combinacionalmente
                        // (já calculados no bloco always_comb acima)
                        rho_scaled <= rho_calc;
                        rho_bin <= rho_bin_calc;
                        
                        // Vota no acumulador
                        acc_addr = rho_bin_calc * THETA_BINS + theta_idx;
                        accumulator[acc_addr] <= accumulator[acc_addr] + 1'b1;
                    end
                    
                    // Avança para próximo θ
                    if (theta_idx < THETA_BINS - 1) begin
                        theta_idx <= theta_idx + 1'b1;
                    end else begin
                        theta_idx <= 7'd0;
                        
                        // Avança para próximo pixel
                        if (pixel_x < IMG_SIZE - 1) begin
                            pixel_x <= pixel_x + 1'b1;
                        end else begin
                            pixel_x <= 8'd0;
                            if (pixel_y < IMG_SIZE - 1) begin
                                pixel_y <= pixel_y + 1'b1;
                            end else begin
                                // Terminou de processar todos os pixels
                                peak_count <= 4'd0;
                                pixel_x <= 8'd0;
                                pixel_y <= 8'd0;
                                state <= FIND_PEAKS;
                            end
                        end
                    end
                end
                
                FIND_PEAKS: begin
                    // CORREÇÃO: Busca os MAIORES picos em todo o acumulador
                    // Mantém os TOP-N picos com mais votos
                    
                    // Usa pixel_x e pixel_y como índices r e t (reutiliza contadores)
                    clear_r = pixel_x;  // rho
                    clear_t = pixel_y;  // theta
                    acc_addr = clear_r * THETA_BINS + clear_t;
                    
                    // ESTRATÉGIA: Mantém os TOP-N picos com MAIS votos
                    // Comparação direta desenrolada (sem loops) para síntese
                    if (accumulator[acc_addr] >= 6'd5) begin  // Threshold mínimo
                        if (peak_count < MAX_LINES) begin
                            // Ainda há espaço: adiciona direto
                            line_rho[peak_count] <= clear_r[7:0];
                            line_theta[peak_count] <= (clear_t * 180) / THETA_BINS;
                            line_votes[peak_count] <= {2'b0, accumulator[acc_addr]};
                            peak_count <= peak_count + 1'b1;
                        end else if (peak_count == MAX_LINES) begin
                            // Lista cheia: substitui o MENOR se este for maior
                            // Comparação desenrolada para MAX_LINES=4
                            if (accumulator[acc_addr] > line_votes[0][5:0] && 
                                line_votes[0][5:0] <= line_votes[1][5:0] && 
                                line_votes[0][5:0] <= line_votes[2][5:0] && 
                                line_votes[0][5:0] <= line_votes[3][5:0]) begin
                                // Slot 0 tem o menor
                                line_rho[0] <= clear_r[7:0];
                                line_theta[0] <= (clear_t * 180) / THETA_BINS;
                                line_votes[0] <= {2'b0, accumulator[acc_addr]};
                            end else if (accumulator[acc_addr] > line_votes[1][5:0] && 
                                         line_votes[1][5:0] <= line_votes[0][5:0] && 
                                         line_votes[1][5:0] <= line_votes[2][5:0] && 
                                         line_votes[1][5:0] <= line_votes[3][5:0]) begin
                                // Slot 1 tem o menor
                                line_rho[1] <= clear_r[7:0];
                                line_theta[1] <= (clear_t * 180) / THETA_BINS;
                                line_votes[1] <= {2'b0, accumulator[acc_addr]};
                            end else if (accumulator[acc_addr] > line_votes[2][5:0] && 
                                         line_votes[2][5:0] <= line_votes[0][5:0] && 
                                         line_votes[2][5:0] <= line_votes[1][5:0] && 
                                         line_votes[2][5:0] <= line_votes[3][5:0]) begin
                                // Slot 2 tem o menor
                                line_rho[2] <= clear_r[7:0];
                                line_theta[2] <= (clear_t * 180) / THETA_BINS;
                                line_votes[2] <= {2'b0, accumulator[acc_addr]};
                            end else if (accumulator[acc_addr] > line_votes[3][5:0] && 
                                         line_votes[3][5:0] <= line_votes[0][5:0] && 
                                         line_votes[3][5:0] <= line_votes[1][5:0] && 
                                         line_votes[3][5:0] <= line_votes[2][5:0]) begin
                                // Slot 3 tem o menor
                                line_rho[3] <= clear_r[7:0];
                                line_theta[3] <= (clear_t * 180) / THETA_BINS;
                                line_votes[3] <= {2'b0, accumulator[acc_addr]};
                            end
                        end
                    end
                    
                    // Sempre avança para próxima posição
                    if (pixel_y < THETA_BINS - 1) begin
                        pixel_y <= pixel_y + 1'b1;
                    end else begin
                        pixel_y <= 7'd0;
                        if (pixel_x < RHO_BINS - 1) begin
                            pixel_x <= pixel_x + 1'b1;
                        end else begin
                            // Terminou de varrer todo o acumulador
                            num_lines <= peak_count;
`ifdef SIMULATION
                            $display("[FIND_PEAKS] Varredura completa. Total de picos: %0d", peak_count);
`endif
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule

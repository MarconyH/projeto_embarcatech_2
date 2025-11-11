// hough_tracker.sv
// Hough Tracker Minimalista: Rastreamento de Borda Vertical (Substituto de lane_hough.vhd)

module hough_tracker #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720
) (
    input  logic clk,
    input  logic reset,
    
    // Interface de entrada (pixels de Sobel)
    input  logic vs_in,      // Simulado pelo estado PROCESSING
    input  logic de_in,      // Simulado pelo estado PROCESSING
    input  logic edge_detected,
    input  int x_coord,      // Coordenada X do pixel sendo processado
    input  int y_coord,      // Coordenada Y do pixel sendo processado
    
    // Interface de saída
    output logic processing,
    output logic line_detected,
    output int line_rho,        // Coordenada X da última borda (0-1279)
    output int line_theta       // Ângulo (Sempre 2 = 90 graus)
);

    logic frame_active;
    logic vs_prev;
    logic line_detected_reg;
    int last_edge_x;
    
    // Configuração inicial (força o centro da imagem)
    // Uso de initial é válido para simulação e inicialização em FPGA (Yosys)
    initial begin
        last_edge_x = IMG_WIDTH / 2;
        line_detected_reg = 1'b0;
        frame_active = 1'b0;
        vs_prev = 1'b0;
    end

    // Saídas combinacionais
    assign processing = frame_active;
    assign line_detected = line_detected_reg;
    assign line_theta = 2;        // Sempre 90 graus (Linha Vertical)
    assign line_rho = last_edge_x;

    // Lógica Sequencial (Rastreamento de Borda)
    always_ff @(posedge clk) begin
        vs_prev <= vs_in;

        if (reset) begin
            frame_active <= 1'b0;
            line_detected_reg <= 1'b0;
            last_edge_x <= IMG_WIDTH / 2;
        end else begin
            
            // 1. Início de Frame (vs_in é o pulso de início do estado PROCESSING)
            if (vs_in == 1'b1 && vs_prev == 1'b0) begin
                frame_active <= 1'b1;
                line_detected_reg <= 1'b0;
            end
            
            // 2. Fim de Frame (vs_in é o pulso de fim do estado PROCESSING)
            else if (vs_in == 1'b0 && vs_prev == 1'b1) begin
                frame_active <= 1'b0;
                line_detected_reg <= 1'b1; // Linha detectada e disponível
            end
            
            // 3. Rastreamento (Atualiza a última posição X da borda)
            else if (frame_active && de_in && edge_detected) begin
                last_edge_x <= x_coord;
            end
        end
    end

endmodule
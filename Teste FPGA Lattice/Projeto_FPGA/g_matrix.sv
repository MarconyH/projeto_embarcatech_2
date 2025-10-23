// g_matrix.sv
// Arithmetic for 3x3 matrix of Sobel filter (Substitui lane_g_matrix.vhd)
// Calcula G_x^2 ou G_y^2

module g_matrix (
    input  logic clk,
    input  logic reset,
    // Pixels que recebem fator +1 ou +2
    input  logic [23:0] in_p1a, in_p2, in_p1b, 
    // Pixels que recebem fator -1 ou -2
    input  logic [23:0] in_m1a, in_m2, in_m1b,
    output logic [27:0] data_out // 28 bits para G^2 (máx 268M)
);

    // Registradores para valores de luminância Y (0 a 4095)
    logic [11:0] lum_p1a, lum_p2, lum_p1b;
    logic [11:0] lum_m1a, lum_m2, lum_m1b;
    
    // Soma intermediária (Máx 4 * 4095 = 16380 -> requer ~15 bits com sinal)
    int sum_reg; 

    // Função combinacional para conversão RGB para Y (Luminância)
    function automatic logic [11:0] rgb2y (input logic [23:0] vec);
        logic [7:0] r, g, b;
        logic [11:0] result;
        
        r = vec[23:16]; // R
        g = vec[15:8];  // G
        b = vec[7:0];   // B
        
        // Y = 5*R + 9*G + 2*B (Normalizado internamente no VHDL original)
        // O valor máximo é 16 * 255 = 4080 (cabe em 12 bits)
        result = (r * 5) + (g * 9) + (b * 2);
        return result;
    endfunction
    
    // Estágio 1: Conversão e Sobel Sum (Registrado)
    always_ff @(posedge clk) begin
        // Conversão RGB para Y
        lum_p1a <= rgb2y(in_p1a);
        lum_p2  <= rgb2y(in_p2);
        lum_p1b <= rgb2y(in_p1b);
        lum_m1a <= rgb2y(in_m1a);
        lum_m2  <= rgb2y(in_m2);
        lum_m1b <= rgb2y(in_m1b);
        
        // Cálculo da soma do Sobel (G_x ou G_y)
        // sum = (+1)*p1a + (+2)*p2 + (+1)*p1b + (-1)*m1a + (-2)*m2 + (-1)*m1b
        sum_reg <= lum_p1a + (lum_p2 * 2) + lum_p1b 
                 - lum_m1a - (lum_m2 * 2) - lum_m1b;
    end
    
    // Estágio 2: Quadrado da Soma (Registrado)
    // sum*sum é no máximo 16380^2 ≈ 268M (28 bits)
    always_ff @(posedge clk) begin
        data_out <= sum_reg * sum_reg;
    end

endmodule
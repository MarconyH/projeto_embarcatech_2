// g_root_lut.sv
// ROM/LUT para Raiz Quadrada do Gradiente (Substitui lane_g_root_IP.vhd)

module g_root_lut (
    input  logic clk,
    input  logic [12:0] address, // Endereço 0 a 8191
    output logic [7:0] q         // Saída 0 a 255
);
    localparam int ROM_DEPTH = 8192; 
    
    logic [7:0] lut_mem [0:ROM_DEPTH-1];

    // Inicialização da ROM (Deve ser gerada a partir do lane_g_root.mif)
    initial begin
        // NOTA: É CRÍTICO que o arquivo 'g_root_lut.hex' ou similar seja criado 
        // e contenha os 8192 valores 255 - sqrt(8 * g_sum_2 / 8192)
        // Se você não tiver um .hex, este módulo falhará na síntese.
        // O $readmemh é aceito por Yosys/Nextpnr para inicialização de ROM.
        $readmemh("g_root_lut.hex", lut_mem); 
    end

    // Leitura Síncrona (comum para BRAM/LUT-RAM)
    always_ff @(posedge clk) begin
        q <= lut_mem[address];
    end
    
endmodule
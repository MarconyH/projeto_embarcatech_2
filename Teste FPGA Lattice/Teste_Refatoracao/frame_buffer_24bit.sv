// Armazenamento da imagem 1280x720 (2.76 MB) - Usa BRAM no FPGA

module frame_buffer_24bit #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720,
    parameter PIXEL_BITS = 24
) (
    input  logic clk,
    input  logic reset,
    
    // Porta de Escrita (Controlada pelo UART RX)
    input  logic [$clog2(IMG_WIDTH * IMG_HEIGHT)-1:0] wr_addr,
    input  logic [PIXEL_BITS-1:0] wr_data,
    input  logic wr_en,
    
    // Porta de Leitura (Controlada pelo Sobel/Processamento)
    input  logic [$clog2(IMG_WIDTH * IMG_HEIGHT)-1:0] rd_addr,
    output logic [PIXEL_BITS-1:0] rd_data
);

    localparam int MEM_DEPTH = IMG_WIDTH * IMG_HEIGHT;
    localparam int ADDR_WIDTH = $clog2(MEM_DEPTH); // 10 bits + 7 bits = 17 bits

    // Memória real (será mapeada para BRAMs ou EBRs no Lattice ECP5)
    logic [PIXEL_BITS-1:0] memory [0:MEM_DEPTH-1];
    
    // Escrita na BRAM (síncrona)
    always_ff @(posedge clk) begin
        if (wr_en) begin
            memory[wr_addr] <= wr_data;
        end
    end
    
    // Leitura na BRAM (Síncrona ou Assíncrona. Aqui definimos Leitura Síncrona 
    // para melhor timing e mapeamento de BRAM)
    always_ff @(posedge clk) begin
        // Não usamos rd_en pois a leitura é contínua no estágio PROCESSING
        rd_data <= memory[rd_addr]; 
    end

endmodule
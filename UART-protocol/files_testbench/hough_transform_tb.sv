// hough_transform_tb.sv
// Testbench para o módulo hough_transform
// Testa detecção de linhas em padrões conhecidos

`timescale 1ns/1ps

module hough_transform_tb;

    // Parâmetros
    localparam IMG_SIZE = 16;
    localparam RHO_BINS = 16;
    localparam THETA_BINS = 16;
    localparam MAX_LINES = 4;
    
    // Sinais do DUT
    logic        clk;
    logic        reset_n;
    logic        start;
    logic        done;
    logic        busy;
    logic        wr_en;
    logic [7:0]  wr_addr;
    logic [7:0]  wr_data;
    logic [7:0]  num_lines;
    
    // Sinais flat
    logic [7:0]  line_rho_0, line_rho_1, line_rho_2, line_rho_3;
    logic [7:0]  line_theta_0, line_theta_1, line_theta_2, line_theta_3;
    logic [7:0]  line_votes_0, line_votes_1, line_votes_2, line_votes_3;
    
    // Arrays locais para facilitar uso no testbench
    logic [7:0]  line_rho   [0:MAX_LINES-1];
    logic [7:0]  line_theta [0:MAX_LINES-1];
    logic [7:0]  line_votes [0:MAX_LINES-1];
    
    // Mapeamento
    assign line_rho[0]   = line_rho_0;
    assign line_rho[1]   = line_rho_1;
    assign line_rho[2]   = line_rho_2;
    assign line_rho[3]   = line_rho_3;
    assign line_theta[0] = line_theta_0;
    assign line_theta[1] = line_theta_1;
    assign line_theta[2] = line_theta_2;
    assign line_theta[3] = line_theta_3;
    assign line_votes[0] = line_votes_0;
    assign line_votes[1] = line_votes_1;
    assign line_votes[2] = line_votes_2;
    assign line_votes[3] = line_votes_3;
    
    // Instancia DUT
    hough_transform #(
        .IMG_SIZE(IMG_SIZE),
        .RHO_BINS(RHO_BINS),
        .THETA_BINS(THETA_BINS),
        .MAX_LINES(MAX_LINES)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .done(done),
        .busy(busy),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .num_lines(num_lines),
        .line_rho_0(line_rho_0),
        .line_theta_0(line_theta_0),
        .line_votes_0(line_votes_0),
        .line_rho_1(line_rho_1),
        .line_theta_1(line_theta_1),
        .line_votes_1(line_votes_1),
        .line_rho_2(line_rho_2),
        .line_theta_2(line_theta_2),
        .line_votes_2(line_votes_2),
        .line_rho_3(line_rho_3),
        .line_theta_3(line_theta_3),
        .line_votes_3(line_votes_3)
    );
    
    // Geração de clock (50 MHz = 20ns período)
    initial clk = 0;
    always #10 clk = ~clk;
    
    // Matriz de teste (16x16 bits = 32 bytes)
    logic [7:0] test_image [0:31];
    
    // Task para carregar imagem no DUT
    task load_image();
        for (int i = 0; i < 32; i++) begin
            @(posedge clk);
            wr_en = 1'b1;
            wr_addr = i[7:0];
            wr_data = test_image[i];
        end
        @(posedge clk);
        wr_en = 1'b0;
    endtask
    
    // Task para criar linha vertical em x
    task create_vertical_line(input int x_pos);
        int pixel_idx, byte_addr, bit_pos;
        int y;
        // Zera imagem
        for (int i = 0; i < 32; i++) test_image[i] = 8'h00;
        
        // Desenha linha vertical
        for (y = 0; y < IMG_SIZE; y = y + 1) begin
            pixel_idx = y * IMG_SIZE + x_pos;
            byte_addr = pixel_idx / 8;
            bit_pos = pixel_idx % 8;
            test_image[byte_addr][bit_pos] = 1'b1;
        end
    endtask
    
    // Task para criar linha horizontal em y
    task create_horizontal_line(input int y_pos);
        int pixel_idx, byte_addr, bit_pos;
        int x;
        // Zera imagem
        for (int i = 0; i < 32; i++) test_image[i] = 8'h00;
        
        // Desenha linha horizontal
        for (x = 0; x < IMG_SIZE; x = x + 1) begin
            pixel_idx = y_pos * IMG_SIZE + x;
            byte_addr = pixel_idx / 8;
            bit_pos = pixel_idx % 8;
            test_image[byte_addr][bit_pos] = 1'b1;
        end
    endtask
    
    // Task para criar linha diagonal (canto superior esquerdo -> inferior direito)
    task create_diagonal_line();
        int pixel_idx, byte_addr, bit_pos;
        int i, j;
        // Zera imagem
        for (j = 0; j < 32; j = j + 1) test_image[j] = 8'h00;
        
        // Desenha diagonal
        for (i = 0; i < IMG_SIZE; i = i + 1) begin
            pixel_idx = i * IMG_SIZE + i;
            byte_addr = pixel_idx / 8;
            bit_pos = pixel_idx % 8;
            test_image[byte_addr][bit_pos] = 1'b1;
        end
    endtask
    
    // Task para imprimir imagem
    task print_image();
        int pixel_idx, byte_addr, bit_pos;
        int x, y;
        $display("\n=== Imagem de Teste (16x16) ===");
        for (y = 0; y < IMG_SIZE; y = y + 1) begin
            $write("  ");
            for (x = 0; x < IMG_SIZE; x = x + 1) begin
                pixel_idx = y * IMG_SIZE + x;
                byte_addr = pixel_idx / 8;
                bit_pos = pixel_idx % 8;
                if (test_image[byte_addr][bit_pos])
                    $write("█");
                else
                    $write("·");
            end
            $display("");
        end
    endtask
    
    // Task para imprimir acumulador (células com votos > 0)
    task print_accumulator();
        int r, t, addr, votes;
        $display("\n=== Acumulador (células não-vazias) ===");
        for (r = 0; r < RHO_BINS; r++) begin
            for (t = 0; t < THETA_BINS; t++) begin
                addr = r * THETA_BINS + t;
                votes = dut.accumulator[addr];
                if (votes > 0) begin
                    $display("  acc[ρ=%2d][θ=%2d (θ=%3d°)] = %0d votos", 
                             r, t, (t * 180) / THETA_BINS, votes);
                end
            end
        end
    endtask
    
    // Task para imprimir resultados
    task print_results();
        print_accumulator();
        $display("\n=== Resultados da Transformada de Hough ===");
        $display("Linhas detectadas: %0d", num_lines);
        for (int i = 0; i < num_lines; i++) begin
            $display("  Linha %0d: ρ=%0d, θ=%0d°, votos=%0d", 
                     i, line_rho[i], line_theta[i], line_votes[i]);
        end
    endtask
    
    // Task para executar transformada
    task run_hough();
        int vote_count;
        int mon_byte_addr, mon_bit_pos;
        logic mon_pixel;
        
        vote_count = 0;
        
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        
        // Monitora estado VOTE (mostra primeiras 16 votações)
        fork
            begin
                while (!done && vote_count < 32) begin
                    @(posedge clk);
                    if (dut.state == 3'b010) begin  // VOTE = 2
                        // Calcula os mesmos valores que o DUT
                        mon_byte_addr = (dut.pixel_y * 16 + dut.pixel_x) / 8;
                        mon_bit_pos = (dut.pixel_y * 16 + dut.pixel_x) % 8;
                        mon_pixel = dut.image_mem[mon_byte_addr][mon_bit_pos];
                        
                        if (mon_pixel && vote_count < 16) begin
                            $display("  [VOTE] px(%2d,%2d) θ=%2d → rho_scaled=%0d rho_bin=%0d acc[%0d]",
                                     dut.pixel_x, dut.pixel_y, dut.theta_idx, 
                                     $signed(dut.rho_scaled), dut.rho_bin, dut.acc_addr);
                            vote_count = vote_count + 1;
                        end
                    end
                end
            end
            begin
                wait(done);
            end
        join_any
        disable fork;
        
        @(posedge clk);
    endtask
    
    // Bloco de teste principal
    initial begin
        $dumpfile("hough_tb.vcd");
        $dumpvars(0, hough_transform_tb);
        
        // Inicialização
        reset_n = 1'b0;
        start = 1'b0;
        wr_en = 1'b0;
        wr_addr = 8'h00;
        wr_data = 8'h00;
        
        // Reset
        repeat(5) @(posedge clk);
        reset_n = 1'b1;
        repeat(5) @(posedge clk);
        
        $display("\n========================================");
        $display("  TESTBENCH: Transformada de Hough");
        $display("========================================\n");
        
        // ========== TESTE 1: Linha Vertical no centro (x=8) ==========
        $display("\n>>> TESTE 1: Linha Vertical (x=8)");
        create_vertical_line(8);
        print_image();
        load_image();
        run_hough();
        print_results();
        $display("Esperado: θ ≈ 90° (vertical), ρ ≈ 8");
        
        repeat(10) @(posedge clk);
        
        // ========== TESTE 2: Linha Horizontal no centro (y=8) ==========
        $display("\n>>> TESTE 2: Linha Horizontal (y=8)");
        create_horizontal_line(8);
        print_image();
        load_image();
        run_hough();
        print_results();
        $display("Esperado: θ ≈ 0° (horizontal), ρ ≈ 8");
        
        repeat(10) @(posedge clk);
        
        // ========== TESTE 3: Linha Diagonal ==========
        $display("\n>>> TESTE 3: Linha Diagonal");
        create_diagonal_line();
        print_image();
        load_image();
        run_hough();
        print_results();
        $display("Esperado: θ ≈ 45° (diagonal), ρ variável");
        
        repeat(10) @(posedge clk);
        
        // ========== TESTE 4: Borda de retângulo ==========
        $display("\n>>> TESTE 4: Retângulo (múltiplas linhas)");
        begin
            int i, x, y;
            int pixel_top, byte_top, bit_top;
            int pixel_bot, byte_bot, bit_bot;
            int pixel_left, byte_left, bit_left;
            int pixel_right, byte_right, bit_right;
            
            for (i = 0; i < 32; i = i + 1) test_image[i] = 8'h00;
            
            // Bordas superior e inferior
            for (x = 4; x <= 12; x = x + 1) begin
                pixel_top = 4 * IMG_SIZE + x;
                byte_top = pixel_top / 8;
                bit_top = pixel_top % 8;
                test_image[byte_top][bit_top] = 1'b1;
                
                pixel_bot = 12 * IMG_SIZE + x;
                byte_bot = pixel_bot / 8;
                bit_bot = pixel_bot % 8;
                test_image[byte_bot][bit_bot] = 1'b1;
            end
            
            // Bordas esquerda e direita
            for (y = 4; y <= 12; y = y + 1) begin
                pixel_left = y * IMG_SIZE + 4;
                byte_left = pixel_left / 8;
                bit_left = pixel_left % 8;
                test_image[byte_left][bit_left] = 1'b1;
                
                pixel_right = y * IMG_SIZE + 12;
                byte_right = pixel_right / 8;
                bit_right = pixel_right % 8;
                test_image[byte_right][bit_right] = 1'b1;
            end
        end
        
        print_image();
        load_image();
        run_hough();
        print_results();
        $display("Esperado: 4 linhas (2 horizontais, 2 verticais)");
        
        repeat(10) @(posedge clk);
        
        // ========== TESTE 5: Imagem vazia ==========
        $display("\n>>> TESTE 5: Imagem Vazia");
        for (int i = 0; i < 32; i++) test_image[i] = 8'h00;
        print_image();
        load_image();
        run_hough();
        print_results();
        $display("Esperado: 0 linhas");
        
        repeat(10) @(posedge clk);
        
        $display("\n========================================");
        $display("  Testes Concluídos!");
        $display("========================================\n");
        
        $finish;
    end
    
    // Timeout de segurança
    initial begin
        #1000000;  // 1ms timeout
        $display("\nERRO: Timeout! Simulação travada.");
        $finish;
    end

endmodule

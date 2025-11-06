// uart_hough_integration_tb.sv
// Testbench de integração SINCRONIZADO COM MAIN.C
// Versão 3.0: Replica EXATAMENTE o comportamento do Raspberry Pi Pico
// - Monitor de uart_tx durante envio (detecta resposta prematura do FPGA)
// - Diagonal igual ao main.c: matrix[i][j] = (i == j) ? 255 : 0
// - Thresholds reduzidos: ρ=0 (≥8), ρ≠0 (≥5)

`timescale 1ns/1ps
`define SIMULATION  // Habilita debug no Hough Transform

module uart_hough_integration_tb;

    // Parâmetros ajustados para simulação realista
    localparam CLK_FREQ = 10000;    // 10 kHz para simulação mais rápida
    localparam BAUD_RATE = 1000;     // 1000 baud (1 bit = 10 clocks)
    localparam IMG_SIZE = 16;
    localparam IMG_BYTES = 32;       // 16x16 bits / 8 = 32 bytes
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;  // 10 clocks por bit
    localparam MAX_LINES = 4;
    
    // Timeouts calculados
    localparam BYTE_TIME = CLKS_PER_BIT * 12;  // 12 bits por byte (start + 8 data + stop + margin)
    localparam IMAGE_TIME = BYTE_TIME * (IMG_BYTES + 2);  // Header + imagem + margem
    localparam HOUGH_TIME = 50000;   // Tempo estimado para Hough processar
    localparam RESULT_TIME = BYTE_TIME * 20;  // Tempo para receber resultado
    
    // Sinais
    logic clk;
    logic reset_n;
    logic uart_rx;
    logic uart_tx;
    
    // Buffers de teste
    logic [7:0] test_image [0:IMG_BYTES-1];
    logic [7:0] received_data [$];  // Fila para dados recebidos
    
    // Instancia DUT
    uart_echo_colorlight_i9 #(
        .clk_freq(CLK_FREQ),
        .baud_rate(BAUD_RATE),
        .IMG_SIZE(IMG_SIZE)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );
    
    // Geração de clock
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns período = 100 MHz (ajustado por CLKS_PER_BIT)
    
    // Contadores de debug
    int bytes_sent = 0;
    int bytes_received = 0;
    logic tx_monitor_active = 0;
    
    // Variáveis auxiliares para tasks (declaradas globalmente para evitar 'automatic')
    int task_i, task_y, task_x, task_pixel_idx, task_byte_addr, task_bit_pos;
    
    // Task para enviar byte via UART (com debug)
    task uart_send_byte(input logic [7:0] data);
        int i;
        
        $display("[%0t] TX: Enviando byte 0x%02h (%d)", $time, data, data);
        
        // Start bit
        uart_rx = 1'b0;
        repeat(CLKS_PER_BIT) @(posedge clk);
        
        // Data bits (LSB first)
        for (i = 0; i < 8; i++) begin
            uart_rx = data[i];
            repeat(CLKS_PER_BIT) @(posedge clk);
        end
        
        // Stop bit
        uart_rx = 1'b1;
        repeat(CLKS_PER_BIT) @(posedge clk);
        
        // Inter-byte gap (AUMENTADO para debug - 10 bit times)
        repeat(CLKS_PER_BIT * 10) @(posedge clk);
        
        bytes_sent++;
        $display("[%0t] TX: Byte enviado com sucesso (total: %0d)", $time, bytes_sent);
    endtask
    
    // Task para receber byte via UART (timeout simplificado - sem fork-join)
    task uart_receive_byte(output logic [7:0] data, input int timeout_cycles);
        int i;
        int wait_count;
        
        $display("[%0t] RX: Aguardando byte...", $time);
        
        // Aguarda start bit com timeout (polling simples)
        wait_count = 0;
        while (uart_tx == 1'b1 && wait_count < timeout_cycles) begin
            @(posedge clk);
            wait_count++;
        end
        
        if (wait_count >= timeout_cycles) begin
            $display("[%0t] RX: TIMEOUT aguardando start bit!", $time);
            data = 8'hFF;
        end else begin
            $display("[%0t] RX: Start bit detectado", $time);
            
            // Vai para o meio do start bit
            repeat(CLKS_PER_BIT / 2) @(posedge clk);
            repeat(CLKS_PER_BIT) @(posedge clk);  // Pula start bit
            
            // Lê data bits (LSB first)
            for (i = 0; i < 8; i++) begin
                data[i] = uart_tx;
                repeat(CLKS_PER_BIT) @(posedge clk);
            end
            
            // Stop bit (verifica se está em HIGH)
            if (uart_tx != 1'b1) begin
                $display("[%0t] RX: ERRO - Stop bit inválido!", $time);
            end
            
            bytes_received++;
            $display("[%0t] RX: Byte recebido 0x%02h (%d) - total: %0d", $time, data, data, bytes_received);
        end
    endtask
    
    // Task para imprimir bytes empacotados (IGUAL AO main.c debug)
    task print_packed_bytes();
        integer print_i, print_bit;
        
        $display("\n📦 Bytes empacotados enviados (HEX):");
        for (print_i = 0; print_i < IMG_BYTES; print_i++) begin
            $write("0x%02h ", test_image[print_i]);
            if ((print_i + 1) % 8 == 0) $display("");
        end
        $display("");
        
        $display("📦 Bytes empacotados enviados (BINÁRIO):");
        for (print_i = 0; print_i < IMG_BYTES; print_i++) begin
            for (print_bit = 0; print_bit < 8; print_bit++) begin
                $write("%0d", test_image[print_i][print_bit]);
            end
            $write(" ");
            if ((print_i + 1) % 4 == 0) $display("");
        end
        $display("");
    endtask
    
    // Task para criar imagem com APENAS 1 PIXEL (para debug)
    task create_single_pixel(input int x, input int y);
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        task_pixel_idx = y * IMG_SIZE + x;
        task_byte_addr = task_pixel_idx / 8;
        task_bit_pos = task_pixel_idx % 8;
        test_image[task_byte_addr][task_bit_pos] = 1'b1;
        
        $display("Criado pixel único em (%0d,%0d) → byte %0d, bit %0d", x, y, task_byte_addr, task_bit_pos);
    endtask
    
    // Task para criar linha diagonal (IGUAL AO main.c)
    // Cria matriz[i][j] = (i == j) ? 255 : 0
    task create_diagonal_line();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        // Liga pixels da diagonal (0,0), (1,1), (2,2), ..., (15,15)
        for (task_i = 0; task_i < IMG_SIZE; task_i++) begin
            task_pixel_idx = task_i * IMG_SIZE + task_i;  // Pixel na diagonal
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        $display("Criada diagonal: 16 pixels ligados de (0,0) até (15,15)");
    endtask
    
    // Task para criar linha vertical
    task create_vertical_line(input int x_pos);
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            task_pixel_idx = task_y * IMG_SIZE + x_pos;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
    endtask
    
    // Task para criar linha horizontal
    task create_horizontal_line(input int y_pos);
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        for (task_x = 0; task_x < IMG_SIZE; task_x++) begin
            task_pixel_idx = y_pos * IMG_SIZE + task_x;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
    endtask
    
    // Task para criar anti-diagonal (135°) - linha de (15,0) até (0,15)
    task create_antidiagonal_line();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        // Liga pixels da anti-diagonal: i + j == WIDTH - 1
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            task_x = (IMG_SIZE - 1) - task_y;  // x = 15 - y
            task_pixel_idx = task_y * IMG_SIZE + task_x;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        $display("Criada anti-diagonal: 16 pixels ligados de (15,0) até (0,15)");
    endtask
    
    // Task para criar duas linhas verticais paralelas
    task create_two_verticals();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        // Linha vertical em x=5
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            task_pixel_idx = task_y * IMG_SIZE + 5;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        // Linha vertical em x=10
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            task_pixel_idx = task_y * IMG_SIZE + 10;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        $display("Criadas duas linhas verticais em x=5 e x=10");
    endtask
    
    // Task para criar cruz (vertical + horizontal)
    task create_cross();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        // Linha vertical em x=8
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            task_pixel_idx = task_y * IMG_SIZE + 8;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        // Linha horizontal em y=8
        for (task_x = 0; task_x < IMG_SIZE; task_x++) begin
            task_pixel_idx = 8 * IMG_SIZE + task_x;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        $display("Criada cruz: vertical (x=8) + horizontal (y=8)");
    endtask
    
    // Task para criar quadrado (bordas da imagem)
    task create_square();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            for (task_x = 0; task_x < IMG_SIZE; task_x++) begin
                // Borda: y=0, y=15, x=0, x=15
                if (task_y == 0 || task_y == IMG_SIZE-1 || task_x == 0 || task_x == IMG_SIZE-1) begin
                    task_pixel_idx = task_y * IMG_SIZE + task_x;
                    task_byte_addr = task_pixel_idx / 8;
                    task_bit_pos = task_pixel_idx % 8;
                    test_image[task_byte_addr][task_bit_pos] = 1'b1;
                end
            end
        end
        
        $display("Criado quadrado: bordas da imagem");
    endtask
    
    // Task para criar padrão X (duas diagonais)
    task create_x_pattern();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        // Diagonal principal (0,0) → (15,15)
        for (task_i = 0; task_i < IMG_SIZE; task_i++) begin
            task_pixel_idx = task_i * IMG_SIZE + task_i;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        // Anti-diagonal (15,0) → (0,15)
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            task_x = (IMG_SIZE - 1) - task_y;
            task_pixel_idx = task_y * IMG_SIZE + task_x;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        $display("Criado padrão X: diagonal + anti-diagonal");
    endtask
    
    // Task para criar linha vertical na borda esquerda (x=0)
    task create_vertical_left();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            task_pixel_idx = task_y * IMG_SIZE + 0;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        $display("Criada linha vertical na borda esquerda (x=0)");
    endtask
    
    // Task para criar linha horizontal na borda superior (y=0)
    task create_horizontal_top();
        for (task_i = 0; task_i < IMG_BYTES; task_i++) test_image[task_i] = 8'h00;
        
        for (task_x = 0; task_x < IMG_SIZE; task_x++) begin
            task_pixel_idx = 0 * IMG_SIZE + task_x;
            task_byte_addr = task_pixel_idx / 8;
            task_bit_pos = task_pixel_idx % 8;
            test_image[task_byte_addr][task_bit_pos] = 1'b1;
        end
        
        $display("Criada linha horizontal na borda superior (y=0)");
    endtask
    
    // Task para imprimir imagem
    task print_image();
        $display("\n=== Imagem Enviada (16x16) ===");
        for (task_y = 0; task_y < IMG_SIZE; task_y++) begin
            $write("  ");
            for (task_x = 0; task_x < IMG_SIZE; task_x++) begin
                task_pixel_idx = task_y * IMG_SIZE + task_x;
                task_byte_addr = task_pixel_idx / 8;
                task_bit_pos = task_pixel_idx % 8;
                if (test_image[task_byte_addr][task_bit_pos])
                    $write("█");
                else
                    $write("·");
            end
            $display("");
        end
    endtask
    
    // Task para enviar imagem completa (com progresso detalhado)
    task send_image();
        $display("\n========================================");
        $display("[%0t] ENVIO: Iniciando transmissão da imagem", $time);
        $display("========================================");
        
        // Envia header
        $display("[%0t] ENVIO: Enviando header (0xAA)...", $time);
        uart_send_byte(8'hAA);
        $display("[%0t] ENVIO: Header enviado", $time);
        
        // Aguarda processamento do header
        repeat(CLKS_PER_BIT * 4) @(posedge clk);
        
        // Envia imagem (32 bytes)
        $display("[%0t] ENVIO: Enviando imagem (%0d bytes)...", $time, IMG_BYTES);
        for (task_i = 0; task_i < IMG_BYTES; task_i++) begin
            if (task_i % 8 == 0) begin
                $display("[%0t] ENVIO: Progresso: %0d/%0d bytes", $time, task_i, IMG_BYTES);
            end
            uart_send_byte(test_image[task_i]);
        end
        
        $display("[%0t] ENVIO: Imagem completa enviada (%0d bytes)", $time, IMG_BYTES);
        $display("========================================\n");
    endtask
    
    // Task para receber resultado (com verificação e timeout)
    task receive_result();
        logic [7:0] num_lines;
        logic [7:0] rho, theta, votes;
        int timeout_cycles;
        
        $display("\n========================================");
        $display("[%0t] RECEPÇÃO: Aguardando resultado do Hough Transform", $time);
        $display("========================================");
        
        // Aguarda com timeout longo (Hough pode demorar)
        timeout_cycles = HOUGH_TIME + BYTE_TIME * 10;
        
        // Recebe número de linhas
        $display("[%0t] RECEPÇÃO: Aguardando número de linhas...", $time);
        uart_receive_byte(num_lines, timeout_cycles);
        
        if (num_lines == 8'hFF) begin
            $display("[%0t] RECEPÇÃO: ERRO - Timeout ao receber número de linhas!", $time);
            $display("========================================\n");
        end else if (num_lines > MAX_LINES) begin
            $display("[%0t] RECEPÇÃO: ERRO - Número de linhas inválido (%0d > %0d)", $time, num_lines, MAX_LINES);
            $display("========================================\n");
        end else begin
            $display("[%0t] RECEPÇÃO: ✓ Linhas detectadas: %0d", $time, num_lines);
            
            // Recebe dados de cada linha (3 bytes por linha)
        for (task_i = 0; task_i < num_lines; task_i++) begin
            uart_receive_byte(rho, BYTE_TIME * 20);  // Timeout maior
            if (rho == 8'hFF) begin
                $display("[%0t] RECEPÇÃO: ERRO - Timeout ao receber ρ da linha %0d", $time, task_i);
                task_i = num_lines; // Força saída do loop
            end else begin
                uart_receive_byte(theta, BYTE_TIME * 20);  // Timeout maior
                if (theta == 8'hFF) begin
                    $display("[%0t] RECEPÇÃO: ERRO - Timeout ao receber θ da linha %0d", $time, task_i);
                    task_i = num_lines; // Força saída do loop
                end else begin
                    uart_receive_byte(votes, BYTE_TIME * 20);  // Timeout maior
                    if (votes == 8'hFF) begin
                        $display("[%0t] RECEPÇÃO: ERRO - Timeout ao receber votos da linha %0d", $time, task_i);
                        task_i = num_lines; // Força saída do loop
                    end else begin
                        $display("[%0t] RECEPÇÃO:   Linha %0d: ρ=%0d, θ=%0d°, votos=%0d", $time, task_i, rho, theta, votes);
                    end
                end
            end
        end
        
            $display("[%0t] RECEPÇÃO: ✓ Resultado completo recebido", $time);
        end  // fecha o else begin de num_lines válido
        $display("========================================\n");
    endtask
    
    // Monitor contínuo do uart_tx COM DECODIFICAÇÃO
    logic [7:0] monitored_byte;
    logic monitoring_rx = 0;
    int monitor_bit_count = 0;
    int monitor_clk_count = 0;
    
    always @(posedge clk) begin
        if (tx_monitor_active && !monitoring_rx) begin
            // Detecta start bit
            if (uart_tx == 1'b0) begin
                $display("[%0t] 🔍 MONITOR: Start bit detectado em uart_tx", $time);
                monitoring_rx = 1;
                monitor_bit_count = 0;
                monitor_clk_count = 0;
                monitored_byte = 8'h00;
            end
        end else if (monitoring_rx) begin
            monitor_clk_count++;
            
            // Amostra no meio do bit
            if (monitor_clk_count == (CLKS_PER_BIT / 2)) begin
                if (monitor_bit_count < 8) begin
                    monitored_byte[monitor_bit_count] = uart_tx;
                    monitor_bit_count++;
                end else begin
                    // Stop bit
                    $display("[%0t] 📩 MONITOR: Byte CAPTURADO do FPGA = 0x%02h (%3d decimal)", 
                             $time, monitored_byte, monitored_byte);
                    monitoring_rx = 0;
                end
            end
            
            // Próximo bit
            if (monitor_clk_count >= CLKS_PER_BIT) begin
                monitor_clk_count = 0;
            end
        end
    end
    
    // Teste principal
    initial begin
        $dumpfile("uart_hough_integration.vcd");
        $dumpvars(0, uart_hough_integration_tb);
        
        $display("\n");
        $display("==========================================================");
        $display("  TESTBENCH: UART → Hough Transform → UART");
        $display("  Versão 3.0 - Sincronizado com main.c");
        $display("==========================================================");
        $display("Configuração:");
        $display("  - Clock:     %0d Hz", CLK_FREQ);
        $display("  - Baud Rate: %0d bps", BAUD_RATE);
        $display("  - Clocks/Bit: %0d", CLKS_PER_BIT);
        $display("  - Imagem:    16×16 (32 bytes empacotados)");
        $display("==========================================================\n");
        
        // Inicialização
        reset_n = 1'b0;
        uart_rx = 1'b1;  // UART idle
        tx_monitor_active = 0;
        bytes_sent = 0;
        bytes_received = 0;
        
        repeat(10) @(posedge clk);
        reset_n = 1'b1;
        repeat(10) @(posedge clk);
        
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE DE INTEGRAÇÃO: UART + HOUGH TRANSFORM      ║");
        $display("║  Versão 3.0 - Sincronizado com main.c             ║");
        $display("║  Formato: 32 bytes empacotados (8 pixels/byte)    ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("\nParâmetros da simulação:");
        $display("  Clock Freq:     %0d Hz", CLK_FREQ);
        $display("  Baud Rate:      %0d bps", BAUD_RATE);
        $display("  Clocks/Bit:     %0d", CLKS_PER_BIT);
        $display("  Tempo por byte: %0d clocks", BYTE_TIME);
        $display("  Estado inicial: reset_n=%b, uart_rx=%b, uart_tx=%b", reset_n, uart_rx, uart_tx);
        $display("");
        
        // ========== TESTE 0: Verificação de comunicação básica ==========
        // **COMENTADO** - bytes aleatórios poluem a memória antes dos testes reais
        // $display("\n╔════════════════════════════════════════════════════╗");
        // $display("║  TESTE 0: Verificação de Comunicação UART         ║");
        // $display("╚════════════════════════════════════════════════════╝");
        // $display("[%0t] Enviando bytes de teste (0x00, 0x55, 0xAA, 0xFF)...", $time);
        //
        // tx_monitor_active = 1;
        // uart_send_byte(8'h00);
        // repeat(BYTE_TIME * 2) @(posedge clk);
        // uart_send_byte(8'h55);
        // repeat(BYTE_TIME * 2) @(posedge clk);
        // uart_send_byte(8'hAA);
        // repeat(BYTE_TIME * 2) @(posedge clk);
        // uart_send_byte(8'hFF);
        // repeat(BYTE_TIME * 2) @(posedge clk);
        // tx_monitor_active = 0;
        //
        // $display("[%0t] Bytes de teste enviados. Aguardando sistema estabilizar...", $time);
        // repeat(BYTE_TIME * 10) @(posedge clk);
        
        // ========== TESTE 1: Pixel Único (DEBUG) ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 1: PIXEL ÚNICO (DEBUG)                     ║");
        $display("║  Apenas 1 pixel ativo em (5,5)                    ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_single_pixel(5, 5);  // Pixel (5,5) → pixel_idx=85 → byte 10, bit 5
        print_packed_bytes();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough (max %0d ciclos)...", $time, HOUGH_TIME);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 1 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        
        if (bytes_received > 0) begin
            $display("✅ SUCESSO: FPGA respondeu! Este é o comportamento esperado no hardware.");
        end else begin
            $display("❌ FALHA: FPGA não respondeu. Verifique sinais no GTKWave.");
        end
        
        repeat(100) @(posedge clk);
        
        // ========== TESTE 2: Linha Vertical ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 2: Linha Vertical (x=8)                    ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_vertical_line(8);
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 2 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 3: Linha Horizontal ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 3: Linha Horizontal (y=8)                  ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_horizontal_line(8);
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 3 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 4: Linha Diagonal Principal ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 4: Diagonal Principal (0,0)→(15,15)        ║");
        $display("║  Ângulo esperado: θ ≈ 135° (normal à linha 45°)  ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_diagonal_line();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 4 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 5: Anti-diagonal (135°) ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 5: Anti-diagonal (15,0)→(0,15)             ║");
        $display("║  Ângulo esperado: θ ≈ 45° (normal à linha 135°)  ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_antidiagonal_line();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 5 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 6: Duas Linhas Verticais Paralelas ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 6: Duas Verticais Paralelas (x=5, x=10)    ║");
        $display("║  Ângulo esperado: θ ≈ 90° para ambas              ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_two_verticals();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 6 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 7: Cruz (Vertical + Horizontal) ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 7: Cruz (Vertical + Horizontal)            ║");
        $display("║  Ângulo esperado: θ ≈ 0° e 90° (2 linhas)        ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_cross();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 7 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 8: Quadrado (Bordas da Imagem) ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 8: Quadrado (Bordas)                       ║");
        $display("║  Ângulo esperado: 4 linhas (θ ≈ 0°, 90°, 0°, 90°)║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_square();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 8 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 9: Padrão X (Duas Diagonais) ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 9: Padrão X (Duas Diagonais)               ║");
        $display("║  Ângulo esperado: θ ≈ 45° e 135° (2 linhas)      ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_x_pattern();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 9 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 10: Linha Vertical na Borda Esquerda ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 10: Linha Vertical Borda Esquerda (x=0)    ║");
        $display("║  Ângulo esperado: θ ≈ 90°                         ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_vertical_left();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 10 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        // ========== TESTE 11: Linha Horizontal na Borda Superior ==========
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTE 11: Linha Horizontal Borda Superior (y=0)  ║");
        $display("║  Ângulo esperado: θ ≈ 0° ou 180°                  ║");
        $display("╚════════════════════════════════════════════════════╝");
        
        bytes_sent = 0;
        bytes_received = 0;
        tx_monitor_active = 1;
        
        create_horizontal_top();
        print_image();
        send_image();
        
        $display("[%0t] Aguardando processamento Hough...", $time);
        receive_result();
        
        tx_monitor_active = 0;
        $display("[%0t] Teste 11 concluído. Bytes enviados: %0d, recebidos: %0d", $time, bytes_sent, bytes_received);
        repeat(100) @(posedge clk);
        
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  RESUMO DOS TESTES                                 ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("  Total de bytes enviados:   %0d", bytes_sent);
        $display("  Total de bytes recebidos:  %0d", bytes_received);
        $display("  Tempo total de simulação:  %0t", $time);
        $display("\n✓ Todos os 11 testes concluídos!");
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  TESTES REALIZADOS (igual ao main.c):             ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("  1. Pixel único (5,5) - Debug");
        $display("  2. Linha vertical (x=8)");
        $display("  3. Linha horizontal (y=8)");
        $display("  4. Diagonal principal (0,0)→(15,15) - θ≈135°");
        $display("  5. Anti-diagonal (15,0)→(0,15) - θ≈45°");
        $display("  6. Duas verticais paralelas (x=5, x=10)");
        $display("  7. Cruz (vertical + horizontal)");
        $display("  8. Quadrado (bordas)");
        $display("  9. Padrão X (duas diagonais)");
        $display(" 10. Vertical borda esquerda (x=0)");
        $display(" 11. Horizontal borda superior (y=0)");
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  PRÓXIMO PASSO: TESTE NO HARDWARE                 ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("Se todos os testes passaram na simulação,");
        $display("você pode prosseguir com confiança para o hardware!");
        $display("");
        $display("Comandos para síntese:");
        $display("  1. cd UART-protocol");
        $display("  2. flash_uart.bat (Windows)");
        $display("");
        $display("O hardware deve reproduzir os mesmos resultados!\n");
        
        $finish;
    end
    
    // Timeout global (aumentado para 11 testes)
    initial begin
        #15000000;  // 15ms (suficiente para 11 testes completos)
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  ERRO: TIMEOUT GLOBAL!                            ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("Simulação travada após %0t", $time);
        $display("Bytes enviados:   %0d", bytes_sent);
        $display("Bytes recebidos:  %0d", bytes_received);
        $display("\nPossíveis causas:");
        $display("  1. Módulo Hough travou em algum estado");
        $display("  2. UART RX não está recebendo corretamente");
        $display("  3. UART TX não está transmitindo");
        $display("  4. FSM do uart_echo está travada");
        $display("\nVerifique o arquivo VCD para análise detalhada.");
        $finish;
    end
    
    // Monitor de deadlock (verifica se uart_tx muda de estado)
    logic [31:0] tx_idle_count = 0;
    logic last_uart_tx = 1;
    
    always @(posedge clk) begin
        if (uart_tx == last_uart_tx && uart_tx == 1'b1) begin
            tx_idle_count <= tx_idle_count + 1;
            
            // Se UART TX ficou idle por muito tempo após enviar imagem
            if (tx_idle_count == HOUGH_TIME * 2 && bytes_sent > 10) begin
                $display("\n[%0t] AVISO: uart_tx idle por %0d ciclos (esperado processamento Hough)", 
                         $time, tx_idle_count);
            end
        end else begin
            tx_idle_count <= 0;
        end
        last_uart_tx <= uart_tx;
    end

endmodule

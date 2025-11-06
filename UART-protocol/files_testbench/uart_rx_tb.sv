`timescale 1ns/1ps

module uart_rx_tb;

    // Sinais do Testbench
    logic       i_clk;
    logic       i_reset_n;
    logic       i_rx_serial;
    logic       o_rx_dv;
    logic       [7:0] o_rx_byte;

    uart_rx #(
        .CLKS_PER_BIT(10)  // Igual ao testbench principal
    ) dut (
        .i_clk(i_clk),
        .i_rst_n(i_reset_n),
        .i_rx_serial(i_rx_serial),
        .o_rx_dv(o_rx_dv),
        .o_rx_byte(o_rx_byte)
    );

    // Geração de clock
    initial i_clk = 0;
    always #5 i_clk = ~i_clk;  // 10ns período
    
    // Parâmetros
    localparam CLKS_PER_BIT = 10;
    localparam IMG_BYTES = 32;
    
    // Buffer de teste
    logic [7:0] test_image [0:IMG_BYTES-1];
    int bytes_received = 0;
    logic [7:0] received_bytes [0:IMG_BYTES];  // +1 para o header
    
    // Task para enviar byte via UART
    task uart_send_byte(input logic [7:0] data);
        int i;
        
        $display("[%0t] TX: Enviando byte 0x%02h (%3d)", $time, data, data);
        
        // Start bit
        i_rx_serial = 1'b0;
        repeat(CLKS_PER_BIT) @(posedge i_clk);
        
        // Data bits (LSB first)
        for (i = 0; i < 8; i++) begin
            i_rx_serial = data[i];
            repeat(CLKS_PER_BIT) @(posedge i_clk);
        end
        
        // Stop bit
        i_rx_serial = 1'b1;
        repeat(CLKS_PER_BIT) @(posedge i_clk);
        
        // Inter-byte gap (10 bit times para dar tempo ao RX)
        repeat(CLKS_PER_BIT * 10) @(posedge i_clk);
    endtask
    
    // Monitor de recepção
    always @(posedge i_clk) begin
        if (o_rx_dv) begin
            $display("[%0t] RX: Recebido byte[%0d] = 0x%02h (%3d)", 
                     $time, bytes_received, o_rx_byte, o_rx_byte);
            received_bytes[bytes_received] = o_rx_byte;
            bytes_received++;
        end
    end

    // Bloco de estímulo principal
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, uart_rx_tb);
        
        // Inicializa test_image: todos zeros exceto byte 10 = 0x20
        for (int i = 0; i < IMG_BYTES; i++) begin
            test_image[i] = 8'h00;
        end
        test_image[10] = 8'h20;  // Pixel (5,5)
        
        // Inicializa sinais
        i_reset_n   = 1'b0;
        i_rx_serial = 1'b1;  // UART idle
        bytes_received = 0;

        // Libera reset
        #100;
        i_reset_n = 1'b1;

        // Aguarda estabilização
        repeat(20) @(posedge i_clk);

        $display("\n========================================");
        $display("TESTE: UART RX com Header + 32 bytes");
        $display("========================================");
        $display("Enviando: 0xAA (header) + 32 bytes");
        $display("Byte 10 deve ser 0x20, resto 0x00\n");

        // 1. Envia HEADER (0xAA)
        uart_send_byte(8'hAA);
        
        // 2. Envia 32 bytes da imagem
        for (int i = 0; i < IMG_BYTES; i++) begin
            uart_send_byte(test_image[i]);
        end

        // Aguarda processamento final
        repeat(200) @(posedge i_clk);

        // Verifica resultados
        $display("\n========================================");
        $display("RESULTADOS:");
        $display("========================================");
        $display("Bytes recebidos: %0d (esperado: 33)", bytes_received);
        
        if (bytes_received == 33) begin
            $display("✅ Quantidade correta!");
            
            // Verifica header
            if (received_bytes[0] == 8'hAA) begin
                $display("✅ Header correto: 0x%02h", received_bytes[0]);
            end else begin
                $display("❌ Header ERRADO: 0x%02h (esperado 0xAA)", received_bytes[0]);
            end
            
            // Verifica byte 10 da imagem (índice 11 considerando header)
            if (received_bytes[11] == 8'h20) begin
                $display("✅ Byte 10 (imagem) correto: 0x%02h", received_bytes[11]);
            end else begin
                $display("❌ Byte 10 (imagem) ERRADO: 0x%02h (esperado 0x20)", received_bytes[11]);
            end
            
            // Mostra todos os bytes recebidos
            $display("\n📦 Todos os bytes recebidos:");
            $display("Header: 0x%02h", received_bytes[0]);
            $display("Imagem:");
            for (int i = 1; i <= IMG_BYTES; i++) begin
                $write("0x%02h ", received_bytes[i]);
                if (i % 8 == 0) $display("");
            end
            if (IMG_BYTES % 8 != 0) $display("");
            
        end else begin
            $display("❌ Quantidade ERRADA!");
            $display("\n📦 Bytes recebidos:");
            for (int i = 0; i < bytes_received; i++) begin
                $write("0x%02h ", received_bytes[i]);
                if ((i+1) % 8 == 0) $display("");
            end
            $display("");
        end

        $display("\n========================================");
        $display("TESTE CONCLUÍDO");
        $display("========================================\n");

        $finish;
    end

endmodule
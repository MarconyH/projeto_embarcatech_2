`timescale 1ns/1ps

module uart_echo_tb;

    localparam CLK_FREQ = 8;
    localparam BAUD_RATE = 1;

    // Sinais do Testbench
    logic       i_clk;
    logic       i_reset_n;
    logic       i_uart_rx;
    logic       i_uart_tx;
    logic [7:0] send_byte;

    uart_echo_colorlight_i9 #(
        .clk_freq(CLK_FREQ),
        .baud_rate(BAUD_RATE)
    ) dut (
        .clk(i_clk),
        .reset_n(i_reset_n),
        .uart_rx(i_uart_rx),
        .uart_tx(i_uart_tx)
    );

    // Geração de clock (100 MHz)
    initial i_clk = 0;
    always #5 i_clk = ~i_clk;

    // Bloco de estímulo principal
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, uart_echo_tb);
        // 1. Inicializa os sinais
        i_reset_n   = 1'b0; // Ativa o reset (ativo em baixo)
        i_uart_rx = 1'b1;

        // 2. Aguarda um tempo e libera o reset
        #100;
        i_reset_n = 1'b1;

        // 3. Aguarda alguns ciclos para estabilização após o reset
        repeat(8) @(posedge i_clk);

        // start bit
        i_uart_rx = 1'b0;
        repeat(8) @(posedge i_clk);

        // data bit
        send_byte = 8'hAA;
        for (int i = 0; i < 8; i++) begin
        
            i_uart_rx = send_byte[i];
            repeat (8) @(posedge i_clk);
        end

        send_byte = 8'b1001_1101;
        for (int i = 0; i < 8; i++) begin
        
            i_uart_rx = send_byte[i];
            repeat (8) @(posedge i_clk);
        end

        // 5. Aguarda tempo suficiente para a transmissão completa ser visível
        //    (1 start bit + 8 data bits + 1 stop bit = 10 bits)
        //    10 bits * 8 clocks/bit = 80 clocks. Vamos esperar um pouco mais.
        repeat(100) @(posedge i_clk);

        $finish;
    end

endmodule
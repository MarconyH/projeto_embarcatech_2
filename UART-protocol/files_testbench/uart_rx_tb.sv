`timescale 1ns/1ps

module uart_rx_tb;

    // Sinais do Testbench
    logic       i_clk;
    logic       i_reset_n;
    logic       i_rx_serial;
    logic       o_rx_dv;
    logic       [7:0] o_rx_byte;

    uart_rx #(
        .CLKS_PER_BIT(8)
    ) dut (
        .i_clk(i_clk),
        .i_rst_n(i_reset_n),
        .i_rx_serial(i_rx_serial),
        .o_rx_dv(o_rx_dv),
        .o_rx_byte(o_rx_byte)
    );

    // Geração de clock (100 MHz)
    initial i_clk = 0;
    always #5 i_clk = ~i_clk;

    // Bloco de estímulo principal
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, uart_rx_tb);
        // 1. Inicializa os sinais
        i_reset_n   = 1'b0; // Ativa o reset (ativo em baixo)
        i_rx_serial = 1'b1;

        // 2. Aguarda um tempo e libera o reset
        #100;
        i_reset_n = 1'b1;

        // 3. Aguarda alguns ciclos para estabilização após o reset
        repeat(8) @(posedge i_clk);

        // start bit
        i_rx_serial = 1'b0;

        // data bit
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b1;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b0;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b0;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b1;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b1;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b0;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b1;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b0;
        repeat(8) @(posedge i_clk);
        i_rx_serial = 1'b1;

        // 5. Aguarda tempo suficiente para a transmissão completa ser visível
        //    (1 start bit + 8 data bits + 1 stop bit = 10 bits)
        //    10 bits * 8 clocks/bit = 80 clocks. Vamos esperar um pouco mais.
        repeat(100) @(posedge i_clk);

        $finish;
    end

endmodule
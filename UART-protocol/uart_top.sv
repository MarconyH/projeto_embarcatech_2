module uart_top #(
    parameter CLK_FREQ_HZ = 50_000_000,  // Clock do sistema
    parameter BAUD_RATE   = 115200        // Taxa de transmissão
) (
    // Sinais do sistema
    input  logic       i_clk,          // Clock 50 MHz
    input  logic       i_rst_n,        // Reset assíncrono ativo baixo
    
    // Interface UART física (conectar ao Raspberry Pi Pico)
    input  logic       i_uart_rx,      // Recebe do Pico TX
    output logic       o_uart_tx,      // Envia para Pico RX
    
    // Interface de transmissão (conectar à lógica do usuário)
    input  logic       i_tx_dv,        // Data Valid: inicia transmissão
    input  logic [7:0] i_tx_byte,      // Byte a transmitir
    output logic       o_tx_active,    // TX em andamento
    output logic       o_tx_done,      // TX completo (pulso)
    
    // Interface de recepção (conectar à lógica do usuário)
    output logic       o_rx_dv,        // Data Valid: dado recebido
    output logic [7:0] o_rx_byte       // Byte recebido
);

    // Calcula CLKS_PER_BIT
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    
    // Instancia transmissor UART
    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_tx_inst (
        .i_clk       (i_clk),
        .i_rst_n     (i_rst_n),
        .i_tx_dv     (i_tx_dv),
        .i_tx_byte   (i_tx_byte),
        .o_tx_serial (o_uart_tx),
        .o_tx_active (o_tx_active),
        .o_tx_done   (o_tx_done)
    );
    
    // Instancia receptor UART
    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_rx_inst (
        .i_clk       (i_clk),
        .i_rst_n     (i_rst_n),
        .i_rx_serial (i_uart_rx),
        .o_rx_dv     (o_rx_dv),
        .o_rx_byte   (o_rx_byte)
    );

endmodule

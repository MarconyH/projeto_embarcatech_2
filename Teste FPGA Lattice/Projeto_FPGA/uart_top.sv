// uart_top.sv
// UART Top-Level Module - SystemVerilog
// Integração e cálculo de CLKS_PER_BIT para 25 MHz.

module uart_top #(
    parameter CLK_FREQ_HZ = 25_000_000,  // Clock do sistema (25 MHz - Colorlight i9)
    parameter BAUD_RATE   = 115200        // Taxa de transmissão
) (
    // Sinais do sistema
    input  logic       i_clk,          
    input  logic       i_rst_n,        
    
    // Interface UART física
    input  logic       i_uart_rx,      
    output logic       o_uart_tx,      
    
    // Interface de transmissão
    input  logic       i_tx_dv,        
    input  logic [7:0] i_tx_byte,      
    output logic       o_tx_active,    
    output logic       o_tx_done,      
    
    // Interface de recepção
    output logic       o_rx_dv,        
    output logic [7:0] o_rx_byte       
);

    // Calcula CLKS_PER_BIT: 25,000,000 / 115,200 ≈ 217
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
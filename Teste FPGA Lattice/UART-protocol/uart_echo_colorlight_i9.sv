// uart_echo_colorlight_i9.sv
// FPGA Echo: Recebe texto via UART e retorna o mesmo texto
module uart_echo_colorlight_i9 (
    input  logic       clk_50mhz,    // P3 (25 MHz real)
    input  logic       reset_n,      // D1
    input  logic       uart_rx,      // D2 <- Pico TX (GP0)
    output logic       uart_tx,      // E2 -> Pico RX (GP1)
    output logic [3:0] leds,         // Status
    output logic       led_rx_active,
    output logic       led_tx_active
);

    logic       rx_dv;
    logic [7:0] rx_byte;
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active, tx_done;
    
    uart_top #(
        .CLK_FREQ_HZ(25_000_000),
        .BAUD_RATE(115200)
    ) uart_inst (
        .i_clk(clk_50mhz),
        .i_rst_n(reset_n),
        .i_uart_rx(uart_rx),
        .o_uart_tx(uart_tx),
        .i_tx_dv(tx_dv),
        .i_tx_byte(tx_byte),
        .o_tx_active(tx_active),
        .o_tx_done(tx_done),
        .o_rx_dv(rx_dv),
        .o_rx_byte(rx_byte)
    );
    
    // Echo direto
    assign tx_dv = rx_dv;
    assign tx_byte = rx_byte;
    
    // Contador de bytes para LEDs
    logic [3:0] byte_count;
    
    always_ff @(posedge clk_50mhz or negedge reset_n) begin
        if (!reset_n) begin
            byte_count <= 4'b0000;
            leds <= 4'b0000;
        end else if (rx_dv) begin
            byte_count <= byte_count + 1'b1;
            leds <= byte_count;
        end
    end
    
    assign led_rx_active = rx_dv;
    assign led_tx_active = tx_active;

endmodule

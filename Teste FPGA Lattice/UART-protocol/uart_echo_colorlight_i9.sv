module uart_echo_colorlight_i9 (
    input  logic       clk_50mhz,    // P3 (25 MHz real)
    input  logic       reset_n,      // D1
    input  logic       uart_rx,      // D2 <- Pico TX (GP0)
    output logic       uart_tx       // E2 -> Pico RX (GP1)
);

    // ========================================
    // POWER-ON RESET: Gera reset interno automático
    // ========================================
    logic [7:0] reset_counter = 8'd0;
    logic reset_n_internal = 1'b0;
    
    always_ff @(posedge clk_50mhz) begin
        if (reset_counter < 8'd255) begin
            reset_counter <= reset_counter + 1'b1;
            reset_n_internal <= 1'b0;
        end else begin
            reset_n_internal <= 1'b1;
        end
    end

    logic       rx_dv;
    logic [7:0] rx_byte;
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active, tx_done;
    
    // TESTE COM BAUD RATE REDUZIDO: 9600 baud (mais tolerante)
    // CLKS_PER_BIT = 25_000_000 / 9600 = 2604 ciclos/bit
    uart_top #(
        .CLK_FREQ_HZ(25_000_000),
        .BAUD_RATE(9600)
    ) uart_inst (
        .i_clk(clk_50mhz),
        .i_rst_n(reset_n_internal),     // USA RESET INTERNO
        .i_uart_rx(uart_rx),           // RX conectado
        .o_uart_tx(uart_tx),
        .i_tx_dv(tx_dv),
        .i_tx_byte(tx_byte),
        .o_tx_active(tx_active),
        .o_tx_done(tx_done),
        .o_rx_dv(rx_dv),               // RX conectado
        .o_rx_byte(rx_byte)            // RX conectado
    );
    
    // ========================================
    // LÓGICA DE ECHO - ATIVADA
    // Quando recebe byte via UART, envia de volta
    // ========================================
    logic rx_received;
    always_ff @(posedge clk_50mhz or negedge reset_n_internal) begin
        if (!reset_n_internal) begin
            tx_dv <= 1'b0;
            tx_byte <= 8'h00;
            rx_received <= 1'b0;
        end else begin
            tx_dv <= 1'b0;
            
            // Quando recebe novo byte e não está processando anterior
            if (rx_dv && !rx_received) begin
                tx_dv <= 1'b1;
                tx_byte <= rx_byte;
                rx_received <= 1'b1;
            end
            
            // Reseta flag quando rx_dv desliga
            if (!rx_dv && rx_received) begin
                rx_received <= 1'b0;
            end
        end
    end

endmodule

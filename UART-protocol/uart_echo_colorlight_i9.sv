module uart_echo_colorlight_i9 #(
    parameter clk_freq = 25_000_000,
    parameter baud_rate = 9600
)(
    input  logic       clk,
    input  logic       reset_n,
    input  logic       uart_rx,
    output logic       uart_tx
);

    // `define TESTE_TX_MANUAL

    logic       rx_dv;
    logic [7:0] rx_byte;      
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active, tx_done;
    
    uart_top #(
        .CLK_FREQ_HZ(clk_freq),
        .BAUD_RATE(baud_rate)

    ) uart_inst (
        .i_clk(clk),
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
    
`ifdef TESTE_TX_MANUAL
    logic [31:0] timer_counter;
    logic [7:0]  test_char;
    localparam TIMER_500MS = 25_000_000 / 2;
    
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            timer_counter <= 32'd0;
            test_char <= 8'd65;
            tx_dv <= 1'b0;
            tx_byte <= 8'h00;
        end else begin
            tx_dv <= 1'b0;
            if (timer_counter < TIMER_500MS) begin
                timer_counter <= timer_counter + 1'b1;
            end else begin
                timer_counter <= 32'd0;
                if (!tx_active) begin
                    tx_dv <= 1'b1;
                    tx_byte <= test_char;
                    if (test_char < 8'd90) begin
                        test_char <= test_char + 1'b1;
                    end else begin
                        test_char <= 8'd65;
                    end
                end
            end
        end
    end
    
`else
    // ECHO COM HEADER DE SINCRONIZAÇÃO
    localparam HEADER_BYTE = 8'hAA;
    
    typedef enum logic [1:0] {
        WAIT_HEADER,
        ECHO_DATA
    } state_t;
    
    state_t state;
    logic       header_received;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= WAIT_HEADER;
            tx_dv <= 1'b0;
            tx_byte <= 8'h00;
            header_received <= 1'b0;
        end else begin
            tx_dv <= 1'b0;

            case (state)
                WAIT_HEADER: begin
                    // aguarda header (não armazena nem ecoa aqui)
                    if (rx_dv && rx_byte == HEADER_BYTE) begin
                        header_received <= 1'b1;
                        state <= ECHO_DATA;
                    end
                end
                
                ECHO_DATA: begin
                    // Echo imediato: quando receber um byte (rx_dv),
                    // se TX estiver livre, transmite imediatamente.
                    if (rx_dv) begin
                        if (!tx_active) begin
                            tx_dv <= 1'b1;
                            tx_byte <= rx_byte;
                        end
                        // se tx_active == 1, descartamos o byte (simplicidade)
                    end
                end
            endcase
        end
    end
`endif

endmodule
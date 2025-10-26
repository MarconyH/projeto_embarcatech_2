module uart_echo_colorlight_i9 (
    input  logic       clk_50mhz,
    input  logic       reset_n,
    input  logic       uart_rx,
    output logic       uart_tx
);

    // `define TESTE_TX_MANUAL
    
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
    
    uart_top #(
        .CLK_FREQ_HZ(25_000_000),
        .BAUD_RATE(9600)
    ) uart_inst (
        .i_clk(clk_50mhz),
        .i_rst_n(reset_n_internal),
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
    
    always_ff @(posedge clk_50mhz or negedge reset_n_internal) begin
        if (!reset_n_internal) begin
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
        IDLE,
        WAIT_HEADER_ECHO,
        ECHO_DATA
    } state_t;
    
    state_t state;
    logic [7:0] rx_fifo [0:7];  // FIFO aumentado para 8 bytes
    logic [2:0] rx_fifo_wr_ptr;
    logic [2:0] rx_fifo_rd_ptr;
    logic [2:0] next_wr_ptr;
    logic       rx_fifo_empty;
    logic       header_received;
    
    assign rx_fifo_empty = (rx_fifo_wr_ptr == rx_fifo_rd_ptr);
    assign next_wr_ptr = rx_fifo_wr_ptr + 3'b001;

    always_ff @(posedge clk_50mhz or negedge reset_n_internal) begin
        if (!reset_n_internal) begin
            state <= IDLE;
            tx_dv <= 1'b0;
            tx_byte <= 8'h00;
            rx_fifo_wr_ptr <= 3'b000;
            rx_fifo_rd_ptr <= 3'b000;
            header_received <= 1'b0;
            for (int i = 0; i < 8; i++) rx_fifo[i] <= 8'h00;
        end else begin
            tx_dv <= 1'b0;

            case (state)
                IDLE: begin
                    if (rx_dv && rx_byte == HEADER_BYTE) begin
                        header_received <= 1'b1;
                        state <= WAIT_HEADER_ECHO;
                    end
                end
                
                WAIT_HEADER_ECHO: begin
                    if (!tx_active) begin
                        tx_dv <= 1'b1;
                        tx_byte <= HEADER_BYTE;  // Echo header
                        state <= ECHO_DATA;
                    end
                end
                
                ECHO_DATA: begin
                    // Escreve dados no FIFO
                    if (rx_dv) begin
                        if (next_wr_ptr != rx_fifo_rd_ptr) begin
                            rx_fifo[rx_fifo_wr_ptr] <= rx_byte;
                            rx_fifo_wr_ptr <= next_wr_ptr;
                        end
                    end
                    
                    // Lê FIFO e transmite
                    if (!rx_fifo_empty && !tx_active) begin
                        tx_dv <= 1'b1;
                        tx_byte <= rx_fifo[rx_fifo_rd_ptr];
                        rx_fifo_rd_ptr <= rx_fifo_rd_ptr + 3'b001;
                    end
                end
            endcase
        end
    end
`endif

endmodule
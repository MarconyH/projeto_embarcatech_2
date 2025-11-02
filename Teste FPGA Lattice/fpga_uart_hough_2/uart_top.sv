// =======================================================
// uart_top.sv - Recepção matriz via UART com HEADER/FOOTER
// Integra Sobel e Hough - Parametrizável N x N
// =======================================================
module uart_top #(
    parameter N = 16           // Tamanho da matriz N x N
)(
    input  logic clk,
    input  logic reset_n,
    input  logic uart_rx,
    output logic uart_tx,
    output logic led
);

    // -------------------------------
    // UART RX/TX
    // -------------------------------
    logic [7:0] rx_data;
    logic       rx_valid;
    logic [7:0] tx_data;
    logic       tx_start;
    logic       tx_busy;

    uart_rx_module u_rx (
        .clk(clk),
        .reset_n(reset_n),
        .rx(uart_rx),
        .data_out(rx_data),
        .data_valid(rx_valid)
    );

    uart_tx_module u_tx (
        .clk(clk),
        .reset_n(reset_n),
        .tx(uart_tx),
        .data_in(tx_data),
        .start(tx_start),
        .busy(tx_busy)
    );

    // -------------------------------
    // Memória matriz N x N
    // -------------------------------
    localparam MATRIX_SIZE = N*N;
    logic [7:0] matrix_mem [0:MATRIX_SIZE-1];
    logic [15:0] matrix_index;
    logic matrix_full;

    // -------------------------------
    // FSM Recepção UART com HEADER/FOOTER
    // -------------------------------
    typedef enum logic [1:0] {
        WAIT_HEADER,
        RECEIVE_MATRIX,
        WAIT_FOOTER
    } uart_state_t;
    uart_state_t uart_state;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            uart_state   <= WAIT_HEADER;
            matrix_index <= 0;
            matrix_full  <= 0;
        end else if (rx_valid) begin
            case (uart_state)
                WAIT_HEADER: begin
                    if (rx_data == 8'hAA) begin
                        uart_state <= RECEIVE_MATRIX;
                        matrix_index <= 0;
                        matrix_full <= 0;
                    end
                end
                RECEIVE_MATRIX: begin
                    matrix_mem[matrix_index] <= rx_data;
                    matrix_index <= matrix_index + 1;
                    if (matrix_index == MATRIX_SIZE-1)
                        uart_state <= WAIT_FOOTER;
                end
                WAIT_FOOTER: begin
                    if (rx_data == 8'h55) begin
                        matrix_full <= 1;
                        uart_state <= WAIT_HEADER; // pronto para próxima matriz
                    end
                end
            endcase
        end
    end

    assign led = matrix_full;

    // -------------------------------
    // Flatten matriz para Sobel
    // -------------------------------
    logic [8*MATRIX_SIZE-1:0] matrix_flat;
    integer k;
    always_comb begin
        for (k=0; k<MATRIX_SIZE; k++)
            matrix_flat[k*8 +: 8] = matrix_mem[k];
    end

    // -------------------------------
    // Sobel Filter
    // -------------------------------
    logic [8*MATRIX_SIZE-1:0] edge_map_flat;
    logic sobel_done;

    sobel_filter_seq #(.N(N)) sobel_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(matrix_full),
        .matrix_in_flat(matrix_flat),
        .edge_map(edge_map_flat),
        .done(sobel_done)
    );

    // -------------------------------
    // Hough Transform
    // -------------------------------
    logic hough_done;
    logic [15:0] rho;
    logic [15:0] theta;

    hough_minimal_seq #(.N(N)) hough_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(sobel_done),
        .edge_map_flat(edge_map_flat),
        .done(hough_done),
        .rho(rho),
        .theta(theta)
    );

    // -------------------------------
    // UART Transmission FSM (ASCII debug)
    // -------------------------------
    typedef enum logic [1:0] {IDLE, SEND_RHO, SEND_THETA} tx_state_t;
    tx_state_t tx_state;
    logic [7:0] tx_buffer;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tx_start <= 0;
            tx_data  <= 0;
            tx_state <= IDLE;
        end else begin
            tx_start <= 0;
            case(tx_state)
                IDLE: begin
                    if (hough_done && !tx_busy) begin
                        tx_data <= "R"; // ASCII start marker
                        tx_start <= 1;
                        tx_state <= SEND_RHO;
                    end
                end
                SEND_RHO: begin
                    if (!tx_busy) begin
                        tx_data <= rho[7:0]; // envia rho LSB
                        tx_start <= 1;
                        tx_state <= SEND_THETA;
                    end
                end
                SEND_THETA: begin
                    if (!tx_busy) begin
                        tx_data <= theta[7:0]; // envia theta LSB
                        tx_start <= 1;
                        tx_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule

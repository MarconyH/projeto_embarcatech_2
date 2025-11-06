// uart_top.sv - recebe blocos 8x8 para montar 32x32, processa e retorna RGB image
module uart_top #(
    parameter IMG_W = 32,
    parameter IMG_H = 32,
    parameter BLOCK_W = 8,
    parameter BLOCK_H = 8
)(
    input  logic clk,
    input  logic reset_n,
    input  logic uart_rx,
    output logic uart_tx,
    output logic led
);

    // Derived params
    localparam BLOCKS_PER_ROW = IMG_W / BLOCK_W;
    localparam BLOCKS_PER_COL = IMG_H / BLOCK_H;
    localparam TOTAL_BLOCKS = BLOCKS_PER_ROW * BLOCKS_PER_COL;
    localparam MATRIX_SIZE = IMG_W * IMG_H;
    localparam COLOR_BYTES = MATRIX_SIZE * 3; // RGB per pixel

    // UART RX/TX instances
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

    // Storage for full grayscale image
    logic [7:0] full_image [0:MATRIX_SIZE-1];
    // Edge map flattened (connected to sobel)
    logic [8*MATRIX_SIZE-1:0] matrix_flat;
    logic [8*MATRIX_SIZE-1:0] edge_map_flat;

    // Color output buffer
    logic [7:0] color_image [0:COLOR_BYTES-1];

    // Received-block bitmap
    logic [TOTAL_BLOCKS-1:0] blocks_received;
    integer i;

    // FSM states for RX
    typedef enum logic [2:0] {IDLE, WAIT_META, READ_BLOCK, WAIT_FOOTER} rx_state_t;
    rx_state_t rx_state;

    // temp holders
    integer block_id;
    integer total_blocks_expected;
    integer byte_index; // inside block
    integer block_base;
    integer r,c;

    // matrix_full flag triggers processing
    logic matrix_full;

    // Initialize
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_state <= IDLE;
            blocks_received <= '0;
            block_id <= 0;
            total_blocks_expected <= 0;
            byte_index <= 0;
            matrix_full <= 0;
        end else begin
            if (rx_valid) begin
                case (rx_state)
                    IDLE: begin
                        if (rx_data == 8'hAA) begin
                            rx_state <= WAIT_META;
                        end
                    end
                    WAIT_META: begin
                        // next byte = block_id
                        block_id <= rx_data;
                        rx_state <= READ_BLOCK;
                        byte_index <= 0;
                    end
                    READ_BLOCK: begin
                        // Expect total_blocks in first byte after block_id? we kept total_blocks at next position earlier
                        // But we used header, then block_id, then total_blocks, then payload.
                        // Because here we consumed block_id already, we need next byte to be total_blocks.
                        // So handle that: if byte_index == 0 treat rx_data as total_blocks
                        if (byte_index == 0) begin
                            total_blocks_expected <= rx_data;
                            byte_index <= byte_index + 1;
                        end else begin
                            // reading payload: index payload_index = byte_index - 1
                            int payload_index = byte_index - 1;
                            // compute base address
                            int br = block_id / BLOCKS_PER_ROW;
                            int bc = block_id % BLOCKS_PER_ROW;
                            int base = (br * BLOCK_H) * IMG_W + (bc * BLOCK_W);
                            // map payload_index (0..(BLOCK_W*BLOCK_H-1)) into full_image
                            int local_row = payload_index / BLOCK_W;
                            int local_col = payload_index % BLOCK_W;
                            int dest = base + local_row * IMG_W + local_col;
                            full_image[dest] <= rx_data;
                            byte_index <= byte_index + 1;
                            if (payload_index == (BLOCK_W*BLOCK_H - 1)) begin
                                // finished block payload; set bit
                                blocks_received[block_id] <= 1'b1;
                                rx_state <= WAIT_FOOTER;
                            end
                        end
                    end
                    WAIT_FOOTER: begin
                        if (rx_data == 8'h55) begin
                            rx_state <= IDLE;
                            // check if all blocks received
                            if (&blocks_received[0 +: TOTAL_BLOCKS]) begin
                                matrix_full <= 1'b1;
                            end
                        end
                    end
                    default: rx_state <= IDLE;
                endcase
            end
        end
    end

    // Create matrix_flat (flatten) for Sobel input
    always_comb begin
        for (i=0; i<MATRIX_SIZE; i=i+1) begin
            matrix_flat[i*8 +: 8] = full_image[i];
        end
    end

    // Sobel and Hough instantiations (N = IMG_W)
    logic sobel_done;
    logic hough_done;
    logic [15:0] rho;
    logic [15:0] theta;

    sobel_filter_seq #(.N(IMG_W)) sobel_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(matrix_full),
        .matrix_in_flat(matrix_flat),
        .edge_map_flat(edge_map_flat),
        .done(sobel_done)
    );

    hough_minimal_seq #(.N(IMG_W)) hough_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(sobel_done),
        .edge_map_flat(edge_map_flat),
        .done(hough_done),
        .rho(rho),
        .theta(theta)
    );

    // After Hough done, generate color_image based on edge_map_flat and theta
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // clear
            for (i=0;i<COLOR_BYTES;i=i+1) color_image[i] <= 8'd0;
        end else begin
            if (hough_done) begin
                // Choose color by theta ranges
                for (i=0;i<MATRIX_SIZE;i=i+1) begin
                    logic [7:0] e = edge_map_flat[i*8 +: 8];
                    if (e == 0) begin
                        // background black
                        color_image[i*3 + 0] <= 8'd0;
                        color_image[i*3 + 1] <= 8'd0;
                        color_image[i*3 + 2] <= 8'd0;
                    end else begin
                        // map theta to color
                        if (theta < 16'd45) begin
                            color_image[i*3 + 0] <= 8'd255; // R
                            color_image[i*3 + 1] <= 8'd0;
                            color_image[i*3 + 2] <= 8'd0;
                        end else if (theta < 16'd90) begin
                            color_image[i*3 + 0] <= 8'd0;
                            color_image[i*3 + 1] <= 8'd255; // G
                            color_image[i*3 + 2] <= 8'd0;
                        end else if (theta < 16'd135) begin
                            color_image[i*3 + 0] <= 8'd0;
                            color_image[i*3 + 1] <= 8'd0;
                            color_image[i*3 + 2] <= 8'd255; // B
                        end else begin
                            color_image[i*3 + 0] <= 8'd255;
                            color_image[i*3 + 1] <= 8'd255;
                            color_image[i*3 + 2] <= 8'd0; // Y
                        end
                    end
                end
            end
        end
    end

    // TX FSM to stream back the color image after hough_done
    typedef enum logic [2:0] {TX_IDLE, TX_HEADER, TX_DIM, TX_PIXELS, TX_FOOTER} txfsm_t;
    txfsm_t txfsm;
    integer tx_idx;
    integer tx_total;
    reg [1:0] send_stage;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            txfsm <= TX_IDLE;
            tx_start <= 0;
            tx_data <= 8'd0;
            tx_idx <= 0;
            led <= 0;
        end else begin
            tx_start <= 0;
            case (txfsm)
                TX_IDLE: begin
                    led <= 0;
                    if (hough_done) begin
                        txfsm <= TX_HEADER;
                        tx_idx <= 0;
                        led <= 1;
                    end
                end
                TX_HEADER: begin
                    if (!tx_busy) begin
                        tx_data <= 8'hCC;
                        tx_start <= 1;
                        txfsm <= TX_DIM;
                    end
                end
                TX_DIM: begin
                    if (!tx_busy) begin
                        // send width (16-bit big-endian) then height
                        // We'll send two bytes width then two bytes height
                        tx_data <= (IMG_W >> 8) & 8'hFF; tx_start <= 1;
                        txfsm <= TX_PIXELS;
                        tx_idx <= 0;
                    end
                end
                TX_PIXELS: begin
                    // We need to send remaining three bytes: width LSB, height MSB, height LSB before pixel loop
                    if (!tx_busy) begin
                        // Send width LSB then height MSB and LSB in subsequent cycles
                        if (tx_idx == 0) begin
                            tx_data <= IMG_W & 8'hFF; tx_start <= 1; tx_idx <= tx_idx + 1;
                        end else if (tx_idx == 1) begin
                            tx_data <= (IMG_H >> 8) & 8'hFF; tx_start <= 1; tx_idx <= tx_idx + 1;
                        end else if (tx_idx == 2) begin
                            tx_data <= IMG_H & 8'hFF; tx_start <= 1; tx_idx <= 0; tx_total <= 0;
                        end else begin
                            // Should not happen
                            tx_idx <= 0;
                        end
                        // After the three bytes above, we will stream pixels from a separate counter
                        if (tx_idx == 0) begin
                            txfsm <= TX_PIXELS; // continue
                        end
                    end

                    // Now stream pixels - we wait until tx_busy is free and then push bytes in sequence
                    if (!tx_busy && tx_total < COLOR_BYTES) begin
                        tx_data <= color_image[tx_total];
                        tx_start <= 1;
                        tx_total <= tx_total + 1;
                    end else if (tx_total >= COLOR_BYTES) begin
                        txfsm <= TX_FOOTER;
                    end
                end
                TX_FOOTER: begin
                    if (!tx_busy) begin
                        tx_data <= 8'h33;
                        tx_start <= 1;
                        txfsm <= TX_IDLE;
                    end
                end
                default: txfsm <= TX_IDLE;
            endcase
        end
    end

endmodule

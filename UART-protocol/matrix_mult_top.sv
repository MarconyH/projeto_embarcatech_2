module matrix_mult_top (
    input  logic       clk_50mhz,  // system clock (connected to clk_50mhz in LPF)
    input  logic       reset_n,    // active low
    input  logic       uart_rx,    // from Pico TX (GP0)
    output logic       uart_tx     // to Pico RX (GP1)
);

    // parameters
    localparam ADDR_WIDTH = 8;
    localparam TOTAL_BYTES = (1 << ADDR_WIDTH); // 256
    localparam BAUD_RATE = 9600;
    localparam CLK_FREQ_HZ = 25_000_000;

    // UART interface signals
    logic rx_dv;
    logic [7:0] rx_byte;

    logic tx_dv;
    logic [7:0] tx_byte;
    logic tx_active;
    logic tx_done;

    // Memories: A, B, Result
    logic memA_we;
    logic [ADDR_WIDTH-1:0] memA_waddr;
    logic [7:0] memA_wdata;
    logic [ADDR_WIDTH-1:0] memA_raddr;
    logic [7:0] memA_rdata;

    logic memB_we;
    logic [ADDR_WIDTH-1:0] memB_waddr;
    logic [7:0] memB_wdata;
    logic [ADDR_WIDTH-1:0] memB_raddr;
    logic [7:0] memB_rdata;

    logic memR_we;
    logic [ADDR_WIDTH-1:0] memR_waddr;
    logic [7:0] memR_wdata;
    logic [ADDR_WIDTH-1:0] memR_raddr;
    logic [7:0] memR_rdata;

    // matrix_mult control
    logic mm_start;
    logic mm_done;
    logic [7:0] mm_a_raddr;
    logic [7:0] mm_b_raddr;
    logic mm_res_we;
    logic [7:0] mm_res_waddr;
    logic [7:0] mm_res_wdata;
    logic [7:0] mm_a_rdata;
    logic [7:0] mm_b_rdata;

    // Instantiate UART top (connect to physical pins)
    uart_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_inst (
        .i_clk       (clk_50mhz),
        .i_rst_n     (reset_n),
        .i_uart_rx   (uart_rx),
        .o_uart_tx   (uart_tx),

        .i_tx_dv     (tx_dv),
        .i_tx_byte   (tx_byte),
        .o_tx_active (tx_active),
        .o_tx_done   (tx_done),

        .o_rx_dv     (rx_dv),
        .o_rx_byte   (rx_byte)
    );

    // Instantiate memories (synchronous read)
    matrix_mem #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(8)) memA (
        .clk(clk_50mhz), .rst_n(reset_n),
        .we(memA_we), .waddr(memA_waddr), .wdata(memA_wdata),
        .raddr(memA_raddr), .rdata(memA_rdata)
    );

    matrix_mem #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(8)) memB (
        .clk(clk_50mhz), .rst_n(reset_n),
        .we(memB_we), .waddr(memB_waddr), .wdata(memB_wdata),
        .raddr(memB_raddr), .rdata(memB_rdata)
    );

    matrix_mem #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(8)) memR (
        .clk(clk_50mhz), .rst_n(reset_n),
        .we(memR_we), .waddr(memR_waddr), .wdata(memR_wdata),
        .raddr(memR_raddr), .rdata(memR_rdata)
    );

    // Instantiate matrix multiplier (reads A/B, writes result)
    matrix_mult mm_inst (
        .clk(clk),
        .rst_n(reset_n),
        .start(mm_start),

        .a_raddr(mm_a_raddr),
        .a_rdata(mm_a_rdata),

        .b_raddr(mm_b_raddr),
        .b_rdata(mm_b_rdata),

        .res_we(mm_res_we),
        .res_waddr(mm_res_waddr),
        .res_wdata(mm_res_wdata),

        .done(mm_done)
    );

    // connect mm read/write ports to memories
    assign memA_raddr = mm_a_raddr;
    assign mm_a_rdata = memA_rdata;
    assign memB_raddr = mm_b_raddr;
    assign mm_b_rdata = memB_rdata;

    // connect mm result write to result memory
    assign memR_we    = mm_res_we;
    assign memR_waddr = mm_res_waddr;
    assign memR_wdata = mm_res_wdata;

    // Top FSM: receive -> start mult -> send result
    typedef enum logic [2:0] {
        S_IDLE,
        S_RECV,        // receive TOTAL_BYTES from UART and write to memA & memB
        S_START_MM,    // pulse mm_start 1 cycle
        S_WAIT_MM,     // wait mm_done
        S_SEND_ADDR,   // set memR_raddr for next byte
        S_SEND_WAIT,   // wait one cycle for memR_rdata valid
        S_SEND_TX,     // issue tx_dv when uart tx free
        S_DONE
    } top_state_t;

    top_state_t state, next_state;

    logic [ADDR_WIDTH-1:0] write_ptr;
    logic [ADDR_WIDTH-1:0] read_ptr;

    // tx staging (because mem read is synchronous)
    logic [7:0] send_data;
    logic       have_send_data; // indicates send_data valid

    // start pulse single-cycle
    logic start_pulse;

    // sequential state updates
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_IDLE;
            write_ptr <= '0;
            read_ptr <= '0;
            memA_we <= 1'b0;
            memB_we <= 1'b0;
            memA_waddr <= '0;
            memB_waddr <= '0;
            memA_wdata <= '0;
            memB_wdata <= '0;
            mm_start <= 1'b0;
            start_pulse <= 1'b0;
            have_send_data <= 1'b0;
            tx_dv <= 1'b0;
            tx_byte <= 8'h00;
            memR_raddr <= '0;
        end else begin
            // default deasserts
            memA_we <= 1'b0;
            memB_we <= 1'b0;
            mm_start <= 1'b0;
            start_pulse <= 1'b0;
            tx_dv <= 1'b0;

            case (state)
                S_IDLE: begin
                    write_ptr <= '0;
                    read_ptr <= '0;
                    have_send_data <= 1'b0;
                    if (1) begin
                        // automatically start receiving as soon as module up
                        // (alternatively wait for explicit command)
                        next_state <= S_RECV;
                    end
                end

                S_RECV: begin
                    if (rx_dv) begin
                        // write incoming byte to both A and B (so result = A * A)
                        memA_we <= 1'b1;
                        memA_waddr <= write_ptr;
                        memA_wdata <= rx_byte;

                        memB_we <= 1'b1;
                        memB_waddr <= write_ptr;
                        memB_wdata <= rx_byte;

                        write_ptr <= write_ptr + 1'b1;
                        if (write_ptr == (TOTAL_BYTES - 1)) begin
                            // all received
                            next_state <= S_START_MM;
                        end
                    end
                end

                S_START_MM: begin
                    // pulse start for matrix_mult one cycle
                    mm_start <= 1'b1;
                    next_state <= S_WAIT_MM;
                end

                S_WAIT_MM: begin
                    if (mm_done) begin
                        read_ptr <= '0;
                        have_send_data <= 1'b0;
                        next_state <= S_SEND_ADDR;
                    end
                end

                S_SEND_ADDR: begin
                    // request read from result memory (rdata available next cycle)
                    memR_raddr <= read_ptr;
                    next_state <= S_SEND_WAIT;
                end

                S_SEND_WAIT: begin
                    // latch memR_rdata to staging register
                    send_data <= memR_rdata;
                    have_send_data <= 1'b1;
                    next_state <= S_SEND_TX;
                end

                S_SEND_TX: begin
                    if (have_send_data && !tx_active) begin
                        // send staged byte
                        tx_dv <= 1'b1;
                        tx_byte <= send_data;
                        have_send_data <= 1'b0;
                        read_ptr <= read_ptr + 1'b1;
                        if (read_ptr == (TOTAL_BYTES - 1)) begin
                            next_state <= S_DONE;
                        end else begin
                            next_state <= S_SEND_ADDR;
                        end
                    end
                end

                S_DONE: begin
                    // finished: remain here (could loop back to RECV for next transaction)
                    next_state <= S_DONE;
                end

                default: next_state <= S_IDLE;
            endcase

            // advance state if next_state was set by logic above
            // but ensure we properly capture transitions: use state update at top of always_ff
            state <= next_state;
        end
    end

    // Combinational default next_state (to avoid latches)
    always_comb begin
        next_state = state;
    end

endmodule
<<<<<<< HEAD:UART-protocol/matrix_mult.sv
// matrix_mult.sv
// Coleta 8 bytes via UART (rx_dv/rx_byte) formando duas matrizes 2x2
// Ordem de preenchimento: [0,0], [0,1], [1,0], [1,1]
// Após receber A e B, calcula R = A * B (2x2) e envia os 4 bytes de R via TX
// A transmissão usa handshaking: gera tx_dv e espera tx_done antes de enviar o próximo byte.

module matrix_mult(
    input  logic        clk,
    input  logic        reset_n,    // active-low reset

    // Rx interface (entrada de dados recebidos)
    input  logic        rx_dv,      // pulso: dado válido
    input  logic [7:0]  rx_byte,

    // Tx interface (saída para uart_tx)
    output logic        tx_dv,      // pulso para iniciar transmissão
    output logic [7:0]  tx_byte,
    input  logic        tx_done,    // pulso indicando fim da transmissão
    input  logic        tx_active,  // indica TX ocupado

    output logic [2:0]  debug       // sinais de debug/status
);

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE,
        S_RECV_A,
        S_RECV_B,
        S_COMPUTE,
        S_SEND
=======
module matrix_mult (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,       // inicia operação (uma vez)
    // Memory A read port
    output logic [7:0]   a_raddr,
    input  logic [7:0]   a_rdata,
    // Memory B read port
    output logic [7:0]   b_raddr,
    input  logic [7:0]   b_rdata,
    // Result memory write port
    output logic         res_we,
    output logic [7:0]   res_waddr,
    output logic [7:0]   res_wdata,
    // Done pulse (1 cycle) when finished
    output logic         done
);

    // indices and accumulators
    logic [3:0] i, j, k;
    logic [15:0] sum;              // 16-bit accumulator
    typedef enum logic [2:0] {
        IDLE,
        SET_READ,   // drive read addresses
        WAIT_READ,  // wait one cycle for rdata
        INC_K,
        WRITE_RES,
        NEXT_J_I,
        FINISH
>>>>>>> main:Teste FPGA Lattice/UART-protocol/matrix_mult.sv
    } state_t;

    state_t state, next_state;

<<<<<<< HEAD:UART-protocol/matrix_mult.sv
    // Matrices 2x2
    logic [7:0] A [0:1][0:1];
    logic [7:0] B [0:1][0:1];
    logic [7:0] R [0:1][0:1];

    // Counters
    logic [1:0] recv_count; // 0..3
    logic [1:0] send_count; // 0..3

    // Edge detect for tx_done (rising)
    logic prev_tx_done;
    logic tx_done_rising;

    // Internal control for pulsing tx_dv one cycle
    logic tx_dv_reg;

    // Temporary wider accumulators for multiplication (to avoid overflow during sum)
    logic [15:0] tmp00, tmp01, tmp10, tmp11;

    // Next-state combinational logic (kept simple; most actions handled sequentially)
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: if (rx_dv) next_state = S_RECV_A;
            S_RECV_A: if (recv_count == 2'd3 && rx_dv) next_state = S_RECV_B;
            S_RECV_B: if (recv_count == 2'd3 && rx_dv) next_state = S_COMPUTE;
            S_COMPUTE: next_state = S_SEND;
            S_SEND: if (send_count == 2'd4 && !tx_active) next_state = S_IDLE; // after all sent and bus idle
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_IDLE;
            recv_count <= 2'd0;
            send_count <= 2'd0;
            tx_dv_reg <= 1'b0;
            prev_tx_done <= 1'b0;
            tx_byte <= 8'd0;
            // clear matrices
            A[0][0] <= 8'd0; A[0][1] <= 8'd0; A[1][0] <= 8'd0; A[1][1] <= 8'd0;
            B[0][0] <= 8'd0; B[0][1] <= 8'd0; B[1][0] <= 8'd0; B[1][1] <= 8'd0;
            R[0][0] <= 8'd0; R[0][1] <= 8'd0; R[1][0] <= 8'd0; R[1][1] <= 8'd0;
            tmp00 <= 16'd0; tmp01 <= 16'd0; tmp10 <= 16'd0; tmp11 <= 16'd0;
            debug <= 3'd0;
        end else begin
            // edge detect for tx_done
            prev_tx_done <= tx_done;
            tx_done_rising <= (tx_done && !prev_tx_done);

            // default: tx_dv only asserted by tx_dv_reg for one cycle
            tx_dv_reg <= 1'b0;

            state <= next_state;

            case (state)
                S_IDLE: begin
                    recv_count <= 2'd0;
                    send_count <= 2'd0;
                    debug <= 3'd0;
                    // start receiving on rx_dv (handled in S_RECV_A)
                end

                S_RECV_A: begin
                    debug <= 3'd1;
                    // sample on rx_dv pulse
                    if (rx_dv) begin
                        unique case (recv_count)
                            2'd0: A[0][0] <= rx_byte;
                            2'd1: A[0][1] <= rx_byte;
                            2'd2: A[1][0] <= rx_byte;
                            2'd3: A[1][1] <= rx_byte;
                        endcase
                        // increment after sampling
                        if (recv_count != 2'd3) recv_count <= recv_count + 1'b1;
                        else recv_count <= 2'd0; // prepare for next phase when next_state updates
                    end
                end

                S_RECV_B: begin
                    debug <= 3'd2;
                    if (rx_dv) begin
                        unique case (recv_count)
                            2'd0: B[0][0] <= rx_byte;
                            2'd1: B[0][1] <= rx_byte;
                            2'd2: B[1][0] <= rx_byte;
                            2'd3: B[1][1] <= rx_byte;
                        endcase
                        if (recv_count != 2'd3) recv_count <= recv_count + 1'b1;
                        else recv_count <= 2'd0;
                    end
                end

                S_COMPUTE: begin
                    debug <= 3'd3;
                    // perform 2x2 multiply using 16-bit accumulators
                    tmp00 <= (A[0][0] * B[0][0]) + (A[0][1] * B[1][0]);
                    tmp01 <= (A[0][0] * B[0][1]) + (A[0][1] * B[1][1]);
                    tmp10 <= (A[1][0] * B[0][0]) + (A[1][1] * B[1][0]);
                    tmp11 <= (A[1][0] * B[0][1]) + (A[1][1] * B[1][1]);

                    // store truncated (lower 8 bits) as result bytes
                    R[0][0] <= tmp00[7:0];
                    R[0][1] <= tmp01[7:0];
                    R[1][0] <= tmp10[7:0];
                    R[1][1] <= tmp11[7:0];

                    // prepare to send
                    send_count <= 2'd0;
                end

                S_SEND: begin
                    debug <= 3'd4;
                    // If all sent, stay here until bus idle then go to IDLE (next_state handles)
                    if (send_count < 2'd4) begin
                        // Only start a new transmit when UART not active
                        if (!tx_active && !tx_dv_reg) begin
                            // select byte to send based on send_count in order 00,01,10,11
                            unique case (send_count)
                                2'd0: tx_byte <= R[0][0];
                                2'd1: tx_byte <= R[0][1];
                                2'd2: tx_byte <= R[1][0];
                                2'd3: tx_byte <= R[1][1];
                            endcase
                            // pulse tx_dv for one cycle
                            tx_dv_reg <= 1'b1;
                        end

                        // detect tx_done rising edge to advance to next byte
                        if (tx_done_rising) begin
                            send_count <= send_count + 1'b1;
                        end
                    end
                end

                default: ;
=======
    // default outputs (done is registered below to avoid latch inference)
    logic done_reg;
    always_comb begin
        a_raddr = 8'h00;
        b_raddr = 8'h00;
        res_we  = 1'b0;
        res_waddr = 8'h00;
        res_wdata = 8'h00;
        // do not drive `done` here; it's driven by sequential logic to create a one-cycle pulse
        next_state = state;
    end

    // state registers and sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0; j <= 4'd0; k <= 4'd0;
            sum <= 16'd0;
            done_reg <= 1'b0;
        end else begin
            // default: clear done_reg each cycle; FINISH will pulse it
            done_reg <= 1'b0;
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        sum <= 16'd0;
                    end
                end

                SET_READ: begin
                    // addresses driven in combinational block via i,j,k
                end

                WAIT_READ: begin
                    // sample data and accumulate
                    // accumulation handled below (non-blocking)
                end

                INC_K: begin
                    k <= k + 1'b1;
                end

                WRITE_RES: begin
                    // res write performed (res_we asserted combinationally for one cycle)
                end

                NEXT_J_I: begin
                    if (j == 4'd15) begin
                        j <= 4'd0;
                        i <= i + 1'b1;
                    end else begin
                        j <= j + 1'b1;
                    end
                    k <= 4'd0;
                    sum <= 16'd0;
                end

                FINISH: begin
                    // pulse done for one cycle
                    done_reg <= 1'b1;
                end
>>>>>>> main:Teste FPGA Lattice/UART-protocol/matrix_mult.sv
            endcase
        end
    end

<<<<<<< HEAD:UART-protocol/matrix_mult.sv
    // output assignment for tx_dv (one-cycle pulse)
    assign tx_dv = tx_dv_reg;

endmodule
=======
    // Combinational/state transition and IO control
    always_comb begin
        // defaults (may override after)
        next_state = state;
        res_we = 1'b0;
        res_waddr = 8'h00;
        res_wdata = 8'h00;

        // compute linear addresses: addr = row*16 + col
        // A[i,k] address = i*16 + k
        // B[k,j] address = k*16 + j
        a_raddr = {4'd0, i} * 8'd16 + {4'd0, k}; // compute as 8-bit expression
        b_raddr = {4'd0, k} * 8'd16 + {4'd0, j};

        case (state)
            IDLE: begin
                if (start) next_state = SET_READ;
            end

            SET_READ: begin
                // after driving read addresses, wait one cycle to read data
                next_state = WAIT_READ;
            end

            WAIT_READ: begin
                // sample a_rdata and b_rdata and update sum (happens in sequential always_ff)
                // after sampling we go to INC_K or WRITE_RES
                if (k < 4'd15) next_state = INC_K;
                else next_state = WRITE_RES;
            end

            INC_K: begin
                next_state = SET_READ;
            end

            WRITE_RES: begin
                // write sum to result memory (store lower 8 bits, can change policy)
                res_we = 1'b1;
                res_waddr = (i * 8'd16) + j;
                res_wdata = sum[7:0]; // lower 8 bits; adjust if saturation required
                next_state = NEXT_J_I;
            end

            NEXT_J_I: begin
                if (i == 4'd15 && j == 4'd15) next_state = FINISH;
                else next_state = SET_READ;
            end

                FINISH: begin
                    // finish: transition back to IDLE (done is generated sequentially)
                    next_state = IDLE;
                end

            default: next_state = IDLE;
        endcase
    end

    // Accumulation logic: perform multiplication on WAIT_READ cycle
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 16'd0;
        end else begin
            if (state == WAIT_READ) begin
                // multiply and accumulate: a_rdata * b_rdata
                sum <= sum + (16'(a_rdata) * 16'(b_rdata));
            end else if (state == WRITE_RES) begin
                // after writing, reset sum for next element (handled in NEXT_J_I branching too)
                // Keep sum as-is; NEXT_J_I resets sum in sequential update above
            end
        end
    end

    // drive external done output from registered pulse
    assign done = done_reg;

endmodule
>>>>>>> main:Teste FPGA Lattice/UART-protocol/matrix_mult.sv

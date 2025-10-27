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
    } state_t;

    state_t state, next_state;

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
            endcase
        end
    end

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
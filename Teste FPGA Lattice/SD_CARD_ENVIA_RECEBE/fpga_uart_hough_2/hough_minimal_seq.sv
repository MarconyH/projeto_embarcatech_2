// =======================================================
// Hough Minimal FSM
// =======================================================
module hough_minimal_seq #(
    parameter N = 16
)(
    input  logic clk,
    input  logic reset_n,
    input  logic start,
    input  logic [8*N*N-1:0] edge_map_flat,
    output logic done,
    output logic [15:0] rho,
    output logic [15:0] theta
);

    // Memória local para imagem binária (edge map)
    logic [7:0] e [0:N*N-1];

    // Contadores e acumuladores
    integer idx;
    integer x_sum;
    integer count;

    // FSM
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;

    state_t state;

    // ----------------------------------------
    // FSM principal
    // ----------------------------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            idx   <= 0;
            x_sum <= 0;
            count <= 0;
            rho   <= 0;
            theta <= 0;
            done  <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done  <= 0;
                    idx   <= 0;
                    x_sum <= 0;
                    count <= 0;
                    if (start)
                        state <= LOAD;
                end

                // Carrega matriz de bordas
                LOAD: begin
                    e[idx] <= edge_map_flat[idx*8 +: 8];
                    idx <= idx + 1;
                    if (idx == N*N-1) begin
                        idx <= 0;
                        state <= PROCESS;
                    end
                end

                // Processa dados simulando detecção Hough
                PROCESS: begin
                    if (idx < N*N) begin
                        if (e[idx] > 0) begin
                            x_sum <= x_sum + (idx % N);
                            count <= count + 1;
                        end
                        idx <= idx + 1;
                    end else begin
                        if (count > 0)
                            rho <= x_sum / count;
                        else
                            rho <= N/2;
                        theta <= 16'd90;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

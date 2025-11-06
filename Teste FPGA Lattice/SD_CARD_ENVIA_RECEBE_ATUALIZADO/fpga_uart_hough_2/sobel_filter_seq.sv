// =======================================================
// Sobel Filter FSM — compatível com Yosys e FPGA Colorlight i9
// =======================================================
module sobel_filter_seq #(
    parameter N = 16
)(
    input  logic clk,
    input  logic reset_n,
    input  logic start,
    input  logic [8*N*N-1:0] matrix_in_flat,
    output logic [8*N*N-1:0] edge_map_flat,
    output logic done
);

    // Memórias internas (flattened)
    logic [7:0] m [0:N*N-1];
    logic [7:0] e [0:N*N-1];

    // Variáveis auxiliares
    integer idx;
    logic [9:0] gx, gy;
    logic [15:0] mag;

    // Estados da máquina
    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESS,
        DONE
    } state_t;

    state_t state;

    // ------------------------------------------------------
    // FSM principal
    // ------------------------------------------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            idx <= 0;
            done <= 0;
        end else begin
            case (state)
                // Espera pelo sinal de start
                IDLE: begin
                    done <= 0;
                    idx <= 0;
                    if (start)
                        state <= LOAD;
                end

                // Carrega matriz na memória
                LOAD: begin
                    m[idx] <= matrix_in_flat[idx*8 +: 8];
                    idx <= idx + 1;
                    if (idx == N*N-1) begin
                        idx <= 0;
                        state <= PROCESS;
                    end
                end

                // Processa pixel a pixel
                PROCESS: begin
                    if (idx < N*N) begin
                        if (idx > N && idx < N*(N-1) && (idx % N != 0) && (idx % N != N-1)) begin
                            gx = $signed(m[idx+1]) - $signed(m[idx-1]);
                            gy = $signed(m[idx+N]) - $signed(m[idx-N]);
                            mag = gx*gx + gy*gy;
                            e[idx] <= (mag > 16'd8192) ? 8'd255 : 8'd0;
                        end else begin
                            e[idx] <= 8'd0;
                        end
                        idx <= idx + 1;
                    end else begin
                        state <= DONE;
                    end
                end

                // Conclui o processamento
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // ------------------------------------------------------
    // Compacta matriz de saída
    // ------------------------------------------------------
    integer k;
    always_comb begin
        for (k = 0; k < N*N; k = k + 1)
            edge_map[k*8 +: 8] = e[k];
    end

endmodule

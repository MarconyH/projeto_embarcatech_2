module uart_rx_module (
    input  logic clk,
    input  logic reset_n,
    input  logic rx,
    output logic [7:0] data_out,
    output logic data_valid
);

    parameter CLK_DIV = 217; // Para 25 MHz e 115200 baud

    logic [15:0] clk_cnt;
    logic [3:0] bit_cnt;
    logic [7:0] rx_shift;
    logic receiving;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            clk_cnt <= 0;
            bit_cnt <= 0;
            receiving <= 0;
            data_out <= 0;
            data_valid <= 0;
        end else begin
            data_valid <= 0;
            if (!receiving && !rx) begin
                receiving <= 1;
                clk_cnt <= CLK_DIV/2;
                bit_cnt <= 0;
            end else if (receiving) begin
                if (clk_cnt == 0) begin
                    rx_shift[bit_cnt] <= rx;
                    bit_cnt <= bit_cnt + 1;
                    clk_cnt <= CLK_DIV-1;
                    if (bit_cnt == 7) begin
                        data_out <= rx_shift;
                        data_valid <= 1;
                        receiving <= 0;
                    end
                end else clk_cnt <= clk_cnt - 1;
            end
        end
    end
endmodule

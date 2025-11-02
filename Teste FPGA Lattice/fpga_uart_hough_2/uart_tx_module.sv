module uart_tx_module (
    input  logic clk,
    input  logic reset_n,
    input  logic [7:0] data_in,
    input  logic start,
    output logic tx,
    output logic busy
);

    parameter CLK_DIV = 868; // Para 50 MHz e 115200 baud

    logic [3:0] bit_cnt;
    logic [15:0] clk_cnt;
    logic [7:0] tx_shift;
    logic sending;

    assign busy = sending;
    assign tx = sending ? tx_shift[0] : 1'b1;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sending <= 0;
            bit_cnt <= 0;
            clk_cnt <= 0;
            tx_shift <= 0;
        end else begin
            if (start && !sending) begin
                sending <= 1;
                tx_shift <= data_in;
                bit_cnt <= 0;
                clk_cnt <= CLK_DIV-1;
            end else if (sending) begin
                if (clk_cnt == 0) begin
                    tx_shift <= {1'b1, tx_shift[7:1]};
                    bit_cnt <= bit_cnt + 1;
                    clk_cnt <= CLK_DIV-1;
                    if (bit_cnt == 8) sending <= 0;
                end else clk_cnt <= clk_cnt - 1;
            end
        end
    end
endmodule

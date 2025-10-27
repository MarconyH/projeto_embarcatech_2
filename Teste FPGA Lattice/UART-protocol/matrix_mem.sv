module matrix_mem #(
    parameter ADDR_WIDTH = 8,   // 2^8 = 256 locations (16x16)
    parameter DATA_WIDTH = 8
)(
    input  logic                     clk,
    input  logic                     rst_n,

    // Write port (synchronous)
    input  logic                     we,
    input  logic [ADDR_WIDTH-1:0]    waddr,
    input  logic [DATA_WIDTH-1:0]    wdata,

    // Read port (synchronous read)
    input  logic [ADDR_WIDTH-1:0]    raddr,
    output logic [DATA_WIDTH-1:0]    rdata
);

    localparam DEPTH = (1 << ADDR_WIDTH);

    // BRAM / inferred RAM
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Optional reset initialization
    integer ri;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ri = 0; ri < DEPTH; ri = ri + 1) begin
                mem[ri] <= '0;
            end
            rdata <= '0;
        end else begin
            if (we) mem[waddr] <= wdata;
            // synchronous read: rdata updated on clock
            rdata <= mem[raddr];
        end
    end

endmodule
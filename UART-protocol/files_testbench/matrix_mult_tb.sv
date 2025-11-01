module matrix_mult_tb;

    logic clk;
    logic reset;
    logic [7:0] matrix_a [0:3][0:3];
    logic [7:0] matrix_b [0:3][0:3];
    logic [7:0] result [0:3][0:3];
    logic [2:0] debug [0:1];


    matrix_mult
    dut (
        .reset(reset),
        .clk(clk),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .result(result),
        .debug(debug)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Bloco de estímulo principal
    initial begin
        // $dumpfile("wave.vcd");
        // $dumpvars(0, matrix_mult_tb);
        reset = 1'b0;
        $display("%3b", debug[1]);
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                matrix_a [i][j] = 8'h00;
                matrix_b [i][j] = 8'h00;
                if (i == j) begin
                    matrix_a [i][j] = 8'd1;
                    matrix_b [i][j] = 8'd1;
                end
                    result [i][j] = 8'd0;
            end
        end
        matrix_b [0][1] = 8'd20;
        $display("%3b", debug[1]);
        // Display A and B before starting the multiplication
        $display("Matrix A");
        for (int i = 0; i < 4; i++) begin
            $write("  ");
            for (int j = 0; j < 4; j++) begin
                $write("%0d\t", matrix_a[i][j]); // decimal, change to "%0h" for hex
            end
            $display("");
        end
        $display("%3b", debug[1]);
        $display("Matrix B");
        for (int i = 0; i < 4; i++) begin
            $write("  ");
            for (int j = 0; j < 4; j++) begin
                $write("%0d\t", matrix_b[i][j]); // decimal, change to "%0h" for hex
            end
            $display("");
        end

        repeat(100) @(posedge clk);
        
        $display("Result");
        for (int i = 0; i < 4; i++) begin
            $write("  ");
            for (int j = 0; j < 4; j++) begin
                $write("%0d\t", result[i][j]);
            end
            $display("");
        end
        $display("%3b", debug[1]);

        reset = 1'b1;
        // Wait additional cycles to let multiplication finish (adjust if needed)
        repeat(100) @(posedge clk);

        $display("%3b", debug[1]);
        while (result[3][3] != 8'd1) begin
            repeat(1) @(posedge clk);
        end

        // Display result after multiplication
        $display("Result");
        for (int i = 0; i < 4; i++) begin
            $write("  ");
            for (int j = 0; j < 4; j++) begin
                $write("%0d\t", result[i][j]);
            end
            $display("");
        end

        $finish;
    end

endmodule
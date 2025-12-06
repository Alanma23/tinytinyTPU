`timescale 1ns / 1ps
`timescale 1ns / 1ps

module dual_weight_fifo_tb;

    reg clk, reset;
    reg push_col0, push_col1;
    reg [7:0] data_in;
    reg pop;
    wire [7:0] col0_out, col1_out;

    dual_weight_fifo uut (
        .clk(clk), .reset(reset),
        .push_col0(push_col0), .push_col1(push_col1),
        .data_in(data_in),
        .pop(pop),
        .col0_out(col0_out), .col1_out(col1_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1;
        push_col0 = 0; push_col1 = 0;
        pop = 0; data_in = 0;
        
        #10 reset = 0;

        // --- PHASE 1: STAGGERED LOAD (Interleaved) ---
        $display("--- Loading FIFOs Interleaved ---");

        // 1. Push Bottom-Left (3)
        push_col0 = 1; data_in = 3;
        #10;
        push_col0 = 0;

        // 2. Push Bottom-Right (4)
        push_col1 = 1; data_in = 4;
        #10;
        push_col1 = 0;

        // 3. Push Top-Left (1)
        push_col0 = 1; data_in = 1;
        #10;
        push_col0 = 0;

        // 4. Push Top-Right (2)
        push_col1 = 1; data_in = 2;
        #10;
        push_col1 = 0;

        // --- PHASE 2: PARALLEL POP (MMU Loading) ---
        $display("--- Popping to MMU ---");
        
        // Pop 1 (Bottom Row Weights)
        pop = 1;
        #10;
        $display("Pop 1: Left=%d (Exp 3), Right=%d (Exp 4)", col0_out, col1_out);

        // Pop 2 (Top Row Weights)
        #10;
        $display("Pop 2: Left=%d (Exp 1), Right=%d (Exp 2)", col0_out, col1_out);

        pop = 0;
        #10;
        $finish;
    end
endmodule
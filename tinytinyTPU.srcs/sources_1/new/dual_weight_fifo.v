`timescale 1ns / 1ps
`timescale 1ns / 1ps

module dual_weight_fifo (
    input wire clk,
    input wire reset,
    
    // --- PUSH SIDE (Staggered/Interleaved) ---
    // Simulates a narrow bus filling multiple columns
    input wire push_col0,
    input wire push_col1,
    input wire [7:0] data_in, // Shared Data Bus
    
    // --- POP SIDE (Parallel) ---
    // The MMU loads all columns simultaneously
    input wire pop,
    output reg [7:0] col0_out,
    output reg [7:0] col1_out
);

    // Two independent queues (4 deep)
    reg [7:0] queue0 [0:3];
    reg [7:0] queue1 [0:3];
    
    // Pointers
    reg [1:0] wr_ptr0, rd_ptr0;
    reg [1:0] wr_ptr1, rd_ptr1;

    // Initialization
    integer i;
    initial begin
        for (i=0; i<4; i=i+1) begin
            queue0[i] = 0;
            queue1[i] = 0;
        end
        col0_out = 0;
        col1_out = 0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr0 <= 0; rd_ptr0 <= 0;
            wr_ptr1 <= 0; rd_ptr1 <= 0;
            col0_out <= 0; col1_out <= 0;
        end else begin
            // --- COL 0 LOGIC ---
            if (push_col0) begin
                queue0[wr_ptr0] <= data_in;
                wr_ptr0 <= wr_ptr0 + 1;
            end
            if (pop) begin
                col0_out <= queue0[rd_ptr0];
                rd_ptr0 <= rd_ptr0 + 1;
            end

            // --- COL 1 LOGIC ---
            if (push_col1) begin
                queue1[wr_ptr1] <= data_in;
                wr_ptr1 <= wr_ptr1 + 1;
            end
            if (pop) begin
                col1_out <= queue1[rd_ptr1];
                rd_ptr1 <= rd_ptr1 + 1;
            end
        end
    end

endmodule
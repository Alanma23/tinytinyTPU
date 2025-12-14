`timescale 1ns / 1ps

module dual_weight_fifo (
    input wire clk,
    input wire reset,
    // Push interface
    // Simulates a narrow bus filling multiple columns
    input wire push_col0,
    input wire push_col1,
    input wire [7:0] data_in, // Shared Data Bus
    // Pop interface
    // The MMU loads weights with column staggering
    input wire pop,
    output wire [7:0] col0_out,      // Direct output (combinational, no skew)
    output wire [7:0] col1_out,      // Direct output (combinational, no skew)
    // Raw outputs (for debugging/monitoring)
    output wire [7:0] col1_raw       // Same as col1_out (no skew now)
);

    // Two 4-deep queues
    reg [7:0] queue0 [0:3];
    reg [7:0] queue1 [0:3];
    
    // Pointers for read/write
    reg [1:0] wr_ptr0, rd_ptr0;
    reg [1:0] wr_ptr1, rd_ptr1;
    
    // Combinational read for both columns (no latency, no skew)
    // Weight loading skew is handled naturally by the psum propagation path
    assign col0_out = queue0[rd_ptr0];
    assign col1_out = queue1[rd_ptr1];
    assign col1_raw = queue1[rd_ptr1];

    // Initialization
    integer i;
    initial begin
        for (i=0; i<4; i=i+1) begin
            queue0[i] = 0;
            queue1[i] = 0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr0 <= 0; rd_ptr0 <= 0;
            wr_ptr1 <= 0; rd_ptr1 <= 0;
        end else begin
            // Column 0: Push and Pop
            if (push_col0) begin
                queue0[wr_ptr0] <= data_in;
                wr_ptr0 <= wr_ptr0 + 1;
            end
            if (pop) begin
                rd_ptr0 <= rd_ptr0 + 1;
            end

            // Column 1: Push and Pop (no skew - symmetric with column 0)
            if (push_col1) begin
                queue1[wr_ptr1] <= data_in;
                wr_ptr1 <= wr_ptr1 + 1;
            end
            if (pop) begin
                rd_ptr1 <= rd_ptr1 + 1;
            end
        end
    end

endmodule

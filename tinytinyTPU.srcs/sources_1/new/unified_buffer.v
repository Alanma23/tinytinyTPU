`timescale 1ns / 1ps
// Simple synchronous unified buffer (byte-wide FIFO) to capture activation pipeline output.
// Integrates via ready/valid on the write side; provides ready/valid on the read side.
module unified_buffer #(
    parameter WIDTH = 8,
    parameter DEPTH = 256,
    parameter ADDR_W = $clog2(DEPTH)
) (
    input  wire                 clk,
    input  wire                 reset,

    // Write side (from activation_pipeline)
    input  wire                 wr_valid,
    input  wire [WIDTH-1:0]     wr_data,
    output wire                 wr_ready,

    // Read side (to systolic / consumer)
    input  wire                 rd_ready,
    output reg                  rd_valid,
    output reg  [WIDTH-1:0]     rd_data,

    // Status
    output wire                 full,
    output wire                 empty,
    output reg  [ADDR_W:0]      count
);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W-1:0] rd_ptr;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    assign wr_ready = ~full;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr   <= {ADDR_W{1'b0}};
            rd_ptr   <= {ADDR_W{1'b0}};
            count    <= {ADDR_W+1{1'b0}};
            rd_valid <= 1'b0;
            rd_data  <= {WIDTH{1'b0}};
        end else begin
            // default rd_valid drops unless we emit a beat this cycle
            rd_valid <= 1'b0;

            // Write path
            if (wr_valid && wr_ready) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
                count <= count + 1'b1;
            end

            // Read path
            if (rd_ready && ~empty) begin
                rd_data  <= mem[rd_ptr];
                rd_ptr   <= rd_ptr + 1'b1;
                rd_valid <= 1'b1;
                count    <= count - 1'b1;
            end
        end
    end
endmodule


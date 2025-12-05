`timescale 1ns / 1ps
module mmu ( // for a 2x2 systolic array
    input wire clk,
    input wire reset,
    input wire en_load_weight,
    
    // UB activations input
    input wire [7:0] row0_in,
    input wire [7:0] row1_in,
    
    // Weight FIFO input
    input wire [7:0] col0_in,
    input wire [7:0] col1_in,
    
    // Accumulator output
    output wire [15:0] acc0_out,
    output wire [15:0] acc1_out
);
		
		
		// pe 00 -> pe 01
		//   |         | 
		//   v         v
		// pe 10 -> pe 11
		
    // Systolic array PE connections 
    wire [7:0] pe00_01_act, pe10_11_act;
    wire [15:0] pe00_10_psum, pe01_11_psum;

    pe pe00 (
        .clk(clk), .reset(reset), .en_load_weight(en_load_weight),
        .in_act(row0_in),         
        .in_psum({8'b0, col0_in}),     
        .out_act(pe00_01_act),
        .out_psum(pe00_10_psum)
    );

    pe pe01 (
        .clk(clk), .reset(reset), .en_load_weight(en_load_weight),
        .in_act(pe00_01_act),   
        .in_psum({8'b0, col1_in}),      
        .out_act(), // notice that activation is unconnected in our 2x2 case to the right
        .out_psum(pe01_11_psum)
    );

    // --- Row 1 ---
    pe pe10 (
        .clk(clk), .reset(reset), .en_load_weight(en_load_weight),
        .in_act(row1_in),       
        .in_psum(pe00_10_psum), 
        .out_act(pe10_11_act),
        .out_psum(acc0_out)       // output row to accumulator
    );

    pe pe11 (
        .clk(clk), .reset(reset), .en_load_weight(en_load_weight),
        .in_act(pe10_11_act), 
        .in_psum(pe01_11_psum),
        .out_act(), // similar reason to in pe11
        .out_psum(acc1_out)       // output row to accumulator
    );

endmodule
`timescale 1ns / 1ps

module pe(                  input wire clk, 
							input wire reset,
							input wire en_load_weight, 
							input wire [7:0] in_act,
							input wire [15:0] in_psum,
							output reg [7:0] out_act,
							output reg [15:0] out_psum);
				
				reg[7:0] weight;
				
				always @(posedge clk or posedge reset) begin
					if (reset) begin
						out_act <= 8'd0;
						out_psum <= 16'd0;
						weight <= 8'd0;
					end
					else begin
						if (en_load_weight) begin // just getting started
							weight <= in_psum[7:0]; // weight input
							out_psum <= in_psum; // pass weight into PE
							out_act <= 8'd0; // reset activation
						end
						else begin
							out_act <= in_act; // pass right
							out_psum <= (in_act * weight) + in_psum; // pass down
							// out_psum in this case assume that the weight is already loaded
						end
					end
				end			
endmodule
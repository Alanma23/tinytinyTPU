module accumulator_align (
	input wire clk,
	input wire reset,
	
	input wire valid_in,
	input wire [15:0] raw_col0,
	input wire [15:0] raw_col1,
	
	output reg aligned_valid,
	output reg [15:0] align_col0,
	output reg [15:0] align_col1
);

	reg [15:0] col0_delay_reg;
	reg pending;
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			col0_delay_reg <= 0;
			pending <= 0;
			aligned_valid <= 0;
			align_col0 <= 0;
			align_col1 <= 0;
		end 
		else begin
			aligned_valid <= 0;

			// Capture first beat (col0) when no pending pair
			if (valid_in && !pending) begin
				col0_delay_reg <= raw_col0;
				pending <= 1'b1;
			end
			// On the second beat (pending set), emit aligned pair using current raw_col1
			else if (valid_in && pending) begin
				aligned_valid <= 1'b1;
				align_col0 <= col0_delay_reg;
				align_col1 <= raw_col1;
				pending <= 1'b0;
			end
		end
	end

endmodule
`timescale 1ns / 1ps
// Integration TB: accumulator -> activation_pipeline -> unified_buffer
module accel_integration_tb;
    reg clk, reset;

    // Stimulus to accumulator (emulating MMU outputs)
    reg         valid_in;
    reg         accum_en;
    reg         addr_sel;
    reg [15:0]  mmu_col0_in, mmu_col1_in;

    // Activation config
    reg signed [15:0] norm_gain;
    reg signed [31:0] norm_bias;
    reg [4:0]  norm_shift;
    reg signed [15:0] q_inv_scale;
    reg signed [7:0]  q_zero_point;

    // Unified buffer consumer
    reg rd_ready;

    wire signed [31:0] acc0, acc1;
    wire acc_valid;
    wire ap_valid;
    wire signed [7:0] ap_data;
    wire ub_wr_ready;

    wire ub_rd_valid;
    wire signed [7:0] ub_rd_data;
    wire ub_full, ub_empty;

    // DUT chain
    accumulator accum_u (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .accumulator_enable(accum_en),
        .addr_sel(addr_sel),
        .mmu_col0_in(mmu_col0_in),
        .mmu_col1_in(mmu_col1_in),
        .acc_col0_out(acc0),
        .acc_col1_out(acc1),
        .valid_out(acc_valid)
    );

    activation_pipeline ap_u (
        .clk(clk),
        .reset(reset),
        .valid_in(acc_valid & ub_wr_ready), // simple backpressure: stall if UB not ready
        .acc_in(acc0),          // feed col0 for this demo
        .target_in(acc1),       // use col1 as target to exercise loss
        .norm_gain(norm_gain),
        .norm_bias(norm_bias),
        .norm_shift(norm_shift),
        .q_inv_scale(q_inv_scale),
        .q_zero_point(q_zero_point),
        .valid_out(ap_valid),
        .ub_data_out(ap_data),
        .loss_valid(), // ignore loss in this integration TB
        .loss_out()
    );

    unified_buffer ub_u (
        .clk(clk),
        .reset(reset),
        .wr_valid(ap_valid),
        .wr_data(ap_data),
        .wr_ready(ub_wr_ready),
        .rd_ready(rd_ready),
        .rd_valid(ub_rd_valid),
        .rd_data(ub_rd_data),
        .full(ub_full),
        .empty(ub_empty),
        .count()
    );

    // Simple clock
    always #5 clk = ~clk;

    integer i;
    reg [7:0] expected [0:31];
    integer head = 0, tail = 0;

    initial begin
        clk = 0; reset = 1;
        valid_in = 0; accum_en = 0; addr_sel = 0;
        mmu_col0_in = 0; mmu_col1_in = 0;
        norm_gain = 16'sd256; norm_bias = 0; norm_shift = 5'd8; // unity norm
        q_inv_scale = 16'sd256; q_zero_point = 0;                // S=1.0
        rd_ready = 0;

        #20 reset = 0;

        // Wave 1: overwrite with (10, 20) then (30, 40) accumulating into buffer 0
        send_mmu(16'd10, 16'd0, 0);
        send_mmu(16'd0, 16'd20, 0);
        send_mmu(16'd30, 16'd0, 0);
        send_mmu(16'd0, 16'd40, 0);

        // Wave 2: accumulate +5/+7
        accum_en = 1;
        send_mmu(16'd5, 16'd0, 0);
        send_mmu(16'd0, 16'd7, 0);

        // Start draining after some cycles
        repeat (6) @(negedge clk);
        rd_ready = 1;

        // Let it run
        repeat (50) @(negedge clk);
        rd_ready = 0;

        // End
        repeat (20) @(negedge clk);
        $display("Integration TB finished");
        $finish;
    end

    task send_mmu(input [15:0] c0, input [15:0] c1, input sel);
        begin
            @(negedge clk);
            addr_sel   <= sel;
            valid_in   <= 1;
            mmu_col0_in <= c0;
            mmu_col1_in <= c1;
            @(negedge clk);
            valid_in   <= 0;
        end
    endtask

    // Scoreboard expected UB data = quantized(acc0)
    // For unity norm/scale, acc0 itself should quantize directly (clamped to int8)
    always @(posedge clk) begin
        if (ap_valid && ub_wr_ready) begin
            expected[tail] <= ap_data;
            tail = tail + 1;
        end
        if (ub_rd_valid && rd_ready) begin
            if (head >= tail) $fatal(1, "Read with no expected data at t=%0t", $time);
            if (ub_rd_data !== expected[head])
                $fatal(1, "UB data mismatch t=%0t got %0d exp %0d", $time, ub_rd_data, expected[head]);
            head = head + 1;
        end
    end

    // Trace
    always @(posedge clk) begin
        if (ub_rd_valid && rd_ready)
            $display("t=%0t RD UB %0d", $time, ub_rd_data);
    end
endmodule


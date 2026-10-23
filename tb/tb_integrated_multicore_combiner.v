`timescale 1ns/1ps

// Integration test:
// main multicore workload system -> hardware result combiner -> final result.
module tb_integrated_multicore_combiner;
    reg clk = 0;
    reg reset = 1;
    reg [2:0] required_cores = 0;
    reg workload_start = 0;
    reg [31:0] workload_size = 0;

    wire [3:0] core_enable;
    wire workload_done;
    wire [31:0] r0, r1, r2, r3;
    wire [31:0] cyc0, cyc1, cyc2, cyc3;
    wire [31:0] alu0, alu1, alu2, alu3;

    wire [31:0] final_result;
    wire result_valid;

    integer failures = 0;

    always #5 clk = ~clk;

    // Main RTL workload system: partitions work and executes it on CPU cores.
    multicore_cpu_workload_system main_system (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .workload_start(workload_start),
        .workload_size(workload_size),
        .core_enable(core_enable),
        .workload_done(workload_done),
        .core0_result(r0), .core1_result(r1),
        .core2_result(r2), .core3_result(r3),
        .core0_cycles(cyc0), .core1_cycles(cyc1),
        .core2_cycles(cyc2), .core3_cycles(cyc3),
        .core0_alu(alu0), .core1_alu(alu1),
        .core2_alu(alu2), .core3_alu(alu3)
    );

    // Hardware combiner receives partial sums, active-worker mask, and done.
    result_combiner combiner (
        .core0_result(r0),
        .core1_result(r1),
        .core2_result(r2),
        .core3_result(r3),
        .valid_mask(core_enable),
        .workload_done(workload_done),
        .final_result(final_result),
        .result_valid(result_valid)
    );

    task launch_workload;
        input [2:0] cores;
        input [31:0] items;
        begin
            @(negedge clk);
            required_cores = cores;
            workload_size = items;
            workload_start = 1'b1;

            @(negedge clk);
            workload_start = 1'b0;

            wait (workload_done === 1'b0);
            wait (workload_done === 1'b1);
            // Allow combinational result and valid outputs to settle.
            #1;
        end
    endtask

    task check_case;
        input [255:0] test_name;
        input [3:0] expected_enable;
        input [31:0] expected_final;
        begin
            $display("\n--- %0s ---", test_name);
            $display("core_enable=%b done=%b result_valid=%b",
                     core_enable, workload_done, result_valid);
            $display("partial results: %0d, %0d, %0d, %0d",
                     r0, r1, r2, r3);
            $display("combined final_result=%0d (expected %0d)",
                     final_result, expected_final);

            if (core_enable !== expected_enable) begin
                $display("FAIL: unexpected active-core mask");
                failures = failures + 1;
            end else begin
                $display("PASS: active-core mask");
            end

            if (workload_done !== 1'b1 || result_valid !== 1'b1) begin
                $display("FAIL: result_valid was not asserted at completion");
                failures = failures + 1;
            end else begin
                $display("PASS: completion and result_valid");
            end

            if (final_result !== expected_final) begin
                $display("FAIL: combined result incorrect");
                failures = failures + 1;
            end else begin
                $display("PASS: combined final result");
            end
        end
    endtask

    initial begin
        $display("=== INTEGRATED MAIN RTL + RESULT COMBINER TEST ===");

        reset = 1'b1;
        required_cores = 0;
        workload_size = 0;
        workload_start = 0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        repeat (2) @(negedge clk);

        // Existing prototype sums the assigned work indices:
        // N=8 -> partial results 1,5,9,13 -> combined result 28.
        launch_workload(3'd4, 32'd8);
        check_case("N=8, K=4", 4'b1111, 32'd28);

        // N=7, K=3 -> partial results 3,7,11; core 3 is excluded.
        launch_workload(3'd3, 32'd7);
        check_case("N=7, K=3", 4'b0111, 32'd21);

        // Zero work -> no valid workers; stale core results must be ignored.
        launch_workload(3'd4, 32'd0);
        check_case("N=0, K=4", 4'b0000, 32'd0);

        if (failures == 0) begin
            $display("\nSUMMARY: failures=0");
            $display("RESULT: PASS");
        end else begin
            $display("\nSUMMARY: failures=%0d", failures);
            $display("RESULT: FAIL");
        end
        $finish;
    end

    initial begin
        #20000;
        $display("FAIL: global timeout");
        $finish;
    end
endmodule

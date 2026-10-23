`timescale 1ns/1ps

module tb_multicore_integrated_system;
    reg clk = 0;
    reg reset = 1;
    reg [2:0] required_cores = 0;
    reg vector_workload_start = 0;
    reg [31:0] vector_workload_size = 0;
    reg cpu_workload_start = 0;
    reg [31:0] cpu_workload_size = 0;

    wire vector_workload_done;
    wire [31:0] vc0, vc1, vc2, vc3, vc4, vc5, vc6, vc7;
    wire [3:0] original_core_enable;
    wire [3:0] cpu_core_enable;
    wire cpu_workload_done;
    wire [31:0] r0, r1, r2, r3;
    wire [31:0] cpu_final_result;
    wire cpu_result_valid;
    integer failures = 0;

    always #5 clk = ~clk;

    multicore_integrated_system dut (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .vector_workload_start(vector_workload_start),
        .vector_workload_size(vector_workload_size),
        .vector_workload_done(vector_workload_done),
        .vector_c0(vc0), .vector_c1(vc1),
        .vector_c2(vc2), .vector_c3(vc3),
        .vector_c4(vc4), .vector_c5(vc5),
        .vector_c6(vc6), .vector_c7(vc7),
        .original_core_enable(original_core_enable),
        .cpu_workload_start(cpu_workload_start),
        .cpu_workload_size(cpu_workload_size),
        .cpu_core_enable(cpu_core_enable),
        .cpu_workload_done(cpu_workload_done),
        .cpu_core0_result(r0), .cpu_core1_result(r1),
        .cpu_core2_result(r2), .cpu_core3_result(r3),
        .cpu_final_result(cpu_final_result),
        .cpu_result_valid(cpu_result_valid)
    );

    initial begin
        $display("=== INTEGRATED MULTICORE SYSTEM TEST ===");
        repeat (3) @(negedge clk);
        reset = 0;
        repeat (2) @(negedge clk);

        // Launch vector accelerator and CPU partitioned workload together.
        required_cores = 3'd4;
        vector_workload_size = 32'd8;
        cpu_workload_size = 32'd8;
        vector_workload_start = 1;
        cpu_workload_start = 1;
        @(negedge clk);
        vector_workload_start = 0;
        cpu_workload_start = 0;

        // Wait for BOTH independent workloads. join_any would return when
        // the faster vector workload finishes and could check CPU results early.
        fork
            begin
                wait (vector_workload_done === 1'b1);
            end
            begin
                wait (cpu_workload_done === 1'b1);
            end
        join
        #1;

        $display("original_core_enable=%b", original_core_enable);
        $display("vector_done=%b outputs=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 vector_workload_done, vc0, vc1, vc2, vc3, vc4, vc5, vc6, vc7);
        $display("cpu_core_enable=%b cpu_done=%b partials=%0d,%0d,%0d,%0d",
                 cpu_core_enable, cpu_workload_done, r0, r1, r2, r3);
        $display("cpu_final_result=%0d result_valid=%b",
                 cpu_final_result, cpu_result_valid);

        if (original_core_enable !== 4'b1111) begin
            $display("FAIL: original core manager did not enable four cores");
            failures = failures + 1;
        end
        if (vector_workload_done !== 1'b1 ||
            {vc0,vc1,vc2,vc3,vc4,vc5,vc6,vc7} !==
            {32'd11,32'd22,32'd33,32'd44,32'd55,32'd66,32'd77,32'd88}) begin
            $display("FAIL: vector accelerator check");
            failures = failures + 1;
        end else begin
            $display("PASS: vector accelerator retained and operational");
        end
        if (cpu_core_enable !== 4'b1111 ||
            cpu_workload_done !== 1'b1 ||
            {r0,r1,r2,r3} !== {32'd1,32'd5,32'd9,32'd13}) begin
            $display("FAIL: controller-partitioned CPU workload check");
            failures = failures + 1;
        end else begin
            $display("PASS: controller-partitioned CPU workers operational");
        end
        if (cpu_final_result !== 32'd28 || cpu_result_valid !== 1'b1) begin
            $display("FAIL: CPU result combiner check");
            failures = failures + 1;
        end else begin
            $display("PASS: CPU partial results combined correctly");
        end

        if (failures == 0)
            $display("INTEGRATED TEST: PASS");
        else
            $display("INTEGRATED TEST: FAIL (%0d failures)", failures);
        $finish;
    end

    initial begin
        #10000;
        $display("FAIL: global timeout waiting for integrated workloads");
        $finish;
    end
endmodule

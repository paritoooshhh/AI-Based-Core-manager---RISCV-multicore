`timescale 1ns/1ps

module tb_multicore_controller_cpu;
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
    integer failures = 0;

    always #5 clk = ~clk;

    multicore_cpu_workload_system dut (
        .clk(clk), .reset(reset),
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

    task launch_workload;
        input [2:0] cores;
        input [31:0] items;
        begin
            @(negedge clk);
            required_cores = cores;
            workload_size = items;
            workload_start = 1;
            @(negedge clk);
            workload_start = 0;
            wait (workload_done === 1'b0);
            wait (workload_done === 1'b1);
            #1;
        end
    endtask

    initial begin
        $display("\n=== CONTROLLER-TO-CPU WORKLOAD TEST ===");
        #2 reset = 1;
        repeat (2) @(negedge clk);
        reset = 0;

        // Eight items, four cores: ranges [0,1], [2,3], [4,5], [6,7].
        launch_workload(3'd4, 32'd8);
        $display("Case 1: N=8 K=4 enable=%b results=%0d,%0d,%0d,%0d",
                 core_enable, r0, r1, r2, r3);
        if (core_enable !== 4'b1111) begin
            $display("FAIL: expected all four workers active"); failures = failures + 1;
        end else $display("PASS: four controller-assigned CPU workers active");
        if ({r0,r1,r2,r3} !== {32'd1,32'd5,32'd9,32'd13}) begin
            $display("FAIL: incorrect range sums for N=8 K=4"); failures = failures + 1;
        end else $display("PASS: all four CPU range sums correct");
        if ((cyc0==0)||(cyc1==0)||(cyc2==0)||(cyc3==0)||
            (alu0==0)||(alu1==0)||(alu2==0)||(alu3==0)) begin
            $display("FAIL: at least one CPU did not execute useful instructions"); failures = failures + 1;
        end else $display("PASS: all four CPUs executed useful instructions");

        // Seven items, three cores: [0,2], [3,4], [5,6]; core 3 inactive.
        launch_workload(3'd3, 32'd7);
        $display("Case 2: N=7 K=3 enable=%b results=%0d,%0d,%0d,%0d",
                 core_enable, r0, r1, r2, r3);
        if (core_enable !== 4'b0111) begin
            $display("FAIL: expected only cores 0-2 active"); failures = failures + 1;
        end else $display("PASS: only three valid workers enabled");
        if ({r0,r1,r2,r3} !== {32'd3,32'd7,32'd11,32'd0}) begin
            $display("FAIL: incorrect uneven-partition results"); failures = failures + 1;
        end else $display("PASS: uneven ranges and inactive core handled correctly");

        // Zero work should complete without enabling a worker.
        launch_workload(3'd4, 32'd0);
        $display("Case 3: N=0 K=4 enable=%b done=%b", core_enable, workload_done);
        if (core_enable !== 4'b0000 || workload_done !== 1'b1) begin
            $display("FAIL: zero-work case did not safely complete"); failures = failures + 1;
        end else $display("PASS: zero-work case completes with no active workers");

        if (failures == 0) begin
            $display("SUMMARY: failures=0");
            $display("RESULT: PASS");
        end else begin
            $display("SUMMARY: failures=%0d", failures);
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

`timescale 1ns/1ps

// Connectivity audit for the current project architecture.
//
// IMPORTANT:
// 1) This test deliberately tests the original multicore_system and the
//    controller-driven multicore_cpu_workload_system as separate paths.
// 2) Passing functional checks does NOT prove a netlist is structurally wired
//    as intended. Inspect hierarchy/wiring and review the audit notes below.
// 3) Port names for the original multicore_system are based on the project
//    interface described in the project notes: workload_start, workload_size,
//    workload_done and vector output ports. If your local top-level port names
//    differ, update only the instance port map to match the actual declaration.

module tb_system_connectivity_audit;
    reg clk = 0;
    reg reset = 1;

    // Original multicore_system inputs (adjust port map if local RTL differs).
    reg original_workload_start = 0;
    reg [31:0] original_workload_size = 0;

    // Controller-driven CPU workload system inputs.
    reg [2:0] cpu_required_cores = 0;
    reg cpu_workload_start = 0;
    reg [31:0] cpu_workload_size = 0;

    // Original top-level outputs.
    wire original_workload_done;
    wire [31:0] vector0, vector1, vector2, vector3;
    wire [31:0] vector4, vector5, vector6, vector7;

    // Controller-driven CPU system outputs.
    wire [3:0] cpu_core_enable;
    wire cpu_workload_done;
    wire [31:0] r0, r1, r2, r3;
    wire [31:0] cyc0, cyc1, cyc2, cyc3;
    wire [31:0] alu0, alu1, alu2, alu3;

    // Result combiner output.
    wire [31:0] combined_result;
    wire combined_valid;

    integer failures = 0;
    integer timeout_seen = 0;

    always #5 clk = ~clk;

    // NOTE: This instantiation assumes the original top has these ports.
    // Check the actual module declaration before compiling.
        wire [3:0] original_core_enable;

    multicore_system original_top (
        .clk(clk),
        .reset(reset),
        .required_cores(3'd4),
        .core_enable(original_core_enable),

        .workload_start(original_workload_start),
        .workload_size(original_workload_size),
        .workload_done(original_workload_done),

        .vector_c0(vector0),
        .vector_c1(vector1),
        .vector_c2(vector2),
        .vector_c3(vector3),
        .vector_c4(vector4),
        .vector_c5(vector5),
        .vector_c6(vector6),
        .vector_c7(vector7)
    );

    multicore_cpu_workload_system cpu_workload_top (
        .clk(clk),
        .reset(reset),
        .required_cores(cpu_required_cores),
        .workload_start(cpu_workload_start),
        .workload_size(cpu_workload_size),
        .core_enable(cpu_core_enable),
        .workload_done(cpu_workload_done),
        .core0_result(r0), .core1_result(r1),
        .core2_result(r2), .core3_result(r3),
        .core0_cycles(cyc0), .core1_cycles(cyc1),
        .core2_cycles(cyc2), .core3_cycles(cyc3),
        .core0_alu(alu0), .core1_alu(alu1),
        .core2_alu(alu2), .core3_alu(alu3)
    );

    result_combiner combiner (
        .core0_result(r0), .core1_result(r1),
        .core2_result(r2), .core3_result(r3),
        .valid_mask(cpu_core_enable),
        .workload_done(cpu_workload_done),
        .final_result(combined_result),
        .result_valid(combined_valid)
    );

    task launch_cpu_workload;
        input [2:0] cores;
        input [31:0] items;
        begin
            @(negedge clk);
            cpu_required_cores = cores;
            cpu_workload_size = items;
            cpu_workload_start = 1;
            @(negedge clk);
            cpu_workload_start = 0;
            wait (cpu_workload_done === 1'b0);
            wait (cpu_workload_done === 1'b1);
            #1;
        end
    endtask

    initial begin
        $display("=== TOP-LEVEL CONNECTIVITY AUDIT ===");
        $display("AUDIT SCOPE: original multicore_system vs CPU workload prototype");
        reset = 1;
        repeat (3) @(negedge clk);
        reset = 0;
        repeat (2) @(negedge clk);

        // Check A: original top-level vector workload path.
        $display("\n[CHECK A] Original multicore_system vector path");
        @(negedge clk);
        original_workload_size = 32'd8;
        original_workload_start = 1;
        @(negedge clk);
        original_workload_start = 0;

        wait (original_workload_done === 1'b1);
        #1;
        $display("original_workload_done=%b", original_workload_done);
        $display("vector outputs=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 vector0, vector1, vector2, vector3,
                 vector4, vector5, vector6, vector7);

        if (original_workload_done !== 1'b1) begin
            $display("FAIL: original top-level workload did not complete");
            failures = failures + 1;
        end else begin
            $display("PASS: original top-level workload completion observed");
        end

        // Check B: CPU workload path from top-level inputs to CPU outputs.
        $display("\n[CHECK B] Controller-to-CPU path");
        launch_cpu_workload(3'd4, 32'd8);
        $display("cpu_core_enable=%b cpu_workload_done=%b",
                 cpu_core_enable, cpu_workload_done);
        $display("CPU partial results=%0d,%0d,%0d,%0d",
                 r0, r1, r2, r3);

        if (cpu_core_enable !== 4'b1111) begin
            $display("FAIL: controller path did not activate all four workers");
            failures = failures + 1;
        end else begin
            $display("PASS: controller path activated all four workers");
        end

        if (cpu_workload_done !== 1'b1) begin
            $display("FAIL: CPU workload did not complete");
            failures = failures + 1;
        end else begin
            $display("PASS: CPU workload completion observed");
        end

        // Check C: partial CPU results propagate into the combiner.
        $display("\n[CHECK C] CPU results -> result_combiner");
        $display("combined_result=%0d combined_valid=%b",
                 combined_result, combined_valid);
        if (combined_result !== 32'd28 || combined_valid !== 1'b1) begin
            $display("FAIL: combiner did not receive/produce expected result");
            failures = failures + 1;
        end else begin
            $display("PASS: CPU result signals reached combiner");
        end

        // Explicit warning: these are separate top-level instances in this TB.
        // Therefore this TB can show both paths work, but cannot claim the
        // original multicore_system is internally connected to the CPU workload
        // prototype. Structural hierarchy must be inspected/modified to merge.
        $display("\n[STRUCTURAL NOTE]");
        $display("The original multicore_system and cpu_workload_top are");
        $display("separate instances in this testbench.");
        $display("Their coexistence does NOT prove the original top integrates");
        $display("parallel_workload_controller with the RISC-V CPU cores.");

        if (failures == 0) begin
            $display("\nFUNCTIONAL CHECKS: PASS");
            $display("STRUCTURAL INTEGRATION: REQUIRES RTL HIERARCHY REVIEW");
        end else begin
            $display("\nFUNCTIONAL CHECKS: FAIL (%0d failures)", failures);
        end
        $finish;
    end

    initial begin
        #50000;
        timeout_seen = 1;
        $display("FAIL: global timeout (a completion signal may be unconnected)");
        $finish;
    end
endmodule

`timescale 1ns/1ps

// Connectivity audit using the actual multicore_system port names from
// the supplied RTL. It tests:
// A) original multicore_system: core_manager -> ordinary riscv_core counters
// B) original multicore_system: vector_workload_unit -> its internal controller/FSM
// C) separate CPU workload prototype -> partitioned RISC-V cores -> result combiner
//
// IMPORTANT: A, B, and C are NOT one integrated CPU workload path. This testbench
// explicitly reports that the original top does not connect its vector controller
// to the ordinary riscv_core instances.

module tb_top_level_connectivity_audit;
    reg clk = 0;
    reg reset = 1;

    // Actual original multicore_system inputs.
    reg [2:0] required_cores = 0;
    reg workload_start = 0;
    reg [31:0] workload_size = 0;

    wire [3:0] core_enable;
    wire workload_done;
    wire [31:0] vc0, vc1, vc2, vc3, vc4, vc5, vc6, vc7;
    wire [31:0] c0_cycles, c0_inst, c0_alu, c0_load, c0_store, c0_branch, c0_taken;
    wire [31:0] c1_cycles, c1_inst, c1_alu, c1_load, c1_store, c1_branch, c1_taken;
    wire [31:0] c2_cycles, c2_inst, c2_alu, c2_load, c2_store, c2_branch, c2_taken;
    wire [31:0] c3_cycles, c3_inst, c3_alu, c3_load, c3_store, c3_branch, c3_taken;

    // Separate CPU workload prototype inputs/outputs.
    reg [2:0] cpu_required_cores = 0;
    reg cpu_workload_start = 0;
    reg [31:0] cpu_workload_size = 0;
    wire [3:0] cpu_core_enable;
    wire cpu_workload_done;
    wire [31:0] r0, r1, r2, r3;
    wire [31:0] pc0, pc1, pc2, pc3;
    wire [31:0] pa0, pa1, pa2, pa3;
    wire [31:0] cpu_final_result;
    wire cpu_result_valid;

    integer failures = 0;

    always #5 clk = ~clk;

    // A + B vector workload and four ordinary RISC-V cores.
    multicore_system original_top (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .core_enable(core_enable),
        .workload_start(workload_start),
        .workload_size(workload_size),
        .workload_done(workload_done),
        .vector_c0(vc0), .vector_c1(vc1),
        .vector_c2(vc2), .vector_c3(vc3),
        .vector_c4(vc4), .vector_c5(vc5),
        .vector_c6(vc6), .vector_c7(vc7),
        .core0_cycle_count(c0_cycles),
        .core0_instruction_count(c0_inst),
        .core0_alu_count(c0_alu),
        .core0_load_count(c0_load),
        .core0_store_count(c0_store),
        .core0_branch_count(c0_branch),
        .core0_branch_taken_count(c0_taken),
        .core1_cycle_count(c1_cycles),
        .core1_instruction_count(c1_inst),
        .core1_alu_count(c1_alu),
        .core1_load_count(c1_load),
        .core1_store_count(c1_store),
        .core1_branch_count(c1_branch),
        .core1_branch_taken_count(c1_taken),
        .core2_cycle_count(c2_cycles),
        .core2_instruction_count(c2_inst),
        .core2_alu_count(c2_alu),
        .core2_load_count(c2_load),
        .core2_store_count(c2_store),
        .core2_branch_count(c2_branch),
        .core2_branch_taken_count(c2_taken),
        .core3_cycle_count(c3_cycles),
        .core3_instruction_count(c3_inst),
        .core3_alu_count(c3_alu),
        .core3_load_count(c3_load),
        .core3_store_count(c3_store),
        .core3_branch_count(c3_branch),
        .core3_branch_taken_count(c3_taken)
    );

    // Separate controller-driven CPU path, followed by the result combiner.
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
        .core0_cycles(pc0), .core1_cycles(pc1),
        .core2_cycles(pc2), .core3_cycles(pc3),
        .core0_alu(pa0), .core1_alu(pa1),
        .core2_alu(pa2), .core3_alu(pa3)
    );

    result_combiner combiner (
        .core0_result(r0), .core1_result(r1),
        .core2_result(r2), .core3_result(r3),
        .valid_mask(cpu_core_enable),
        .workload_done(cpu_workload_done),
        .final_result(cpu_final_result),
        .result_valid(cpu_result_valid)
    );

    task launch_original_vector;
        input [2:0] cores;
        input [31:0] items;
        begin
            @(negedge clk);
            required_cores = cores;
            workload_size = items;
            workload_start = 1'b1;
            @(negedge clk);
            workload_start = 1'b0;
            wait (workload_done === 1'b1);
            #1;
        end
    endtask

    task launch_cpu_path;
        input [2:0] cores;
        input [31:0] items;
        begin
            @(negedge clk);
            cpu_required_cores = cores;
            cpu_workload_size = items;
            cpu_workload_start = 1'b1;
            @(negedge clk);
            cpu_workload_start = 1'b0;
            wait (cpu_workload_done === 1'b0);
            wait (cpu_workload_done === 1'b1);
            #1;
        end
    endtask

    initial begin
        $display("=== TOP-LEVEL CONNECTIVITY AUDIT ===");
        reset = 1'b1;
        required_cores = 0;
        cpu_required_cores = 0;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        repeat (2) @(negedge clk);

        // CHECK A: original core manager actually enables ordinary CPU cores.
        $display("\n[CHECK A] Original multicore_system -> core_manager -> riscv_core");
        // Drive 0 then 4 to ensure combinational logic evaluates in simulation.
        @(negedge clk);
        required_cores = 0;
        @(negedge clk);
        required_cores = 4;
        repeat (4) @(negedge clk);
        $display("original core_enable=%b", core_enable);
        $display("core cycle counts=%0d,%0d,%0d,%0d",
                 c0_cycles, c1_cycles, c2_cycles, c3_cycles);
        if (core_enable !== 4'b1111) begin
            $display("FAIL: original core_manager enable path");
            failures = failures + 1;
        end else begin
            $display("PASS: original core_manager enables four cores");
        end
        if ((c0_cycles == 0) || (c1_cycles == 0) ||
            (c2_cycles == 0) || (c3_cycles == 0)) begin
            $display("FAIL: one or more original core counters did not advance");
            failures = failures + 1;
        end else begin
            $display("PASS: all four original core counters advance");
        end

        // CHECK B: original top-level vector workload uses its internal controller.
        $display("\n[CHECK B] Original multicore_system -> parallel_shared_vector");
        launch_original_vector(3'd4, 32'd8);
        $display("vector workload_done=%b", workload_done);
        $display("vector outputs=%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 vc0, vc1, vc2, vc3, vc4, vc5, vc6, vc7);
        if (workload_done !== 1'b1) begin
            $display("FAIL: original vector workload did not complete");
            failures = failures + 1;
        end else begin
            $display("PASS: original vector workload completes");
        end
        if ({vc0,vc1,vc2,vc3,vc4,vc5,vc6,vc7} !==
            {32'd11,32'd22,32'd33,32'd44,32'd55,32'd66,32'd77,32'd88}) begin
            $display("FAIL: vector output values incorrect");
            failures = failures + 1;
        end else begin
            $display("PASS: vector controller/FSM path produces expected values");
        end

        // CHECK C: separate controller-driven CPU path feeds result combiner.
        $display("\n[CHECK C] Separate CPU workload system -> result_combiner");
        launch_cpu_path(3'd4, 32'd8);
        $display("CPU core_enable=%b done=%b partials=%0d,%0d,%0d,%0d",
                 cpu_core_enable, cpu_workload_done, r0, r1, r2, r3);
        $display("combiner final_result=%0d valid=%b",
                 cpu_final_result, cpu_result_valid);
        if (cpu_core_enable !== 4'b1111 || cpu_workload_done !== 1'b1) begin
            $display("FAIL: separate CPU workload path did not activate/complete");
            failures = failures + 1;
        end else begin
            $display("PASS: separate CPU workload path activates and completes");
        end
        if (cpu_final_result !== 32'd28 || cpu_result_valid !== 1'b1) begin
            $display("FAIL: separate CPU results did not reach combiner correctly");
            failures = failures + 1;
        end else begin
            $display("PASS: separate CPU results reach combiner");
        end

        $display("\n=== ARCHITECTURE FINDING ===");
        $display("The original multicore_system has two paths:");
        $display("  1) core_manager -> four ordinary riscv_core instances");
        $display("  2) parallel_shared_vector -> its own workload controller/FSM");
        $display("The CPU workload controller and riscv_partition_core instances");
        $display("exist under separate multicore_cpu_workload_system.");
        $display("Therefore the original top does NOT yet use controller-assigned");
        $display("ranges to drive its ordinary riscv_core instances.");

        if (failures == 0) begin
            $display("\nFUNCTIONAL CHECKS: PASS");
            $display("ARCHITECTURE AUDIT: ORIGINAL CPU-WORKLOAD INTEGRATION MISSING");
        end else begin
            $display("\nFUNCTIONAL CHECKS: FAIL, failures=%0d", failures);
            $display("Inspect the failing check above before interpreting architecture.");
        end
        $finish;
    end

    initial begin
        #50000;
        $display("FAIL: global timeout (a completion signal may not be connected)");
        $finish;
    end
endmodule

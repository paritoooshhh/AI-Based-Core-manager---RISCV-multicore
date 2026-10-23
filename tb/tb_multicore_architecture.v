
`timescale 1ns/1ps

// Multicore architecture diagnostic.
// The vector FSM performs vector addition independently.
// CPU instruction memories contain only canonical NOPs.
// This test does not claim that the CPUs cooperate on the vector task.

module tb_multicore_architecture;

    reg clk = 0;
    reg reset = 1;
    reg [2:0] required_cores;
    reg workload_start = 0;
    reg [31:0] workload_size = 32'd8;

    wire [3:0] core_enable;
    wire workload_done;

    wire [31:0] c0, c1, c2, c3, c4, c5, c6, c7;

    wire [31:0] cc0, ic0, ac0, lc0, sc0, bc0, btc0;
    wire [31:0] cc1, ic1, ac1, lc1, sc1, bc1, btc1;
    wire [31:0] cc2, ic2, ac2, lc2, sc2, bc2, btc2;
    wire [31:0] cc3, ic3, ac3, lc3, sc3, bc3, btc3;

    integer i;
    integer failures = 0;
    reg timed_out = 0;

    always #5 clk = ~clk;

    multicore_system dut (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .core_enable(core_enable),

        .workload_start(workload_start),
        .workload_size(workload_size),
        .workload_done(workload_done),

        .vector_c0(c0),
        .vector_c1(c1),
        .vector_c2(c2),
        .vector_c3(c3),
        .vector_c4(c4),
        .vector_c5(c5),
        .vector_c6(c6),
        .vector_c7(c7),

        .core0_cycle_count(cc0),
        .core0_instruction_count(ic0),
        .core0_alu_count(ac0),
        .core0_load_count(lc0),
        .core0_store_count(sc0),
        .core0_branch_count(bc0),
        .core0_branch_taken_count(btc0),

        .core1_cycle_count(cc1),
        .core1_instruction_count(ic1),
        .core1_alu_count(ac1),
        .core1_load_count(lc1),
        .core1_store_count(sc1),
        .core1_branch_count(bc1),
        .core1_branch_taken_count(btc1),

        .core2_cycle_count(cc2),
        .core2_instruction_count(ic2),
        .core2_alu_count(ac2),
        .core2_load_count(lc2),
        .core2_store_count(sc2),
        .core2_branch_count(bc2),
        .core2_branch_taken_count(btc2),

        .core3_cycle_count(cc3),
        .core3_instruction_count(ic3),
        .core3_alu_count(ac3),
        .core3_load_count(lc3),
        .core3_store_count(sc3),
        .core3_branch_count(bc3),
        .core3_branch_taken_count(btc3)
    );

    initial begin
        $display("\n=== MULTICORE ARCHITECTURE DIAGNOSTIC ===");
        required_cores = 3'd0;
#1;
required_cores = 3'd4;
#1;

        // Initialize all four CPU instruction memories with NOPs.
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // Apply reset and allow combinational signals to settle.
        #2;
        reset = 1;
        #10;
        reset = 0;

        repeat (2) @(negedge clk);
        #1;

        // Diagnose the core manager and its output connection.
        $display("\n--- CORE ENABLE DIAGNOSTICS ---");
        $display("required_cores=%b (%0d)",
                 required_cores, required_cores);

        $display("Internal enables [3:0]=%b%b%b%b",
                 dut.core3_enable,
                 dut.core2_enable,
                 dut.core1_enable,
                 dut.core0_enable);

        $display("Top-level core_enable=%b", core_enable);

        if ((^required_cores) === 1'bx) begin
            $display("FAIL: required_cores contains unknown bits");
            failures = failures + 1;
        end

        if ((^core_enable) === 1'bx) begin
            $display("FAIL: core_enable contains unknown bits");
            failures = failures + 1;
        end else if (core_enable !== 4'b1111) begin
            $display("FAIL: expected core_enable=1111, got %b",
                     core_enable);
            failures = failures + 1;
        end else begin
            $display("PASS: all four cores are enabled");
        end

        if ({dut.core3_enable, dut.core2_enable,
             dut.core1_enable, dut.core0_enable} !== 4'b1111) begin
            $display("FAIL: internal core-manager outputs are incorrect");
            failures = failures + 1;
        end else begin
            $display("PASS: internal core-manager outputs are correct");
        end

        // Start the independent vector workload.
        $display("\n--- VECTOR WORKLOAD ---");
        workload_start = 1;
        @(negedge clk);
        workload_start = 0;

        // Wait for completion, but stop waiting after 400 clock edges.
        fork : completion_watch
            begin
                wait (workload_done === 1'b1);
            end

            begin
                repeat (400) @(posedge clk);
                timed_out = 1;
            end
        join_any

        disable completion_watch;

        #1;

        if (timed_out || workload_done !== 1'b1) begin
            $display("FAIL: timeout waiting for workload_done");
            failures = failures + 1;
        end else if ({c0, c1, c2, c3, c4, c5, c6, c7} !==
                     {32'd11, 32'd22, 32'd33, 32'd44,
                      32'd55, 32'd66, 32'd77, 32'd88}) begin
            $display("FAIL: vector output mismatch");
            $display("Actual: %0d %0d %0d %0d %0d %0d %0d %0d",
                     c0, c1, c2, c3, c4, c5, c6, c7);
            failures = failures + 1;
        end else begin
            $display("PASS: vector FSM produced expected vector sum");
            $display("Outputs: %0d %0d %0d %0d %0d %0d %0d %0d",
                     c0, c1, c2, c3, c4, c5, c6, c7);
        end

        // Report CPU activity separately from vector-FSM activity.
        $display("\n--- CPU ACTIVITY ---");
        $display("core_enable=%b", core_enable);

        $display("CPU cycle counters: %0d, %0d, %0d, %0d",
                 cc0, cc1, cc2, cc3);

        $display("CPU instruction counters: %0d, %0d, %0d, %0d",
                 ic0, ic1, ic2, ic3);

        $display("CPU ALU counters: %0d, %0d, %0d, %0d",
                 ac0, ac1, ac2, ac3);

        $display("\nARCHITECTURE FINDING:");
        $display("Vector addition is handled by parallel_shared_vector.");
        $display("CPU instruction memories contain only NOP instructions.");
        $display("This test does not demonstrate cooperative CPU execution.");

        if (failures == 0) begin
            $display("\nSUMMARY: failures=0");
            $display("RESULT: PASS");
        end else begin
            $display("\nSUMMARY: failures=%0d", failures);
            $display("RESULT: FAIL");
        end

        $finish;
    end

    // Global safety timeout.
    initial begin
        #5000;
        $display("FAIL: global simulation timeout");
        $finish;
    end

endmodule

`timescale 1ns/1ps

// Benchmark sweep for multicore_cpu_workload_system.
// Emits CSV rows to the simulator console; no existing testbench is modified.
module tb_ml_scheduler_benchmark;
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

    integer global_cycle = 0;
    integer start_cycle;
    integer finish_cycle;
    integer elapsed_cycles;
    integer active_count;
    integer result_sum;
    integer expected_sum;
    integer result_correct;
    integer failures = 0;
    integer n;
    integer k;

    always #5 clk = ~clk;
    always @(posedge clk) global_cycle <= global_cycle + 1;

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

    task run_case;
        input [31:0] items;
        input [2:0] cores;
        begin
            // Record a consistent start point before asserting the workload.
            @(negedge clk);
            required_cores = cores;
            workload_size = items;
            start_cycle = global_cycle;
            workload_start = 1'b1;

            @(negedge clk);
            workload_start = 1'b0;

            wait (workload_done === 1'b0);
            wait (workload_done === 1'b1);
            #1;

            finish_cycle = global_cycle;
            elapsed_cycles = finish_cycle - start_cycle;
            active_count = 0;
            if (core_enable[0]) active_count = active_count + 1;
            if (core_enable[1]) active_count = active_count + 1;
            if (core_enable[2]) active_count = active_count + 1;
            if (core_enable[3]) active_count = active_count + 1;

            result_sum = r0 + r1 + r2 + r3;
            expected_sum = (items * (items - 1)) / 2;
            result_correct = (result_sum == expected_sum);

            if (!result_correct) begin
                failures = failures + 1;
                $display("WARNING: result mismatch N=%0d K=%0d sum=%0d expected=%0d",
                         items, cores, result_sum, expected_sum);
            end

            // CSV columns: workload_size, requested_cores, active_cores,
            // elapsed_cycles, result_correct
            $display("DATA,%0d,%0d,%0d,%0d,%0d",
                     items, cores, active_count, elapsed_cycles, result_correct);
        end
    endtask

    initial begin
        $display("=== ML SCHEDULER BENCHMARK ===");
        $display("CSV_HEADER,workload_size,requested_cores,active_cores,elapsed_cycles,result_correct");

        reset = 1'b1;
        repeat (3) @(negedge clk);
        reset = 1'b0;
        repeat (2) @(negedge clk);

        // The current RTL intentionally supports up to eight work items.
        // Sweep every nonzero size and requested core count 1..4.
        for (n = 1; n <= 8; n = n + 1) begin
            for (k = 1; k <= 4; k = k + 1) begin
                run_case(n, k);
            end
        end

        $display("BENCHMARK_SUMMARY,failures=%0d", failures);
        if (failures == 0)
            $display("BENCHMARK_RESULT,PASS");
        else
            $display("BENCHMARK_RESULT,FAIL");
        $finish;
    end

    initial begin
        #100000;
        $display("FATAL: benchmark global timeout");
        $finish;
    end
endmodule

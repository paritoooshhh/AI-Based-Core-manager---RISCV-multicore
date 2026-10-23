`timescale 1ns/1ps

// Fresh testbench for the controller-partitioned CPU workload path.
// Top under test: multicore_cpu_workload_system
//
// Run with Icarus Verilog:
//   iverilog -g2012 -s tb_multicore_cpu_workload_sweep -o build/cpu_sweep.vvp \
//       rtl/14_Multicore-Zeta_corrected.v tb/tb_multicore_cpu_workload_sweep.v
//   vvp build/cpu_sweep.vvp
//
// This testbench does not modify the RTL. It sweeps workload sizes 1..8 and
// requested core counts 1..4. Since this interface exposes partial results
// rather than a final combined result, it sums the four worker results.
// Correctness is checked against the single-core result for the same workload
// size; this tests partition-count invariance, not an independent golden model.

module tb_multicore_cpu_workload_sweep;
    reg clk;
    reg reset;
    reg [2:0] required_cores;
    reg workload_start;
    reg [31:0] workload_size;

    wire [3:0] core_enable;
    wire workload_done;
    wire [31:0] core0_result, core1_result, core2_result, core3_result;
    wire [31:0] core0_cycles, core1_cycles, core2_cycles, core3_cycles;
    wire [31:0] core0_alu, core1_alu, core2_alu, core3_alu;

    integer size_i;
    integer cores_i;
    integer pass_count;
    integer fail_count;
    integer timeout_cycles;
    integer active_count;
    integer wall_cycles;
    integer run_result;
    integer expected_result;
    integer result_match;
    integer timed_out;
    reg [3:0] observed_mask;
    integer baseline_result [1:8];
    integer baseline_valid [1:8];

    always #5 clk = ~clk;

    multicore_cpu_workload_system dut (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .workload_start(workload_start),
        .workload_size(workload_size),
        .core_enable(core_enable),
        .workload_done(workload_done),
        .core0_result(core0_result),
        .core1_result(core1_result),
        .core2_result(core2_result),
        .core3_result(core3_result),
        .core0_cycles(core0_cycles),
        .core1_cycles(core1_cycles),
        .core2_cycles(core2_cycles),
        .core3_cycles(core3_cycles),
        .core0_alu(core0_alu),
        .core1_alu(core1_alu),
        .core2_alu(core2_alu),
        .core3_alu(core3_alu)
    );

    function integer popcount4;
        input [3:0] bits;
        integer k;
        begin
            popcount4 = 0;
            for (k = 0; k < 4; k = k + 1)
                popcount4 = popcount4 + bits[k];
        end
    endfunction

    task run_case;
        input integer work_size_arg;
        input integer cores_arg;
        output integer result_out;
        output integer cycles_out;
        output integer active_out;
        output reg [3:0] mask_out;
        output integer timed_out_out;
        integer local_cycles;
        reg [3:0] mask_seen;
        begin
            // Reset each experiment so counters and controller state start clean.
            @(negedge clk);
            reset = 1'b1;
            workload_start = 1'b0;
            required_cores = cores_arg[2:0];
            workload_size = work_size_arg;
            repeat (3) @(negedge clk);
            reset = 1'b0;

            // Pulse start for one full clock interval.
            @(negedge clk);
            workload_start = 1'b1;
            @(negedge clk);
            workload_start = 1'b0;

            local_cycles = 0;
            mask_seen = 4'b0000;
            timed_out_out = 0;

            // Wait for real DUT completion, not a fixed-duration measurement.
            while ((workload_done !== 1'b1) && (local_cycles < 500)) begin
                @(posedge clk);
                local_cycles = local_cycles + 1;
                mask_seen = mask_seen | core_enable;
            end

            if (workload_done !== 1'b1) begin
                timed_out_out = 1;
            end else begin
                // Let registered outputs settle before sampling them.
                @(negedge clk);
            end

            result_out = core0_result + core1_result + core2_result + core3_result;
            cycles_out = local_cycles;
            mask_out = mask_seen;
            active_out = popcount4(mask_seen);
        end
    endtask

    integer measured_cycles;
    integer measured_active;
    integer measured_result;
    integer case_timeout;
    integer expected_active;
    reg [3:0] measured_mask;

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        required_cores = 3'd1;
        workload_start = 1'b0;
        workload_size = 32'd1;
        pass_count = 0;
        fail_count = 0;

        for (size_i = 1; size_i <= 8; size_i = size_i + 1) begin
            baseline_valid[size_i] = 0;
            baseline_result[size_i] = 0;
        end

        $display("CPU_SWEEP_BEGIN,top,multicore_cpu_workload_system");
        $display("CSV_HEADER,workload_size,requested_cores,active_cores,active_mask,elapsed_cycles,core_cycle_sum,result_sum,baseline_result,result_match,timeout");

        // Run the one-core reference first for each workload size, then
        // compare multi-core configurations with that reference result.
        for (size_i = 1; size_i <= 8; size_i = size_i + 1) begin
            for (cores_i = 1; cores_i <= 4; cores_i = cores_i + 1) begin
                run_case(size_i, cores_i, measured_result, measured_cycles,
                         measured_active, measured_mask, case_timeout);

                expected_active = (cores_i < size_i) ? cores_i : size_i;
                if (case_timeout == 0 && cores_i == 1) begin
                    baseline_result[size_i] = measured_result;
                    baseline_valid[size_i] = 1;
                end

                if (case_timeout != 0) begin
                    result_match = 0;
                    fail_count = fail_count + 1;
                end else if (cores_i == 1) begin
                    // Establish the reference only from a successful one-core run.
                    baseline_result[size_i] = measured_result;
                    baseline_valid[size_i] = 1;
                    result_match = 1;
                    pass_count = pass_count + 1;
                end else if (baseline_valid[size_i] != 0) begin
                    result_match = (measured_result == baseline_result[size_i]);
                    if (result_match)
                        pass_count = pass_count + 1;
                    else
                        fail_count = fail_count + 1;
                end else begin
                    // A multi-core result cannot be validated without its baseline.
                    result_match = 0;
                    fail_count = fail_count + 1;
                end

                $display("DATA,%0d,%0d,%0d,%b,%0d,%0d,%0d,%0d,%0d,%0d",
                    size_i, cores_i, measured_active, measured_mask,
                    measured_cycles,
                    (core0_cycles + core1_cycles + core2_cycles + core3_cycles),
                    measured_result, baseline_result[size_i],
                    result_match, case_timeout);

                if (case_timeout == 0 && measured_active != expected_active) begin
                    $display("CHECK_FAIL,active_core_count,size=%0d,requested=%0d,expected=%0d,observed=%0d,mask=%b",
                        size_i, cores_i, expected_active, measured_active, measured_mask);
                    fail_count = fail_count + 1;
                end
                if (case_timeout != 0) begin
                    $display("CHECK_FAIL,timeout,size=%0d,requested=%0d", size_i, cores_i);
                end
            end
        end

        $display("CPU_SWEEP_SUMMARY,pass=%0d,fail=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("CPU_SWEEP_RESULT,PASS");
        else
            $display("CPU_SWEEP_RESULT,FAIL");
        $finish;
    end

endmodule

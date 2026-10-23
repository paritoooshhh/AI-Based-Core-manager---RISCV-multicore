`timescale 1ns/1ps

module tb_ml_scheduler_heavy_benchmark;
    reg clk = 0;
    reg reset = 1;
    reg [2:0] required_cores = 1;
    reg workload_start = 0;
    reg [31:0] workload_size = 1;
    reg [1:0] workload_type = 0;

    wire [3:0] core_enable;
    wire workload_done;
    wire [31:0] core0_result, core1_result, core2_result, core3_result;
    wire [31:0] core0_cycles, core1_cycles, core2_cycles, core3_cycles;
    wire [31:0] core0_alu, core1_alu, core2_alu, core3_alu;

    integer pass_count = 0, fail_count = 0;
    integer size_index, core_index, type_index;
    integer elapsed_cycles, timeout_flag, active_mask, active_cores;
    integer i, timeout_limit;
    reg [31:0] result_sum, expected_result;
    reg [31:0] base_result [0:35];
    reg base_valid [0:35];
    reg result_correct;
    reg [31:0] total_instruction_count, total_alu_count;
    reg [31:0] total_load_count, total_store_count;
    reg [31:0] total_branch_count, total_branch_taken_count;
    reg [31:0] total_core_cycles;
    integer workload_sizes [0:8];
    reg [127:0] workload_names [0:3];

    always #5 clk = ~clk;

    multicore_cpu_heavy_workload_system dut(
        .clk(clk), .reset(reset), .required_cores(required_cores),
        .workload_start(workload_start), .workload_size(workload_size),
        .workload_type(workload_type), .core_enable(core_enable),
        .workload_done(workload_done),
        .core0_result(core0_result), .core1_result(core1_result),
        .core2_result(core2_result), .core3_result(core3_result),
        .core0_cycles(core0_cycles), .core1_cycles(core1_cycles),
        .core2_cycles(core2_cycles), .core3_cycles(core3_cycles),
        .core0_alu(core0_alu), .core1_alu(core1_alu),
        .core2_alu(core2_alu), .core3_alu(core3_alu)
    );

    function integer popcount4;
        input [3:0] mask;
        integer k;
        begin
            popcount4 = 0;
            for (k=0; k<4; k=k+1)
                if (mask[k]) popcount4 = popcount4 + 1;
        end
    endfunction

    task run_case;
        input integer work_type;
        input integer size_slot;
        input integer work_size;
        input integer requested;
        integer k;
        integer baseline_slot;
        reg [3:0] seen_mask;
        reg [31:0] expected;
        begin
            reset = 1;
            workload_start = 0;
            workload_type = work_type[1:0];
            workload_size = work_size;
            required_cores = requested;
            repeat (3) @(posedge clk);
            @(negedge clk);
            reset = 0;
            workload_start = 1;
            @(negedge clk);
            workload_start = 0;

            seen_mask = 4'b0000;
            elapsed_cycles = 0;
            timeout_flag = 0;
            timeout_limit = work_size * 20 + 200;
            while ((workload_done !== 1'b1) &&
                   (elapsed_cycles < timeout_limit)) begin
                @(posedge clk);
                elapsed_cycles = elapsed_cycles + 1;
                seen_mask = seen_mask | core_enable;
            end
            #1;
            if (workload_done !== 1'b1)
                timeout_flag = 1;

            active_mask = seen_mask;
            active_cores = popcount4(seen_mask);
            result_sum = core0_result + core1_result + core2_result + core3_result;
            expected = (work_size * (work_size - 1)) / 2;
            expected_result = expected;
            result_correct = (timeout_flag == 0) && (result_sum === expected);
            if (active_cores != ((requested < work_size) ? requested : work_size))
                result_correct = 0;

            // Compare each core count against the one-core result for the SAME
            // workload family and size, not against another size's baseline.
            baseline_slot = work_type * 9 + size_slot;
            if (requested == 1) begin
                base_result[baseline_slot] = result_sum;
                base_valid[baseline_slot] = (timeout_flag == 0);
            end else if (!base_valid[baseline_slot] ||
                         result_sum !== base_result[baseline_slot]) begin
                result_correct = 0;
            end

            total_core_cycles = core0_cycles + core1_cycles + core2_cycles + core3_cycles;
            total_instruction_count = dut.ic0 + dut.ic1 + dut.ic2 + dut.ic3;
            total_alu_count = core0_alu + core1_alu + core2_alu + core3_alu;
            total_load_count = dut.ld0 + dut.ld1 + dut.ld2 + dut.ld3;
            total_store_count = dut.st0 + dut.st1 + dut.st2 + dut.st3;
            total_branch_count = dut.br0 + dut.br1 + dut.br2 + dut.br3;
            total_branch_taken_count = dut.bt0 + dut.bt1 + dut.bt2 + dut.bt3;

            $display("DATA,%0d,%0d,%0d,%0d,%0d",
                     work_size, requested, active_cores, elapsed_cycles, result_correct);
            $display("METRICS,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                     work_type, work_size, requested, active_cores, total_core_cycles,
                     total_instruction_count, total_alu_count, total_load_count,
                     total_store_count, total_branch_count, total_branch_taken_count);

            if (result_correct && !timeout_flag) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("CHECK_FAIL,type=%0d,size=%0d,cores=%0d,mask=%b,result=%0d,expected=%0d,timeout=%0d",
                         work_type, work_size, requested, seen_mask,
                         result_sum, expected, timeout_flag);
            end
        end
    endtask

    initial begin
        workload_sizes[0] = 8;
        workload_sizes[1] = 16;
        workload_sizes[2] = 32;
        workload_sizes[3] = 64;
        workload_sizes[4] = 128;
        workload_sizes[5] = 256;
        workload_sizes[6] = 48;
        workload_sizes[7] = 96;
        workload_sizes[8] = 192;
        workload_names[0] = "arithmetic";
        workload_names[1] = "branch";
        workload_names[2] = "memory";
        workload_names[3] = "mixed";

        for (i=0; i<36; i=i+1) begin
            base_valid[i] = 0;
            base_result[i] = 0;
        end

        $display("=== ML SCHEDULER BENCHMARK ===");
        $display("BENCHMARK_SCOPE,experimental_partitioned_cpu");
        $display("CSV_HEADER,workload_size,requested_cores,active_cores,elapsed_cycles,result_correct");
        $display("METRICS_HEADER,workload_type_id,workload_size,requested_cores,active_cores,core_cycle_sum,instruction_count,alu_count,load_count,store_count,branch_count,branch_taken_count");

        for (type_index=0; type_index<4; type_index=type_index+1) begin
            $display("WORKLOAD_TYPE,%0d,%0s", type_index, workload_names[type_index]);
            // Reset the baseline for each workload family.
            base_valid[type_index] = 0;
            for (size_index=0; size_index<9; size_index=size_index+1) begin
                for (core_index=1; core_index<=4; core_index=core_index+1) begin
                    // Ensure one-core baseline for this size is collected first.
                    // The loop order starts with core 1 for each size.
                    run_case(type_index, size_index, workload_sizes[size_index], core_index);
                end
            end
        end

        $display("BENCHMARK_SUMMARY,failures=%0d", fail_count);
        if (fail_count == 0)
            $display("BENCHMARK_RESULT,PASS");
        else
            $display("BENCHMARK_RESULT,FAIL");
        $finish;
    end
endmodule


`timescale 1ns/1ps

module tb_multicore_system;

    reg clk;
    reg reset;
    reg [2:0] required_cores;
    reg workload_start;
    reg [31:0] workload_size;

    wire [3:0] core_enable;
    wire workload_done;

    wire [31:0] vector_c0, vector_c1;
    wire [31:0] vector_c2, vector_c3;
    wire [31:0] vector_c4, vector_c5;
    wire [31:0] vector_c6, vector_c7;

    wire [31:0] core0_cycle_count, core0_instruction_count;
    wire [31:0] core0_alu_count, core0_load_count;
    wire [31:0] core0_store_count, core0_branch_count;
    wire [31:0] core0_branch_taken_count;

    wire [31:0] core1_cycle_count, core1_instruction_count;
    wire [31:0] core1_alu_count, core1_load_count;
    wire [31:0] core1_store_count, core1_branch_count;
    wire [31:0] core1_branch_taken_count;

    wire [31:0] core2_cycle_count, core2_instruction_count;
    wire [31:0] core2_alu_count, core2_load_count;
    wire [31:0] core2_store_count, core2_branch_count;
    wire [31:0] core2_branch_taken_count;

    wire [31:0] core3_cycle_count, core3_instruction_count;
    wire [31:0] core3_alu_count, core3_load_count;
    wire [31:0] core3_store_count, core3_branch_count;
    wire [31:0] core3_branch_taken_count;

    integer i;
    reg [2:0] ml_required_cores;
    reg [2:0] ml_prediction_mem [0:0];

    multicore_system dut (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .core_enable(core_enable),
        .workload_start(workload_start),
        .workload_size(workload_size),
        .workload_done(workload_done),

        .vector_c0(vector_c0), .vector_c1(vector_c1),
        .vector_c2(vector_c2), .vector_c3(vector_c3),
        .vector_c4(vector_c4), .vector_c5(vector_c5),
        .vector_c6(vector_c6), .vector_c7(vector_c7),

        .core0_cycle_count(core0_cycle_count),
        .core0_instruction_count(core0_instruction_count),
        .core0_alu_count(core0_alu_count),
        .core0_load_count(core0_load_count),
        .core0_store_count(core0_store_count),
        .core0_branch_count(core0_branch_count),
        .core0_branch_taken_count(core0_branch_taken_count),

        .core1_cycle_count(core1_cycle_count),
        .core1_instruction_count(core1_instruction_count),
        .core1_alu_count(core1_alu_count),
        .core1_load_count(core1_load_count),
        .core1_store_count(core1_store_count),
        .core1_branch_count(core1_branch_count),
        .core1_branch_taken_count(core1_branch_taken_count),

        .core2_cycle_count(core2_cycle_count),
        .core2_instruction_count(core2_instruction_count),
        .core2_alu_count(core2_alu_count),
        .core2_load_count(core2_load_count),
        .core2_store_count(core2_store_count),
        .core2_branch_count(core2_branch_count),
        .core2_branch_taken_count(core2_branch_taken_count),

        .core3_cycle_count(core3_cycle_count),
        .core3_instruction_count(core3_instruction_count),
        .core3_alu_count(core3_alu_count),
        .core3_load_count(core3_load_count),
        .core3_store_count(core3_store_count),
        .core3_branch_count(core3_branch_count),
        .core3_branch_taken_count(core3_branch_taken_count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_cores;
        input [2:0] requested;
        input [3:0] expected;
        begin
            @(negedge clk);
            required_cores = requested;
            #1;

            if (core_enable !== expected) begin
                $display("FAIL: requested=%0d enable=%b expected=%b",
                         requested, core_enable, expected);
                $fatal(1, "Core selection test failed");
            end

            $display("PASS: requested=%0d enable=%b",
                     requested, core_enable);
        end
    endtask

    // Export all RISC-V performance counters as machine-readable CSV rows.
    task print_counter_csv;
        begin
            $display("COUNTER_CSV,core_id,cycles,instructions,alu,loads,stores,branches,branches_taken");

            $display("COUNTER_CSV,0,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                core0_cycle_count, core0_instruction_count,
                core0_alu_count, core0_load_count, core0_store_count,
                core0_branch_count, core0_branch_taken_count);

            $display("COUNTER_CSV,1,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                core1_cycle_count, core1_instruction_count,
                core1_alu_count, core1_load_count, core1_store_count,
                core1_branch_count, core1_branch_taken_count);

            $display("COUNTER_CSV,2,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                core2_cycle_count, core2_instruction_count,
                core2_alu_count, core2_load_count, core2_store_count,
                core2_branch_count, core2_branch_taken_count);

            $display("COUNTER_CSV,3,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                core3_cycle_count, core3_instruction_count,
                core3_alu_count, core3_load_count, core3_store_count,
                core3_branch_count, core3_branch_taken_count);
        end
    endtask

    initial begin
        reset = 1'b1;
        required_cores = 3'd0;
        workload_start = 1'b0;
        workload_size = 32'd8;

        ml_required_cores = 3'd0;
        $readmemh("ml_prediction.mem", ml_prediction_mem);
        ml_required_cores = ml_prediction_mem[0];

        if (ml_required_cores < 1 || ml_required_cores > 4)
            $fatal(1, "Invalid ML prediction: %0d", ml_required_cores);

        $display("ML predicted core count = %0d", ml_required_cores);

        repeat (3) @(negedge clk);

        // Initialize instruction memories with NOPs.
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // ADDI x1,x0,10; ADDI x2,x0,20; ADD x3,x1,x2
        dut.core0.instruction_memory_unit.memory[0] = 32'h00A00093;
        dut.core0.instruction_memory_unit.memory[1] = 32'h01400113;
        dut.core0.instruction_memory_unit.memory[2] = 32'h002081B3;

        dut.core1.instruction_memory_unit.memory[0] = 32'h00A00093;
        dut.core1.instruction_memory_unit.memory[1] = 32'h01400113;
        dut.core1.instruction_memory_unit.memory[2] = 32'h002081B3;

        dut.core2.instruction_memory_unit.memory[0] = 32'h00A00093;
        dut.core2.instruction_memory_unit.memory[1] = 32'h01400113;
        dut.core2.instruction_memory_unit.memory[2] = 32'h002081B3;

        dut.core3.instruction_memory_unit.memory[0] = 32'h00A00093;
        dut.core3.instruction_memory_unit.memory[1] = 32'h01400113;
        dut.core3.instruction_memory_unit.memory[2] = 32'h002081B3;

        @(negedge clk);
        reset = 1'b0;

        check_cores(3'd0, 4'b0000);
        check_cores(3'd1, 4'b0001);
        check_cores(3'd2, 4'b0011);
        check_cores(3'd3, 4'b0111);
        check_cores(3'd4, 4'b1111);

        // Execute the program on two cores.
        @(negedge clk);
        required_cores = 3'd2;

        repeat (8) @(negedge clk);

        if (dut.core0.register_file_unit.registers[3] !== 32'd30)
            $fatal(1, "Core 0 failed: x3 is not 30");

        if (dut.core1.register_file_unit.registers[3] !== 32'd30)
            $fatal(1, "Core 1 failed: x3 is not 30");

        $display("PASS: RISC-V execution");
        $display("Core 0 x3 = %0d",
                 dut.core0.register_file_unit.registers[3]);
        $display("Core 1 x3 = %0d",
                 dut.core1.register_file_unit.registers[3]);

        $display("Core 0 instruction count = %0d", core0_instruction_count);
        $display("Core 1 instruction count = %0d", core1_instruction_count);
        $display("Core 2 instruction count = %0d", core2_instruction_count);
        $display("Core 3 instruction count = %0d", core3_instruction_count);

        // Capture counters before starting the separate vector workload.
        print_counter_csv();

        // Start vector addition using the ML-predicted core count.
        workload_size = 32'd8;

        @(negedge clk);
        required_cores = ml_required_cores;
        #1;

        if (core_enable !== ((4'b1111 >> (4 - ml_required_cores)) & 4'b1111))
            $fatal(1, "Core enable mask does not match ML prediction");

        $display("ML core prediction = %0d", ml_required_cores);
        $display("Core enable mask = %b", core_enable);

        @(negedge clk);
        workload_start = 1'b1;

        @(negedge clk);
        workload_start = 1'b0;

        fork
            begin
                wait (workload_done === 1'b1);
            end
            begin
                repeat (30) @(negedge clk);
                if (workload_done !== 1'b1)
                    $fatal(1, "TIMEOUT: vector workload did not finish");
            end
        join_any
        disable fork;

        #1;

        if (vector_c0 !== 32'd11 ||
            vector_c1 !== 32'd22 ||
            vector_c2 !== 32'd33 ||
            vector_c3 !== 32'd44 ||
            vector_c4 !== 32'd55 ||
            vector_c5 !== 32'd66 ||
            vector_c6 !== 32'd77 ||
            vector_c7 !== 32'd88) begin

            $display("FAIL: vector addition outputs incorrect");
            $display("C = %0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d",
                vector_c0, vector_c1, vector_c2, vector_c3,
                vector_c4, vector_c5, vector_c6, vector_c7);
            $fatal(1, "Vector addition test failed");
        end

        $display("PASS: parallel vector addition");
        $display("C = %0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d",
            vector_c0, vector_c1, vector_c2, vector_c3,
            vector_c4, vector_c5, vector_c6, vector_c7);

        $display("PASS: Complete multicore_system testbench");
        $finish;
    end

endmodule

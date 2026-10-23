
`timescale 1ns/1ps

module tb_ai_fibonacci_demo;

    reg clk;
    reg reset;
    reg [2:0] required_cores;
    reg workload_start;
    reg [31:0] workload_size;

    wire [3:0] core_enable;
    wire workload_done;

    wire [31:0] vector_c0, vector_c1, vector_c2, vector_c3;
    wire [31:0] vector_c4, vector_c5, vector_c6, vector_c7;

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

    reg [3:0] ml_prediction_mem [0:0];
    integer i;
    integer active_count;

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

    initial begin
        reset = 1'b1;
        required_cores = 3'd0;
        workload_start = 1'b0;
        workload_size = 32'd0;

        // Initialize all instruction memories to NOP.
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // Each core calculates a different Fibonacci number.
        // x1 = 0, x2 = 1, x3 = iteration count.
        // Loop body: x4=x1+x2; x1=x2; x2=x4; x3=x3-1.
        // x2 holds the final Fibonacci result.

        // Core 0: 4 iterations -> F(5) = 5
        dut.core0.instruction_memory_unit.memory[0] = 32'h00000093;
        dut.core0.instruction_memory_unit.memory[1] = 32'h00100113;
        dut.core0.instruction_memory_unit.memory[2] = 32'h00400193;
        dut.core0.instruction_memory_unit.memory[3] = 32'h00208233;
        dut.core0.instruction_memory_unit.memory[4] = 32'h00010093;
        dut.core0.instruction_memory_unit.memory[5] = 32'h00020113;
        dut.core0.instruction_memory_unit.memory[6] = 32'hFFF18193;
        dut.core0.instruction_memory_unit.memory[7] = 32'h00018463;
        dut.core0.instruction_memory_unit.memory[8] = 32'hFE0006E3;

        // Core 1: 5 iterations -> F(6) = 8
        dut.core1.instruction_memory_unit.memory[0] = 32'h00000093;
        dut.core1.instruction_memory_unit.memory[1] = 32'h00100113;
        dut.core1.instruction_memory_unit.memory[2] = 32'h00500193;
        dut.core1.instruction_memory_unit.memory[3] = 32'h00208233;
        dut.core1.instruction_memory_unit.memory[4] = 32'h00010093;
        dut.core1.instruction_memory_unit.memory[5] = 32'h00020113;
        dut.core1.instruction_memory_unit.memory[6] = 32'hFFF18193;
        dut.core1.instruction_memory_unit.memory[7] = 32'h00018463;
        dut.core1.instruction_memory_unit.memory[8] = 32'hFE0006E3;

        // Core 2: 6 iterations -> F(7) = 13
        dut.core2.instruction_memory_unit.memory[0] = 32'h00000093;
        dut.core2.instruction_memory_unit.memory[1] = 32'h00100113;
        dut.core2.instruction_memory_unit.memory[2] = 32'h00600193;
        dut.core2.instruction_memory_unit.memory[3] = 32'h00208233;
        dut.core2.instruction_memory_unit.memory[4] = 32'h00010093;
        dut.core2.instruction_memory_unit.memory[5] = 32'h00020113;
        dut.core2.instruction_memory_unit.memory[6] = 32'hFFF18193;
        dut.core2.instruction_memory_unit.memory[7] = 32'h00018463;
        dut.core2.instruction_memory_unit.memory[8] = 32'hFE0006E3;

        // Core 3: 7 iterations -> F(8) = 21
        dut.core3.instruction_memory_unit.memory[0] = 32'h00000093;
        dut.core3.instruction_memory_unit.memory[1] = 32'h00100113;
        dut.core3.instruction_memory_unit.memory[2] = 32'h00700193;
        dut.core3.instruction_memory_unit.memory[3] = 32'h00208233;
        dut.core3.instruction_memory_unit.memory[4] = 32'h00010093;
        dut.core3.instruction_memory_unit.memory[5] = 32'h00020113;
        dut.core3.instruction_memory_unit.memory[6] = 32'hFFF18193;
        dut.core3.instruction_memory_unit.memory[7] = 32'h00018463;
        dut.core3.instruction_memory_unit.memory[8] = 32'hFE0006E3;

        // Read the prediction produced by the existing Python model.
        #1;
        $readmemh("ml_prediction.mem", ml_prediction_mem);

        if (ml_prediction_mem[0] < 1 || ml_prediction_mem[0] > 4)
            $fatal(1, "Invalid ML core prediction");

        required_cores = ml_prediction_mem[0];

        repeat (3) @(negedge clk);
        reset = 1'b0;

        #1;
        $display("");
        $display("=== AI-DRIVEN PARALLEL FIBONACCI DEMO ===");
        $display("ML predicted cores: %0d", required_cores);
        $display("Core enable mask: %b", core_enable);

        active_count = 0;
        for (i = 0; i < 4; i = i + 1)
            if (core_enable[i])
                active_count = active_count + 1;

        if (active_count != required_cores)
            $fatal(1, "Core-enable mask does not match ML prediction");

        // Fixed observation window. Counters include enabled NOP cycles
        // after a core finishes, so they are not exact task latencies.
        repeat (90) @(negedge clk);

        if (core_enable[0] &&
            dut.core0.register_file_unit.registers[2] !== 32'd5)
            $fatal(1, "Core 0 Fibonacci result incorrect");

        if (core_enable[1] &&
            dut.core1.register_file_unit.registers[2] !== 32'd8)
            $fatal(1, "Core 1 Fibonacci result incorrect");

        if (core_enable[2] &&
            dut.core2.register_file_unit.registers[2] !== 32'd13)
            $fatal(1, "Core 2 Fibonacci result incorrect");

        if (core_enable[3] &&
            dut.core3.register_file_unit.registers[2] !== 32'd21)
            $fatal(1, "Core 3 Fibonacci result incorrect");

        $display("");
        $display("Core,Enabled,Fibonacci_Result,Cycles,Instructions,ALU,Branches,Taken");

        $display("0,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
            core_enable[0],
            dut.core0.register_file_unit.registers[2],
            core0_cycle_count, core0_instruction_count,
            core0_alu_count, core0_branch_count,
            core0_branch_taken_count);

        $display("1,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
            core_enable[1],
            dut.core1.register_file_unit.registers[2],
            core1_cycle_count, core1_instruction_count,
            core1_alu_count, core1_branch_count,
            core1_branch_taken_count);

        $display("2,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
            core_enable[2],
            dut.core2.register_file_unit.registers[2],
            core2_cycle_count, core2_instruction_count,
            core2_alu_count, core2_branch_count,
            core2_branch_taken_count);

        $display("3,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
            core_enable[3],
            dut.core3.register_file_unit.registers[2],
            core3_cycle_count, core3_instruction_count,
            core3_alu_count, core3_branch_count,
            core3_branch_taken_count);

        $display("");
        $display("PASS: ML prediction controls core activation");
        $display("PASS: Active cores completed independent Fibonacci tasks");
        $display("PASS: Performance counters collected");
        $finish;
    end

endmodule

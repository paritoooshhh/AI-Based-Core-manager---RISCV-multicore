`timescale 1ns/1ps

module workload_fibonacci_tb;

    reg clk;
    reg reset;
    reg [2:0] required_cores;

    wire [3:0] core_enable;
    wire workload_done;

    wire [31:0] cycles;
    wire [31:0] instructions;
    wire [31:0] alu_count;
    wire [31:0] load_count;
    wire [31:0] store_count;
    wire [31:0] branch_count;
    wire [31:0] taken_count;

    integer i;
    integer requested_arg;

    always #5 clk = ~clk;

    multicore_system dut (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .core_enable(core_enable),
        .workload_start(1'b0),
        .workload_size(32'd0),
        .workload_done(workload_done),

        .core0_cycle_count(cycles),
        .core0_instruction_count(instructions),
        .core0_alu_count(alu_count),
        .core0_load_count(load_count),
        .core0_store_count(store_count),
        .core0_branch_count(branch_count),
        .core0_branch_taken_count(taken_count)
    );

    initial begin
        clk = 0;
        reset = 1;
        required_cores = 0;

        // Initialize instruction memory on all four cores.
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // Fibonacci program on core 0.
        // x1 = previous Fibonacci number
        // x2 = current Fibonacci number
        // x3 = remaining iterations
        // x4 = next Fibonacci number

        dut.core0.instruction_memory_unit.memory[0] = 32'h00000093; // ADDI x1,x0,0
        dut.core0.instruction_memory_unit.memory[1] = 32'h00100113; // ADDI x2,x0,1
        dut.core0.instruction_memory_unit.memory[2] = 32'h00800193; // ADDI x3,x0,8

        // Loop starts at instruction index 3.
        dut.core0.instruction_memory_unit.memory[3] = 32'h00208233; // ADD x4,x1,x2
        dut.core0.instruction_memory_unit.memory[4] = 32'h00010093; // ADDI x1,x2,0
        dut.core0.instruction_memory_unit.memory[5] = 32'h00020113; // ADDI x2,x4,0
        dut.core0.instruction_memory_unit.memory[6] = 32'hFFF18193; // ADDI x3,x3,-1
        dut.core0.instruction_memory_unit.memory[7] = 32'h00018463; // BEQ x3,x0,+8
        dut.core0.instruction_memory_unit.memory[8] = 32'hFE0006E3; // BEQ x0,x0,-20

        // After eight iterations:
        // x1 = 21, x2 = 34, x3 = 0, x4 = 34.

        #1;
        if (!$value$plusargs("CORES=%d", requested_arg))
            requested_arg = 1;

        if (requested_arg < 1 || requested_arg > 4) begin
            $display("ERROR: CORES must be 1, 2, 3, or 4");
            $finish;
        end

        required_cores = requested_arg;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Allow the loop to finish and counters to settle.
        repeat (75) @(posedge clk);
        @(negedge clk);
        #1;

        $display("WORKLOAD,fibonacci,requested_cores,%0d", required_cores);
        $display("DEBUG: core_enable=%b", core_enable);

        $display(
            "COUNTER_CSV,core_id,cycles,instructions,alu,loads,stores,branches,branches_taken"
        );

        $display("COUNTER_CSV,0,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 cycles, instructions, alu_count, load_count,
                 store_count, branch_count, taken_count);

        $display("DEBUG: x1=%0d x2=%0d x3=%0d x4=%0d",
                 dut.core0.register_file_unit.registers[1],
                 dut.core0.register_file_unit.registers[2],
                 dut.core0.register_file_unit.registers[3],
                 dut.core0.register_file_unit.registers[4]);

        if (dut.core0.register_file_unit.registers[1] === 32'd21 &&
            dut.core0.register_file_unit.registers[2] === 32'd34 &&
            dut.core0.register_file_unit.registers[3] === 32'd0 &&
            dut.core0.register_file_unit.registers[4] === 32'd34)
            $display("PASS: Fibonacci result");
        else
            $display("FAIL: Fibonacci result");

        if (taken_count >= 1)
            $display("PASS: Fibonacci loop branches");
        else
            $display("FAIL: Fibonacci loop branches");

        $display("Fibonacci workload test completed.");
        $finish;
    end

endmodule
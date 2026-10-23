`timescale 1ns/1ps
module workload_branch_tb;

    reg clk;
    reg reset;
    reg [2:0] required_cores;

    wire [3:0] core_enable;
    wire workload_done;

    wire [31:0] vector_c0, vector_c1, vector_c2, vector_c3;
    wire [31:0] vector_c4, vector_c5, vector_c6, vector_c7;

    wire [31:0] c0_cycles, c0_instr, c0_alu, c0_load, c0_store, c0_branch, c0_taken;
    wire [31:0] c1_cycles, c1_instr, c1_alu, c1_load, c1_store, c1_branch, c1_taken;
    wire [31:0] c2_cycles, c2_instr, c2_alu, c2_load, c2_store, c2_branch, c2_taken;
    wire [31:0] c3_cycles, c3_instr, c3_alu, c3_load, c3_store, c3_branch, c3_taken;

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

        .vector_c0(vector_c0), .vector_c1(vector_c1),
        .vector_c2(vector_c2), .vector_c3(vector_c3),
        .vector_c4(vector_c4), .vector_c5(vector_c5),
        .vector_c6(vector_c6), .vector_c7(vector_c7),

        .core0_cycle_count(c0_cycles),
        .core0_instruction_count(c0_instr),
        .core0_alu_count(c0_alu),
        .core0_load_count(c0_load),
        .core0_store_count(c0_store),
        .core0_branch_count(c0_branch),
        .core0_branch_taken_count(c0_taken),

        .core1_cycle_count(c1_cycles),
        .core1_instruction_count(c1_instr),
        .core1_alu_count(c1_alu),
        .core1_load_count(c1_load),
        .core1_store_count(c1_store),
        .core1_branch_count(c1_branch),
        .core1_branch_taken_count(c1_taken),

        .core2_cycle_count(c2_cycles),
        .core2_instruction_count(c2_instr),
        .core2_alu_count(c2_alu),
        .core2_load_count(c2_load),
        .core2_store_count(c2_store),
        .core2_branch_count(c2_branch),
        .core2_branch_taken_count(c2_taken),

        .core3_cycle_count(c3_cycles),
        .core3_instruction_count(c3_instr),
        .core3_alu_count(c3_alu),
        .core3_load_count(c3_load),
        .core3_store_count(c3_store),
        .core3_branch_count(c3_branch),
        .core3_branch_taken_count(c3_taken)
    );

    initial begin
        clk = 0;
        reset = 1;
        required_cores = 0;

        // Initialize all instruction memories to NOP.
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // Core 0 branch program.
        dut.core0.instruction_memory_unit.memory[0] = 32'h00100093; // ADDI x1,x0,1
        dut.core0.instruction_memory_unit.memory[1] = 32'h00100113; // ADDI x2,x0,1
        dut.core0.instruction_memory_unit.memory[2] = 32'h00208463; // BEQ x1,x2,+8 (taken)
        dut.core0.instruction_memory_unit.memory[3] = 32'h06300193; // ADDI x3,x0,99 (skipped)
        dut.core0.instruction_memory_unit.memory[4] = 32'h00008463; // BEQ x1,x0,+8 (not taken)
        dut.core0.instruction_memory_unit.memory[5] = 32'h00700213; // ADDI x4,x0,7

        // Initialize registers checked by the test.
        // x3 should stay zero because its instruction is skipped.
        dut.core0.register_file_unit.registers[3] = 32'd0;
        dut.core0.register_file_unit.registers[4] = 32'd0;

        // Read requested core count from command-line plusarg.
        #1;
        if (!$value$plusargs("CORES=%d", requested_arg))
            requested_arg = 1;

        if (requested_arg < 1 || requested_arg > 4) begin
            $display("ERROR: CORES must be 1, 2, 3, or 4");
            $finish;
        end

        required_cores = requested_arg;

        // Hold reset for three rising edges.
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Execute the branch program followed by NOPs.
        repeat (12) @(posedge clk);
        @(negedge clk);
        #1;

        $display("DEBUG: required_cores=%b core_enable=%b",
                 required_cores, core_enable);

        $display("WORKLOAD,branch,requested_cores,%0d", required_cores);
        $display("COUNTER_CSV,core_id,cycles,instructions,alu,loads,stores,branches,branches_taken");

        $display("COUNTER_CSV,0,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 c0_cycles, c0_instr, c0_alu, c0_load, c0_store,
                 c0_branch, c0_taken);

        $display("COUNTER_CSV,1,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 c1_cycles, c1_instr, c1_alu, c1_load, c1_store,
                 c1_branch, c1_taken);

        $display("COUNTER_CSV,2,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 c2_cycles, c2_instr, c2_alu, c2_load, c2_store,
                 c2_branch, c2_taken);

        $display("COUNTER_CSV,3,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                 c3_cycles, c3_instr, c3_alu, c3_load, c3_store,
                 c3_branch, c3_taken);

        if (c0_taken >= 1)
            $display("PASS: branch taken");
        else
            $display("FAIL: no taken branch detected");

        $display("DEBUG: x1=%0d x2=%0d x3=%0d x4=%0d",
                 dut.core0.register_file_unit.registers[1],
                 dut.core0.register_file_unit.registers[2],
                 dut.core0.register_file_unit.registers[3],
                 dut.core0.register_file_unit.registers[4]);

        $display("DEBUG: PC=%0d", dut.core0.pc_value);

        if (dut.core0.register_file_unit.registers[3] === 32'd0 &&
            dut.core0.register_file_unit.registers[4] === 32'd7)
            $display("PASS: branch program result");
        else
            $display("FAIL: branch program result");

        $display("Branch workload test completed.");
        $finish;
    end

endmodule
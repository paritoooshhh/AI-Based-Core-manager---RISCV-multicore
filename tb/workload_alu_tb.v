`timescale 1ns/1ps

module workload_alu_tb;

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
        // Initialize signals explicitly after simulation starts.
        clk = 1'b0;
        reset = 1'b1;
        required_cores = 3'd0;

        // Initialize all instruction memories with NOPs.
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // Core 0: x1 = x1 + 1, repeated 20 times.
        // ADDI x1, x1, 1
        for (i = 0; i < 20; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00108093;
        end

        // Release the core manager's initial zero-core setting.
        // Change required_cores at a later simulation time so its
        // combinational logic is triggered reliably.
        #1;
        #1;
if (!$value$plusargs("CORES=%d", requested_arg))
    requested_arg = 1;

if (requested_arg < 1 || requested_arg > 4) begin
    $display("ERROR: CORES must be 1, 2, 3, or 4");
    $finish;
end

required_cores = requested_arg;
        // Keep reset asserted for three clock edges.
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Allow the combinational signals and counters to settle.
        #1;
        $display("DEBUG: reset=%b required_cores=%b core_enable=%b",
                 reset, required_cores, core_enable);

        $display("DEBUG: manager outputs=%b%b%b%b",
                 dut.core_manager_unit.core3_enable,
                 dut.core_manager_unit.core2_enable,
                 dut.core_manager_unit.core1_enable,
                 dut.core_manager_unit.core0_enable);

        // Run the ALU workload for a fixed window.
        repeat (25) @(posedge clk);
        @(negedge clk);
        #1;

        $display("DEBUG FINAL: core_enable=%b", core_enable);
        $display("DEBUG FINAL: core0 PC=%0d cycles=%0d instructions=%0d",
                 dut.core0.pc_value, c0_cycles, c0_instr);

        $display("WORKLOAD,alu,requested_cores,%0d", required_cores);
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

        $display("ALU workload test completed.");
        $finish;
    end

endmodule
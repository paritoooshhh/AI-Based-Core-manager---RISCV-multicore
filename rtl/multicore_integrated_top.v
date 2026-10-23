// Unified project top: preserves the original vector/RISC-V system and adds
// the controller-driven CPU workload path plus result combiner.
// The original multicore_system RTL is not modified by this wrapper.
module multicore_integrated_system (
    input clk,
    input reset,
    input [2:0] required_cores,

    // Original vector-accelerator interface
    input vector_workload_start,
    input [31:0] vector_workload_size,
    output vector_workload_done,
    output [31:0] vector_c0, vector_c1, vector_c2, vector_c3,
    output [31:0] vector_c4, vector_c5, vector_c6, vector_c7,
    output [3:0] original_core_enable,

    // Controller-partitioned CPU workload interface
    input cpu_workload_start,
    input [31:0] cpu_workload_size,
    output [3:0] cpu_core_enable,
    output cpu_workload_done,
    output [31:0] cpu_core0_result, cpu_core1_result,
    output [31:0] cpu_core2_result, cpu_core3_result,
    output [31:0] cpu_final_result,
    output cpu_result_valid
);

    // Original multicore_system has additional performance-counter outputs.
    // Keep them connected internally while preserving its existing module.
    wire [31:0] c0_cycles, c0_inst, c0_alu, c0_load, c0_store, c0_branch, c0_taken;
    wire [31:0] c1_cycles, c1_inst, c1_alu, c1_load, c1_store, c1_branch, c1_taken;
    wire [31:0] c2_cycles, c2_inst, c2_alu, c2_load, c2_store, c2_branch, c2_taken;
    wire [31:0] c3_cycles, c3_inst, c3_alu, c3_load, c3_store, c3_branch, c3_taken;

    multicore_system original_system (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .core_enable(original_core_enable),
        .workload_start(vector_workload_start),
        .workload_size(vector_workload_size),
        .workload_done(vector_workload_done),
        .vector_c0(vector_c0), .vector_c1(vector_c1),
        .vector_c2(vector_c2), .vector_c3(vector_c3),
        .vector_c4(vector_c4), .vector_c5(vector_c5),
        .vector_c6(vector_c6), .vector_c7(vector_c7),
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

    multicore_cpu_workload_system cpu_workload_system (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .workload_start(cpu_workload_start),
        .workload_size(cpu_workload_size),
        .core_enable(cpu_core_enable),
        .workload_done(cpu_workload_done),
        .core0_result(cpu_core0_result),
        .core1_result(cpu_core1_result),
        .core2_result(cpu_core2_result),
        .core3_result(cpu_core3_result),
        .core0_cycles(), .core1_cycles(),
        .core2_cycles(), .core3_cycles(),
        .core0_alu(), .core1_alu(),
        .core2_alu(), .core3_alu()
    );

    result_combiner cpu_result_combiner (
        .core0_result(cpu_core0_result),
        .core1_result(cpu_core1_result),
        .core2_result(cpu_core2_result),
        .core3_result(cpu_core3_result),
        .valid_mask(cpu_core_enable),
        .workload_done(cpu_workload_done),
        .final_result(cpu_final_result),
        .result_valid(cpu_result_valid)
    );

endmodule

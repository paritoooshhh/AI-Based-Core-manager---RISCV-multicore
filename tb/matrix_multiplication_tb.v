
`timescale 1ns/1ps

module tb_single_core_addition;

    reg clk;
    reg reset;
    reg [2:0] required_cores;

    wire [3:0] core_enable;
    wire workload_done;

    wire [31:0] vector_c0, vector_c1;
    wire [31:0] vector_c2, vector_c3;
    wire [31:0] vector_c4, vector_c5;
    wire [31:0] vector_c6, vector_c7;

    wire [31:0] core0_cycle_count;
    wire [31:0] core0_instruction_count;
    wire [31:0] core0_alu_count;
    wire [31:0] core0_load_count;
    wire [31:0] core0_store_count;
    wire [31:0] core0_branch_count;
    wire [31:0] core0_branch_taken_count;

    wire [31:0] core1_cycle_count;
    wire [31:0] core1_instruction_count;
    wire [31:0] core1_alu_count;
    wire [31:0] core1_load_count;
    wire [31:0] core1_store_count;
    wire [31:0] core1_branch_count;
    wire [31:0] core1_branch_taken_count;

    wire [31:0] core2_cycle_count;
    wire [31:0] core2_instruction_count;
    wire [31:0] core2_alu_count;
    wire [31:0] core2_load_count;
    wire [31:0] core2_store_count;
    wire [31:0] core2_branch_count;
    wire [31:0] core2_branch_taken_count;

    wire [31:0] core3_cycle_count;
    wire [31:0] core3_instruction_count;
    wire [31:0] core3_alu_count;
    wire [31:0] core3_load_count;
    wire [31:0] core3_store_count;
    wire [31:0] core3_branch_count;
    wire [31:0] core3_branch_taken_count;

    reg [3:0] ml_prediction_mem [0:0];
    reg [3:0] ml_required_cores;

    integer i;

    // ------------------------------------------------
    // DUT: actual multicore_system interface
    // ------------------------------------------------
    multicore_system dut (
        .clk(clk),
        .reset(reset),
        .required_cores(required_cores),
        .core_enable(core_enable),

        .workload_start(1'b0),
        .workload_size(32'd0),
        .workload_done(workload_done),

        .vector_c0(vector_c0),
        .vector_c1(vector_c1),
        .vector_c2(vector_c2),
        .vector_c3(vector_c3),
        .vector_c4(vector_c4),
        .vector_c5(vector_c5),
        .vector_c6(vector_c6),
        .vector_c7(vector_c7),

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

    // 100 MHz simulation clock
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        required_cores = 0;
        ml_required_cores = 0;

        // --------------------------------------------
        // 1. Read prediction from Python ML model
        // --------------------------------------------
        $readmemh("ml_prediction.mem", ml_prediction_mem);
        ml_required_cores = ml_prediction_mem[0];

        if (ml_required_cores < 1 || ml_required_cores > 4)
            $fatal(1, "FAIL: Invalid ML core prediction");

        // Apply ML prediction to the RTL input
        required_cores = ml_required_cores;

        // --------------------------------------------
        // 2. Initialize core instruction memories
        // --------------------------------------------
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // --------------------------------------------
        // 3. Core 0 computes 10 + 20 = 30
        // --------------------------------------------
        dut.core0.instruction_memory_unit.memory[0] = 32'h00A00093;
        dut.core0.instruction_memory_unit.memory[1] = 32'h01400113;
        dut.core0.instruction_memory_unit.memory[2] = 32'h002081B3;

        // Release reset
        repeat (3) @(negedge clk);
        reset = 0;

        // Allow the enable logic to settle
        repeat (1) @(negedge clk);
        #1;

        $display("");
        $display("========================================");
        $display("      ML-DRIVEN ADDITION TEST");
        $display("========================================");
        $display("Predicted cores : %0d", ml_required_cores);
        $display("Requested cores : %0d", required_cores);
        $display("Core enable mask: %b", core_enable);

        // --------------------------------------------
        // 4. Verify ML prediction reached the RTL
        // --------------------------------------------
        case (ml_required_cores)
            1: if (core_enable !== 4'b0001)
                   $fatal(1, "FAIL: Expected mask 0001");
            2: if (core_enable !== 4'b0011)
                   $fatal(1, "FAIL: Expected mask 0011");
            3: if (core_enable !== 4'b0111)
                   $fatal(1, "FAIL: Expected mask 0111");
            4: if (core_enable !== 4'b1111)
                   $fatal(1, "FAIL: Expected mask 1111");
        endcase

        $display("PASS: RTL mask matches ML prediction");

        // --------------------------------------------
        // 5. Wait for instructions to execute
        // --------------------------------------------
        repeat (15) @(negedge clk);
        #1;

        $display("");
        $display("--------------- RESULTS ----------------");
        $display("Core 0: %0d + %0d = %0d",
            dut.core0.register_file_unit.registers[1],
            dut.core0.register_file_unit.registers[2],
            dut.core0.register_file_unit.registers[3]);

        $display("Core 0 cycles              : %0d",
                 core0_cycle_count);
        $display("Core 0 instruction counter  : %0d",
                 core0_instruction_count);
        $display("Core 0 ALU counter          : %0d",
                 core0_alu_count);

        // --------------------------------------------
        // 6. Check arithmetic result
        // --------------------------------------------
        if (dut.core0.register_file_unit.registers[3] !== 32'd30)
            $fatal(1, "FAIL: 10 + 20 did not equal 30");

        $display("PASS: 10 + 20 = 30");
        $display("========================================");
        $display("PASS: ML-DRIVEN ADDITION TEST");
        $display("========================================");

        $finish;
    end

endmodule

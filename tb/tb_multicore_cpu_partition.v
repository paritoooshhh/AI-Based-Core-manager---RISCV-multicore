`timescale 1ns/1ps

// Genuine CPU workload test: each RISC-V core independently computes
// two vector sums using its own instruction memory and register file.
// Core 0: 1+10=11, 2+20=22
// Core 1: 3+30=33, 4+40=44
// Core 2: 5+50=55, 6+60=66
// Core 3: 7+70=77, 8+80=88
// This is static partitioning programmed by the testbench; the existing
// workload controller/vector FSM is not yet connected to CPU execution.

module tb_multicore_cpu_partition;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [2:0] required_cores;
    reg workload_start = 1'b0;
    reg [31:0] workload_size = 32'd8;

    wire [3:0] core_enable;
    wire workload_done;
    wire [31:0] vc0,vc1,vc2,vc3,vc4,vc5,vc6,vc7;

    wire [31:0] cc0,ic0,ac0,lc0,sc0,bc0,btc0;
    wire [31:0] cc1,ic1,ac1,lc1,sc1,bc1,btc1;
    wire [31:0] cc2,ic2,ac2,lc2,sc2,bc2,btc2;
    wire [31:0] cc3,ic3,ac3,lc3,sc3,bc3,btc3;

    integer i;
    integer failures = 0;

    always #5 clk = ~clk;

    multicore_system dut (
        .clk(clk), .reset(reset),
        .required_cores(required_cores), .core_enable(core_enable),
        .workload_start(workload_start), .workload_size(workload_size),
        .workload_done(workload_done),
        .vector_c0(vc0), .vector_c1(vc1), .vector_c2(vc2), .vector_c3(vc3),
        .vector_c4(vc4), .vector_c5(vc5), .vector_c6(vc6), .vector_c7(vc7),
        .core0_cycle_count(cc0), .core0_instruction_count(ic0), .core0_alu_count(ac0),
        .core0_load_count(lc0), .core0_store_count(sc0), .core0_branch_count(bc0), .core0_branch_taken_count(btc0),
        .core1_cycle_count(cc1), .core1_instruction_count(ic1), .core1_alu_count(ac1),
        .core1_load_count(lc1), .core1_store_count(sc1), .core1_branch_count(bc1), .core1_branch_taken_count(btc1),
        .core2_cycle_count(cc2), .core2_instruction_count(ic2), .core2_alu_count(ac2),
        .core2_load_count(lc2), .core2_store_count(sc2), .core2_branch_count(bc2), .core2_branch_taken_count(btc2),
        .core3_cycle_count(cc3), .core3_instruction_count(ic3), .core3_alu_count(ac3),
        .core3_load_count(lc3), .core3_store_count(sc3), .core3_branch_count(bc3), .core3_branch_taken_count(btc3)
    );

    task check_reg;
        input [31:0] actual;
        input [31:0] expected;
        input [255:0] label_text;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s expected=%0d (0x%08h), actual=%0d (0x%08h)",
                         label_text, expected, expected, actual, actual);
                failures = failures + 1;
            end else begin
                $display("PASS: %0s = %0d", label_text, actual);
            end
        end
    endtask

    initial begin
        $display("\n=== FOUR-CORE CPU PARTITIONED ADD TEST ===");

        // Initialize instruction memories to NOP before writing each program.
        for (i = 0; i < 256; i = i + 1) begin
            dut.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            dut.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end

        // Core 0: calculate 1+10 and 2+20.
        dut.core0.instruction_memory_unit.memory[0] = 32'h00100093; // ADDI x1,x0,1
        dut.core0.instruction_memory_unit.memory[1] = 32'h00A00113; // ADDI x2,x0,10
        dut.core0.instruction_memory_unit.memory[2] = 32'h002081B3; // ADD x3,x1,x2
        dut.core0.instruction_memory_unit.memory[3] = 32'h00200213; // ADDI x4,x0,2
        dut.core0.instruction_memory_unit.memory[4] = 32'h01400293; // ADDI x5,x0,20
        dut.core0.instruction_memory_unit.memory[5] = 32'h00520333; // ADD x6,x4,x5

        // Core 1: calculate 3+30 and 4+40.
        dut.core1.instruction_memory_unit.memory[0] = 32'h00300093;
        dut.core1.instruction_memory_unit.memory[1] = 32'h01E00113;
        dut.core1.instruction_memory_unit.memory[2] = 32'h002081B3;
        dut.core1.instruction_memory_unit.memory[3] = 32'h00400213;
        dut.core1.instruction_memory_unit.memory[4] = 32'h02800293;
        dut.core1.instruction_memory_unit.memory[5] = 32'h00520333;

        // Core 2: calculate 5+50 and 6+60.
        dut.core2.instruction_memory_unit.memory[0] = 32'h00500093;
        dut.core2.instruction_memory_unit.memory[1] = 32'h03200113;
        dut.core2.instruction_memory_unit.memory[2] = 32'h002081B3;
        dut.core2.instruction_memory_unit.memory[3] = 32'h00600213;
        dut.core2.instruction_memory_unit.memory[4] = 32'h03C00293;
        dut.core2.instruction_memory_unit.memory[5] = 32'h00520333;

        // Core 3: calculate 7+70 and 8+80.
        dut.core3.instruction_memory_unit.memory[0] = 32'h00700093;
        dut.core3.instruction_memory_unit.memory[1] = 32'h04600113;
        dut.core3.instruction_memory_unit.memory[2] = 32'h002081B3;
        dut.core3.instruction_memory_unit.memory[3] = 32'h00800213;
        dut.core3.instruction_memory_unit.memory[4] = 32'h05000293;
        dut.core3.instruction_memory_unit.memory[5] = 32'h00520333;

        // Force a real input transition so combinational core_manager evaluates.
        required_cores = 3'd0;
        #1;
        required_cores = 3'd4;

        repeat (2) @(negedge clk);
        reset = 1'b1;
        repeat (2) @(negedge clk);
        reset = 1'b0;

        // Six useful instructions per core, followed by NOPs.
        repeat (10) @(posedge clk);
        #1;

        $display("core_enable=%b", core_enable);
        if (core_enable !== 4'b1111) begin
            $display("FAIL: expected all four cores enabled");
            failures = failures + 1;
        end else begin
            $display("PASS: all four cores enabled concurrently");
        end

        $display("Cycle counters: %0d, %0d, %0d, %0d", cc0,cc1,cc2,cc3);
        if ((cc0 < 6) || (cc1 < 6) || (cc2 < 6) || (cc3 < 6)) begin
            $display("FAIL: one or more cores did not advance through the program");
            failures = failures + 1;
        end else begin
            $display("PASS: all four CPU cycle counters advanced");
        end

        $display("\n--- Verify CPU register results ---");
        check_reg(dut.core0.register_file_unit.registers[3], 32'd11, "core0 x3 (1+10)");
        check_reg(dut.core0.register_file_unit.registers[6], 32'd22, "core0 x6 (2+20)");
        check_reg(dut.core1.register_file_unit.registers[3], 32'd33, "core1 x3 (3+30)");
        check_reg(dut.core1.register_file_unit.registers[6], 32'd44, "core1 x6 (4+40)");
        check_reg(dut.core2.register_file_unit.registers[3], 32'd55, "core2 x3 (5+50)");
        check_reg(dut.core2.register_file_unit.registers[6], 32'd66, "core2 x6 (6+60)");
        check_reg(dut.core3.register_file_unit.registers[3], 32'd77, "core3 x3 (7+70)");
        check_reg(dut.core3.register_file_unit.registers[6], 32'd88, "core3 x6 (8+80)");

        $display("\nInstruction counters: %0d, %0d, %0d, %0d", ic0,ic1,ic2,ic3);
        $display("ALU counters: %0d, %0d, %0d, %0d", ac0,ac1,ac2,ac3);
        $display("NOTE: Each core ran its own statically assigned program concurrently.");
        $display("NOTE: This testbench does not yet connect the workload controller to CPU PCs.");

        if (failures == 0) begin
            $display("SUMMARY: failures=0");
            $display("RESULT: PASS");
        end else begin
            $display("SUMMARY: failures=%0d", failures);
            $display("RESULT: FAIL");
        end
        $finish;
    end

    initial begin
        #5000;
        $display("FAIL: global simulation timeout");
        $finish;
    end
endmodule

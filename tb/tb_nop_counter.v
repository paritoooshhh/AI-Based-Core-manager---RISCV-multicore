
`timescale 1ns/1ps

module tb_nop_counter;

  reg clk = 0;
  reg reset = 1;
  reg enable = 0;

  wire [31:0] cycles, instructions, alus;
  wire [31:0] loads, stores, branches, taken;

  integer i;
  integer failures = 0;

  always #5 clk = ~clk;

  riscv_core dut (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .cycle_count(cycles),
    .instruction_count(instructions),
    .alu_count(alus),
    .load_count(loads),
    .store_count(stores),
    .branch_count(branches),
    .branch_taken_count(taken)
  );

  initial begin
    $display("\n=== NOP / REAL ALU COUNTER TEST ===");

    // Initialize instruction memory to NOPs.
    for (i = 0; i < 256; i = i + 1)
      dut.instruction_memory_unit.memory[i] = 32'h00000013;

    // Program:
    // 0: NOP              -> ALU count +0
    // 1: ADDI x1,x0,5     -> ALU count +1
    // 2: ADDI x2,x1,3     -> ALU count +1
    // 3: ADD  x3,x1,x2    -> ALU count +1
    // 4-7: NOP padding    -> ALU count +0
    dut.instruction_memory_unit.memory[0] = 32'h00000013;
    dut.instruction_memory_unit.memory[1] = 32'h00500093;
    dut.instruction_memory_unit.memory[2] = 32'h00308113;
    dut.instruction_memory_unit.memory[3] = 32'h002081B3;

    // Hold reset across clock edges.
    #2;
    reset = 1;
    repeat (2) @(negedge clk);
    reset = 0;

    // Enable execution.
    @(negedge clk);
    enable = 1;

    repeat (8) @(posedge clk);
    #1;
    enable = 0;

    $display(
      "Observed cycles=%0d instructions=%0d alu=%0d",
      cycles, instructions, alus
    );
    $display(
      "Register values: x1=%0d x2=%0d x3=%0d",
      dut.register_file_unit.registers[1],
      dut.register_file_unit.registers[2],
      dut.register_file_unit.registers[3]
    );

    if (cycles !== 8) begin
      $display("FAIL: expected 8 cycles");
      failures = failures + 1;
    end

    if (alus !== 3) begin
      $display("FAIL: expected 3 ALU operations, got %0d", alus);
      failures = failures + 1;
    end else begin
      $display("PASS: NOPs excluded and real ALU operations counted");
    end

    if (dut.register_file_unit.registers[1] !== 32'd5 ||
        dut.register_file_unit.registers[2] !== 32'd8 ||
        dut.register_file_unit.registers[3] !== 32'd13) begin
      $display("FAIL: arithmetic results incorrect");
      failures = failures + 1;
    end else begin
      $display("PASS: ADDI and ADD results are correct");
    end

    $display("SUMMARY: failures=%0d", failures);
    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

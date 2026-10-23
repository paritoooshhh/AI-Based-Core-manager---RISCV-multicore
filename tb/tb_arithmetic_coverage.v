
`timescale 1ns/1ps

module tb_arithmetic_coverage;

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
    $display("\n=== RISC-V ARITHMETIC COVERAGE TEST ===");

    // Initialize instruction memory to NOPs.
    for (i = 0; i < 256; i = i + 1)
      dut.instruction_memory_unit.memory[i] = 32'h00000013;

    // x1 = 12
    dut.instruction_memory_unit.memory[0] = 32'h00C00093;
    // x2 = 5
    dut.instruction_memory_unit.memory[1] = 32'h00500113;
    // x3 = x1 + x2 = 17
    dut.instruction_memory_unit.memory[2] = 32'h002081B3;
    // x4 = x1 - x2 = 7
    dut.instruction_memory_unit.memory[3] = 32'h40208233;
    // x5 = x1 & x2 = 4
    dut.instruction_memory_unit.memory[4] = 32'h0020F2B3;
    // x6 = x1 | x2 = 13
    dut.instruction_memory_unit.memory[5] = 32'h0020E333;
    // x7 = x1 ^ x2 = 9
    dut.instruction_memory_unit.memory[6] = 32'h0020C3B3;
    // x8 = (x2 < x1), signed = 1
    dut.instruction_memory_unit.memory[7] = 32'h00112433;
    // x9 = (x2 < x1), unsigned = 1
    dut.instruction_memory_unit.memory[8] = 32'h001134B3;

    // Reset.
    repeat (2) @(negedge clk);
    reset = 0;

    // Execute nine instructions.
    @(negedge clk);
    enable = 1;
    repeat (9) @(posedge clk);
    #1;
    enable = 0;

    $display(
      "Counters: cycles=%0d instructions=%0d alu=%0d",
      cycles, instructions, alus
    );

    $display(
      "Registers: x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d",
      dut.register_file_unit.registers[1],
      dut.register_file_unit.registers[2],
      dut.register_file_unit.registers[3],
      dut.register_file_unit.registers[4],
      dut.register_file_unit.registers[5]
    );

    $display(
      "Registers: x6=%0d x7=%0d x8=%0d x9=%0d",
      dut.register_file_unit.registers[6],
      dut.register_file_unit.registers[7],
      dut.register_file_unit.registers[8],
      dut.register_file_unit.registers[9]
    );

    if (cycles !== 32'd9 || instructions !== 32'd9) begin
      $display("FAIL: expected 9 cycles and 9 instructions");
      failures = failures + 1;
    end else begin
      $display("PASS: cycle and instruction counts");
    end

    if (alus !== 32'd9) begin
      $display("FAIL: expected 9 ALU operations, got %0d", alus);
      failures = failures + 1;
    end else begin
      $display("PASS: all nine arithmetic instructions counted");
    end

    if (dut.register_file_unit.registers[1] !== 32'd12 ||
        dut.register_file_unit.registers[2] !== 32'd5 ||
        dut.register_file_unit.registers[3] !== 32'd17 ||
        dut.register_file_unit.registers[4] !== 32'd7 ||
        dut.register_file_unit.registers[5] !== 32'd4 ||
        dut.register_file_unit.registers[6] !== 32'd13 ||
        dut.register_file_unit.registers[7] !== 32'd9 ||
        dut.register_file_unit.registers[8] !== 32'd1 ||
        dut.register_file_unit.registers[9] !== 32'd1) begin
      $display("FAIL: one or more arithmetic results are incorrect");
      failures = failures + 1;
    end else begin
      $display("PASS: ADDI, ADD, SUB, AND, OR, XOR, SLT and SLTU");
    end

    if (loads !== 32'd0 || stores !== 32'd0 ||
        branches !== 32'd0 || taken !== 32'd0) begin
      $display("FAIL: unexpected memory or branch counts");
      failures = failures + 1;
    end else begin
      $display("PASS: memory and branch counters remain zero");
    end

    $display("SUMMARY: failures=%0d", failures);
    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

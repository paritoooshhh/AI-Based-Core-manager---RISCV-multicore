
`timescale 1ns/1ps

module tb_branch_not_taken;

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
    $display("\n=== BRANCH NOT-TAKEN COUNTER TEST ===");

    // Fill instruction memory with NOPs.
    for (i = 0; i < 256; i = i + 1)
      dut.instruction_memory_unit.memory[i] = 32'h00000013;

    // Program:
    // 0: ADDI x1,x0,42
    // 1: ADDI x2,x0,7
    // 2: BEQ x1,x2,+8  -> NOT taken because 42 != 7
    // 3: ADDI x3,x0,99 -> executes
    // 4: ADDI x4,x0,5  -> executes
    dut.instruction_memory_unit.memory[0] = 32'h02A00093;
    dut.instruction_memory_unit.memory[1] = 32'h00700113;
    dut.instruction_memory_unit.memory[2] = 32'h00208463;
    dut.instruction_memory_unit.memory[3] = 32'h06300193;
    dut.instruction_memory_unit.memory[4] = 32'h00500213;

    // Reset the core and counters.
    #2;
    reset = 1;
    repeat (2) @(negedge clk);
    reset = 0;

    // Execute five instruction slots.
    @(negedge clk);
    enable = 1;

    repeat (5) @(posedge clk);
    #1;
    enable = 0;

    $display(
      "Counters: cycles=%0d instructions=%0d alu=%0d loads=%0d stores=%0d branches=%0d taken=%0d",
      cycles, instructions, alus, loads, stores, branches, taken
    );

    $display(
      "Registers: x1=%0d x2=%0d x3=%0d x4=%0d",
      dut.register_file_unit.registers[1],
      dut.register_file_unit.registers[2],
      dut.register_file_unit.registers[3],
      dut.register_file_unit.registers[4]
    );

    if (cycles !== 32'd5 || instructions !== 32'd5) begin
      $display("FAIL: expected 5 cycles and 5 instructions");
      failures = failures + 1;
    end else begin
      $display("PASS: cycle and instruction counters");
    end

    if (branches !== 32'd1) begin
      $display("FAIL: expected branch count 1, got %0d", branches);
      failures = failures + 1;
    end else begin
      $display("PASS: branch instruction counted");
    end

    if (taken !== 32'd0) begin
      $display("FAIL: expected taken-branch count 0, got %0d", taken);
      failures = failures + 1;
    end else begin
      $display("PASS: not-taken branch does not increment taken counter");
    end

    if (dut.register_file_unit.registers[1] !== 32'd42 ||
        dut.register_file_unit.registers[2] !== 32'd7 ||
        dut.register_file_unit.registers[3] !== 32'd99 ||
        dut.register_file_unit.registers[4] !== 32'd5) begin
      $display("FAIL: register results incorrect");
      failures = failures + 1;
    end else begin
      $display("PASS: fall-through instructions executed correctly");
    end

    if (loads !== 32'd0 || stores !== 32'd0) begin
      $display("FAIL: unexpected load/store counts");
      failures = failures + 1;
    end else begin
      $display("PASS: load/store counters remain zero");
    end

    $display("SUMMARY: failures=%0d", failures);
    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

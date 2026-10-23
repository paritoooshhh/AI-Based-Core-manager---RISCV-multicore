
`timescale 1ns/1ps

module tb_memory_branch_counter;

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
    $display("\n=== MEMORY / BRANCH COUNTER TEST ===");

    // Initialize instruction memory with NOPs.
    for (i = 0; i < 256; i = i + 1)
      dut.instruction_memory_unit.memory[i] = 32'h00000013;

    // Program:
    // 0: ADDI x1,x0,42   -> x1 = 42
    // 1: SW   x1,0(x0)   -> memory[0] = 42
    // 2: LW   x2,0(x0)   -> x2 = 42
    // 3: BEQ  x1,x2,+8   -> taken; skip instruction 4
    // 4: ADDI x3,x0,99   -> must not execute
    // 5: ADDI x3,x0,7    -> x3 = 7
    dut.instruction_memory_unit.memory[0] = 32'h02A00093;
    dut.instruction_memory_unit.memory[1] = 32'h00102023;
    dut.instruction_memory_unit.memory[2] = 32'h00002103;
    dut.instruction_memory_unit.memory[3] = 32'h00208463;
    dut.instruction_memory_unit.memory[4] = 32'h06300193;
    dut.instruction_memory_unit.memory[5] = 32'h00700193;

    // Hold reset across clock edges.
    #2;
    reset = 1;
    repeat (2) @(negedge clk);
    reset = 0;

    // Execute exactly 6 instruction slots.
    @(negedge clk);
    enable = 1;

    repeat (6) @(posedge clk);
    #1;
    enable = 0;

    $display(
      "Observed cycles=%0d instructions=%0d loads=%0d stores=%0d branches=%0d taken=%0d",
      cycles, instructions, loads, stores, branches, taken
    );

    $display(
      "Register values: x1=%0d x2=%0d x3=%0d",
      dut.register_file_unit.registers[1],
      dut.register_file_unit.registers[2],
      dut.register_file_unit.registers[3]
    );

    // Counter checks.
    if (cycles !== 32'd6 || instructions !== 32'd6) begin
      $display("FAIL: expected 6 cycles and 6 instructions");
      failures = failures + 1;
    end else begin
      $display("PASS: cycle and instruction counters");
    end

    if (loads !== 32'd1) begin
      $display("FAIL: expected 1 load, got %0d", loads);
      failures = failures + 1;
    end else begin
      $display("PASS: load counter");
    end

    if (stores !== 32'd1) begin
      $display("FAIL: expected 1 store, got %0d", stores);
      failures = failures + 1;
    end else begin
      $display("PASS: store counter");
    end

    if (branches !== 32'd1 || taken !== 32'd1) begin
      $display(
        "FAIL: expected branches=1 and taken=1, got branches=%0d taken=%0d",
        branches, taken
      );
      failures = failures + 1;
    end else begin
      $display("PASS: taken-branch counters");
    end

    // Functional checks.
    if (dut.register_file_unit.registers[1] !== 32'd42 ||
        dut.register_file_unit.registers[2] !== 32'd42) begin
      $display("FAIL: load/store data path or register results incorrect");
      failures = failures + 1;
    end else begin
      $display("PASS: loaded value matches stored value");
    end

    if (dut.register_file_unit.registers[3] !== 32'd7) begin
      $display("FAIL: branch target result incorrect; x3=%0d",
               dut.register_file_unit.registers[3]);
      failures = failures + 1;
    end else begin
      $display("PASS: taken branch skips x3=99 and reaches x3=7");
    end

    // Verify counters stop when execution is disabled.
    repeat (2) @(posedge clk);
    #1;
    if (cycles !== 32'd6 || instructions !== 32'd6 ||
        loads !== 32'd1 || stores !== 32'd1 ||
        branches !== 32'd1 || taken !== 32'd1) begin
      $display("FAIL: counters changed while execution was disabled");
      failures = failures + 1;
    end else begin
      $display("PASS: counters hold while disabled");
    end

    $display("SUMMARY: failures=%0d", failures);
    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

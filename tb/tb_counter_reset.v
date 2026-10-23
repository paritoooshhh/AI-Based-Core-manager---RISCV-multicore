
`timescale 1ns/1ps

module tb_counter_reset;

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
    $display("\n=== PERFORMANCE COUNTER RESET TEST ===");

    // Initialize instruction memory with NOPs.
    for (i = 0; i < 256; i = i + 1)
      dut.instruction_memory_unit.memory[i] = 32'h00000013;

    // Create nonzero values in multiple counters:
    // 0: ADDI x1,x0,42
    // 1: SW x1,0(x0)
    // 2: LW x2,0(x0)
    // 3: BEQ x1,x2,+8 (taken)
    dut.instruction_memory_unit.memory[0] = 32'h02A00093;
    dut.instruction_memory_unit.memory[1] = 32'h00102023;
    dut.instruction_memory_unit.memory[2] = 32'h00002103;
    dut.instruction_memory_unit.memory[3] = 32'h00208463;

    // Initial reset.
    repeat (2) @(negedge clk);
    reset = 0;

    // Run four instruction slots.
    @(negedge clk);
    enable = 1;
    repeat (4) @(posedge clk);
    #1;
    enable = 0;

    $display(
      "Before reset: cycles=%0d instructions=%0d alu=%0d loads=%0d stores=%0d branches=%0d taken=%0d",
      cycles, instructions, alus, loads, stores, branches, taken
    );

    // Confirm counters actually accumulated before resetting.
    if (cycles == 0 || instructions == 0 ||
        loads == 0 || stores == 0 || branches == 0 || taken == 0) begin
      $display("FAIL: expected counters to be nonzero before reset");
      failures = failures + 1;
    end else begin
      $display("PASS: counters accumulated before reset");
    end

    // Assert reset between clock edges.
    #2;
    reset = 1;
    #1;

    $display(
      "During reset: cycles=%0d instructions=%0d alu=%0d loads=%0d stores=%0d branches=%0d taken=%0d",
      cycles, instructions, alus, loads, stores, branches, taken
    );

    if (cycles !== 32'd0 ||
        instructions !== 32'd0 ||
        alus !== 32'd0 ||
        loads !== 32'd0 ||
        stores !== 32'd0 ||
        branches !== 32'd0 ||
        taken !== 32'd0) begin
      $display("FAIL: one or more counters did not clear on reset");
      failures = failures + 1;
    end else begin
      $display("PASS: all seven counters clear on reset");
    end

    // Keep reset asserted across a clock edge, then disable execution.
    @(negedge clk);
    enable = 0;
    reset = 0;

    // Allow a little time with execution disabled.
    repeat (2) @(posedge clk);
    #1;

    if (cycles !== 32'd0 ||
        instructions !== 32'd0 ||
        alus !== 32'd0 ||
        loads !== 32'd0 ||
        stores !== 32'd0 ||
        branches !== 32'd0 ||
        taken !== 32'd0) begin
      $display("FAIL: counters changed after reset while disabled");
      failures = failures + 1;
    end else begin
      $display("PASS: counters remain zero after reset while disabled");
    end

    $display("SUMMARY: failures=%0d", failures);
    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

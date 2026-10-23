
`timescale 1ns/1ps

module tb_shift_signed_coverage;

  reg clk = 1'b0;
  reg reset = 1'b1;
  reg enable = 1'b0;

  wire [31:0] cycles;
  wire [31:0] instructions;
  wire [31:0] alus;
  wire [31:0] loads;
  wire [31:0] stores;
  wire [31:0] branches;
  wire [31:0] taken;

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
    $display("\n=== SHIFT / SIGNED ARITHMETIC TEST ===");

    // Initialize instruction memory with NOPs.
    for (i = 0; i < 256; i = i + 1)
      dut.instruction_memory_unit.memory[i] = 32'h00000013;

    // x1 = -8
    dut.instruction_memory_unit.memory[0] = 32'hFF800093;

    // x2 = 2
    dut.instruction_memory_unit.memory[1] = 32'h00200113;

    // x3 = x2 << x2 = 2 << 2 = 8 (SLL)
    dut.instruction_memory_unit.memory[2] = 32'h002111B3;

    // x4 = logical right shift of x1 by x2 (SRL)
    // Expected: 0x3FFFFFFE
    dut.instruction_memory_unit.memory[3] = 32'h0020D233;

    // x5 = arithmetic right shift of x1 by x2 (SRA)
    // Expected: 0xFFFFFFFE (-2)
    dut.instruction_memory_unit.memory[4] = 32'h4020D2B3;

    // x6 = x1 + 3 = -5
    dut.instruction_memory_unit.memory[5] = 32'h00308313;

    // x7 = x2 << 3 = 16 (SLLI)
    dut.instruction_memory_unit.memory[6] = 32'h00311393;

    // x8 = logical right shift x1 by 2 (SRLI)
    // Expected: 0x3FFFFFFE
    dut.instruction_memory_unit.memory[7] = 32'h0020D413;

    // x9 = arithmetic right shift x1 by 2 (SRAI)
    // Expected: 0xFFFFFFFE (-2)
    dut.instruction_memory_unit.memory[8] = 32'h4020D493;

    // Hold reset for two falling edges.
    repeat (2) @(negedge clk);
    reset = 1'b0;

    // Enable execution.
    @(negedge clk);
    enable = 1'b1;

    // Execute nine instructions.
    repeat (9) @(posedge clk);
    #1;
    enable = 1'b0;

    $display("\n--- Counter Results ---");
    $display("Cycles=%0d Instructions=%0d ALU=%0d",
             cycles, instructions, alus);

    $display("\n--- Register Results ---");
    for (i = 1; i <= 9; i = i + 1)
      $display("x%0d = 0x%08h", i,
               dut.register_file_unit.registers[i]);

    // Counter checks.
    if (cycles !== 32'd9 ||
        instructions !== 32'd9 ||
        alus !== 32'd9) begin
      $display("FAIL: expected 9 cycles, instructions and ALU operations");
      failures = failures + 1;
    end else begin
      $display("PASS: cycle and ALU counters");
    end

    // Signed immediate.
    if (dut.register_file_unit.registers[1] !== 32'hFFFFFFF8) begin
      $display("FAIL: negative immediate sign extension");
      failures = failures + 1;
    end else begin
      $display("PASS: negative immediate sign extension");
    end

    // SLL.
    if (dut.register_file_unit.registers[3] !== 32'h00000008) begin
      $display("FAIL: SLL");
      failures = failures + 1;
    end else begin
      $display("PASS: SLL");
    end

    // SRL.
    if (dut.register_file_unit.registers[4] !== 32'h3FFFFFFE) begin
      $display("FAIL: SRL");
      failures = failures + 1;
    end else begin
      $display("PASS: SRL zero-fills the left side");
    end

    // SRA.
    if (dut.register_file_unit.registers[5] !== 32'hFFFFFFFE) begin
      $display("FAIL: SRA");
      failures = failures + 1;
    end else begin
      $display("PASS: SRA preserves the sign bit");
    end

    // ADDI with negative result.
    if (dut.register_file_unit.registers[6] !== 32'hFFFFFFFB) begin
      $display("FAIL: negative ADDI arithmetic");
      failures = failures + 1;
    end else begin
      $display("PASS: negative ADDI arithmetic");
    end

    // SLLI.
    if (dut.register_file_unit.registers[7] !== 32'h00000010) begin
      $display("FAIL: SLLI");
      failures = failures + 1;
    end else begin
      $display("PASS: SLLI");
    end

    // SRLI.
    if (dut.register_file_unit.registers[8] !== 32'h3FFFFFFE) begin
      $display("FAIL: SRLI");
      failures = failures + 1;
    end else begin
      $display("PASS: SRLI zero-fills the left side");
    end

    // SRAI.
    if (dut.register_file_unit.registers[9] !== 32'hFFFFFFFE) begin
      $display("FAIL: SRAI");
      failures = failures + 1;
    end else begin
      $display("PASS: SRAI preserves the sign bit");
    end

    $display("\nSUMMARY: failures=%0d", failures);

    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

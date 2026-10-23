
`timescale 1ns/1ps

module tb_edge_cases;

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
    $display("\n=== EDGE CASE / COMPARISON TEST ===");

    // Initialize instruction memory with NOPs.
    for (i = 0; i < 256; i = i + 1)
      dut.instruction_memory_unit.memory[i] = 32'h00000013;

    // x1 = -1
    dut.instruction_memory_unit.memory[0] = 32'hFFF00093;

    // x2 = 1
    dut.instruction_memory_unit.memory[1] = 32'h00100113;

    // x3 = signed SLT: -1 < 1 => 1
    dut.instruction_memory_unit.memory[2] = 32'h0020A1B3;

    // x4 = unsigned SLTU: 0xFFFFFFFF < 1 => 0
    dut.instruction_memory_unit.memory[3] = 32'h0020B233;

    // x5 = signed SLT: 1 < -1 => 0
    dut.instruction_memory_unit.memory[4] = 32'h001122B3;

    // x6 = unsigned SLTU: 1 < 0xFFFFFFFF => 1
    dut.instruction_memory_unit.memory[5] = 32'h00113333;

    // Attempt to write 5 into x0; x0 must remain zero.
    dut.instruction_memory_unit.memory[6] = 32'h00500013;

    // x7 = x0 + 7 => 7
    dut.instruction_memory_unit.memory[7] = 32'h00700393;

    // These are initialization checks only; they are not executed.
    dut.instruction_memory_unit.memory[8] = 32'h7FFFFFFF;
    dut.instruction_memory_unit.memory[9] = 32'h800004B7;

    // Hold reset for two falling edges.
    repeat (2) @(negedge clk);
    reset = 1'b0;

    // Start execution.
    @(negedge clk);
    enable = 1'b1;

    repeat (10) @(posedge clk);
    #1;
    enable = 1'b0;

    $display("\n--- Counter Results ---");
    $display("Cycles=%0d Instructions=%0d ALU=%0d",
             cycles, instructions, alus);

    $display("\n--- Register Results ---");
    for (i = 0; i <= 9; i = i + 1)
      $display("x%0d = 0x%08h", i,
               dut.register_file_unit.registers[i]);

    // Expected: 10 cycles, 10 instruction slots, 8 counted ALU operations.
    if (cycles !== 32'd10 ||
        instructions !== 32'd10 ||
        alus !== 32'd8) begin
      $display("FAIL: expected cycles=10, instructions=10, ALU=8");
      failures = failures + 1;
    end else begin
      $display("PASS: cycle, instruction and ALU counters");
    end

    // Signed comparison: -1 < 1.
    if (dut.register_file_unit.registers[3] !== 32'd1) begin
      $display("FAIL: signed SLT (-1 < 1)");
      failures = failures + 1;
    end else begin
      $display("PASS: signed SLT (-1 < 1)");
    end

    // Unsigned comparison: 0xFFFFFFFF < 1 is false.
    if (dut.register_file_unit.registers[4] !== 32'd0) begin
      $display("FAIL: unsigned SLTU (0xFFFFFFFF < 1)");
      failures = failures + 1;
    end else begin
      $display("PASS: unsigned SLTU (0xFFFFFFFF < 1)");
    end

    // Signed comparison: 1 < -1 is false.
    if (dut.register_file_unit.registers[5] !== 32'd0) begin
      $display("FAIL: signed SLT (1 < -1)");
      failures = failures + 1;
    end else begin
      $display("PASS: signed SLT (1 < -1)");
    end

    // Unsigned comparison: 1 < 0xFFFFFFFF is true.
    if (dut.register_file_unit.registers[6] !== 32'd1) begin
      $display("FAIL: unsigned SLTU (1 < 0xFFFFFFFF)");
      failures = failures + 1;
    end else begin
      $display("PASS: unsigned SLTU (1 < 0xFFFFFFFF)");
    end

    // x0 must remain zero.
    if (dut.register_file_unit.registers[0] !== 32'd0) begin
      $display("FAIL: x0 register protection");
      failures = failures + 1;
    end else begin
      $display("PASS: x0 remains zero");
    end

    // x7 = x0 + 7 must equal 7.
    if (dut.register_file_unit.registers[7] !== 32'd7) begin
      $display("FAIL: x0 source operand");
      failures = failures + 1;
    end else begin
      $display("PASS: x0 reads as zero");
    end

    // Verify boundary instruction words were initialized.
    if (dut.instruction_memory_unit.memory[8] !== 32'h7FFFFFFF ||
        dut.instruction_memory_unit.memory[9] !== 32'h800004B7) begin
      $display("FAIL: boundary instruction initialization");
      failures = failures + 1;
    end else begin
      $display("PASS: boundary instruction words initialized (not executed)");
    end

    $display("\nSUMMARY: failures=%0d", failures);

    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

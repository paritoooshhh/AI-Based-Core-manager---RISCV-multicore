
`timescale 1ns/1ps

// Diagnostics for register-file reset, data-memory initialization,
// and performance-counter behavior.
module tb_state_memory_counter;

  reg clk = 0;
  always #5 clk = ~clk;

  // --------------------------------------------------
  // Register-file signals
  // --------------------------------------------------
  reg rf_reset = 0;
  reg reg_write = 0;
  reg [4:0] rs1 = 1, rs2 = 0, rd = 0;
  reg [31:0] write_data = 0;

  wire [31:0] read_data1, read_data2;

  register_file rf (
    .clk(clk),
    .reset(rf_reset),
    .reg_write(reg_write),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .write_data(write_data),
    .read_data1(read_data1),
    .read_data2(read_data2)
  );

  // --------------------------------------------------
  // Data-memory signals
  // --------------------------------------------------
  reg MemRead = 0, MemWrite = 0;
  reg [31:0] address = 0, mem_write_data = 0;
  wire [31:0] mem_read_data;

  data_memory dm (
    .clk(clk),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .address(address),
    .write_data(mem_write_data),
    .read_data(mem_read_data)
  );

  // --------------------------------------------------
  // Performance-counter signals
  // --------------------------------------------------
  reg counter_reset = 0;
  reg enable = 0;
  reg alu_active = 0, load_active = 0;
  reg store_active = 0, branch_active = 0, branch_taken = 0;

  wire [31:0] cycles, instructions, alus;
  wire [31:0] loads, stores, branches, taken;

  performance_counter pcnt (
    .clk(clk),
    .reset(counter_reset),
    .enable(enable),
    .alu_active(alu_active),
    .load_active(load_active),
    .store_active(store_active),
    .branch_active(branch_active),
    .branch_taken(branch_taken),
    .cycle_count(cycles),
    .instruction_count(instructions),
    .alu_count(alus),
    .load_count(loads),
    .store_count(stores),
    .branch_count(branches),
    .branch_taken_count(taken)
  );

  integer failures = 0;

  initial begin
    $display("\n=== REGISTER / MEMORY / COUNTER DIAGNOSTICS ===");

    // Test asynchronous register-file reset.
    #2;
    rf_reset = 1;
    counter_reset = 1;

    // Allow reset to remain asserted across a clock edge.
    @(negedge clk);
    #1;
    rf_reset = 0;
    counter_reset = 0;
    #1;

    // All registers should be zero after reset.
    if (read_data1 !== 32'd0) begin
      $display("FAIL: x1 should be zero after reset, got %h", read_data1);
      failures = failures + 1;
    end else begin
      $display("PASS: register x1 is zero after reset");
    end

    if (read_data2 !== 32'd0) begin
      $display("FAIL: x0 should read zero, got %h", read_data2);
      failures = failures + 1;
    end else begin
      $display("PASS: x0 always reads zero");
    end

    // Write x1 and verify the synchronous write.
    @(negedge clk);
    reg_write = 1;
    rd = 1;
    write_data = 32'h12345678;

    @(posedge clk);
    #1;
    reg_write = 0;
    rs1 = 1;
    #1;

    if (read_data1 !== 32'h12345678) begin
      $display("FAIL: register write/read got %h", read_data1);
      failures = failures + 1;
    end else begin
      $display("PASS: register write/read");
    end

    // --------------------------------------------------
    // Explicitly initialize a data-memory word.
    // This does NOT add reset support to data_memory.
    // Address 16 corresponds to word index 4 for a
    // word-indexed memory using address[31:2].
    // --------------------------------------------------
    dm.memory[4] = 32'd2468;

    MemRead = 1;
    address = 32'd16;
    #1;

    if (mem_read_data !== 32'd2468) begin
      $display(
        "FAIL: initialized data-memory word expected 2468, got %h",
        mem_read_data
      );
      failures = failures + 1;
    end else begin
      $display("PASS: explicitly initialized data-memory location reads expected value");
    end

    MemRead = 0;

    // --------------------------------------------------
    // Verify performance-counter reset and counting.
    // --------------------------------------------------
    @(negedge clk);
    counter_reset = 1;
    #1;
    counter_reset = 0;

    enable = 1;
    alu_active = 1;
    load_active = 0;
    store_active = 0;
    branch_active = 0;
    branch_taken = 0;

    @(posedge clk);
    #1;

    if (cycles !== 32'd1 ||
        instructions !== 32'd1 ||
        alus !== 32'd1) begin
      $display(
        "FAIL: expected cycle/instruction/ALU counts 1/1/1; got %0d/%0d/%0d",
        cycles, instructions, alus
      );
      failures = failures + 1;
    end else begin
      $display("PASS: enabled event increments cycle/instruction/ALU counters");
    end

    // Counters should hold while disabled.
    @(negedge clk);
    enable = 0;
    alu_active = 0;

    @(posedge clk);
    #1;

    if (cycles !== 32'd1 || instructions !== 32'd1) begin
      $display("FAIL: counters changed while disabled");
      failures = failures + 1;
    end else begin
      $display("PASS: counters hold while disabled");
    end

    $display(
      "NOTE: instruction_count equals cycle_count by construction in this single-cycle design."
    );
    $display("SUMMARY: failures=%0d", failures);

    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

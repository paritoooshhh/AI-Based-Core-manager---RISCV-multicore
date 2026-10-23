
`timescale 1ns/1ps

// Self-checking tests for parallel_workload_controller.
module tb_parallel_controller;

  reg clk = 0;
  reg reset = 1;
  reg start = 0;

  reg [31:0] total_work = 8;
  reg [2:0] required_cores = 3;

  reg d0 = 0, d1 = 0, d2 = 0, d3 = 0;

  wire [31:0] s0, e0, s1, e1, s2, e2, s3, e3;
  wire v0, v1, v2, v3, all_done;

  integer failures = 0;

  always #5 clk = ~clk;

  parallel_workload_controller dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .total_work(total_work),
    .required_cores(required_cores),
    .core0_done(d0),
    .core1_done(d1),
    .core2_done(d2),
    .core3_done(d3),
    .core0_start(s0), .core0_end(e0), .core0_valid(v0),
    .core1_start(s1), .core1_end(e1), .core1_valid(v1),
    .core2_start(s2), .core2_end(e2), .core2_valid(v2),
    .core3_start(s3), .core3_end(e3), .core3_valid(v3),
    .all_done(all_done)
  );

  // Apply inputs away from the rising edge, then sample
  // the registered outputs just after the capturing edge.
  task launch;
    begin
      @(negedge clk);
      start = 1;

      @(posedge clk);
      #1;
      start = 0;

      $display(
        "DEBUG: work=%0d requested=%0d valid=%b%b%b%b",
        total_work, required_cores, v3, v2, v1, v0
      );
      $display(
        "DEBUG: c0=%0d..%0d c1=%0d..%0d c2=%0d..%0d c3=%0d..%0d",
        s0, e0, s1, e1, s2, e2, s3, e3
      );

      $display("INTERNAL: count=%0d base=%0d remainder=%0d",
         dut.count, dut.base_work, dut.remainder);

$display("INTERNAL: next_valid=%b", dut.next_valid);

$display("INTERNAL: next_start=%0d,%0d,%0d,%0d",
         dut.next_start[0], dut.next_start[1],
         dut.next_start[2], dut.next_start[3]);

$display("INTERNAL: next_end=%0d,%0d,%0d,%0d",
         dut.next_end[0], dut.next_end[1],
         dut.next_end[2], dut.next_end[3]);
    end
  endtask

  initial begin
    $display("\n=== PARALLEL WORKLOAD RANGE DIAGNOSTICS ===");

    // Hold reset across clock edges, then release it.
// Hold reset across clock edges, then release it.
repeat (2) @(negedge clk);
reset = 0;

// Force input transitions so the combinational logic
// receives explicit changes before the first test.
required_cores = 0;
total_work = 0;
@(negedge clk);

required_cores = 3;
total_work = 8;

// Test 1: 8 items over 3 workers -> 3, 3, 2.
launch();

    if ({v3, v2, v1, v0} !== 4'b0111) begin
      $display("FAIL: 3-core valid mask=%b", {v3, v2, v1, v0});
      failures = failures + 1;
    end else begin
      $display("PASS: 3-core valid mask");
    end

    if (s0 !== 0 || e0 !== 2 ||
        s1 !== 3 || e1 !== 5 ||
        s2 !== 6 || e2 !== 7) begin
      $display(
        "FAIL: partition mismatch c0=%0d..%0d c1=%0d..%0d c2=%0d..%0d",
        s0, e0, s1, e1, s2, e2
      );
      failures = failures + 1;
    end else begin
      $display("PASS: 8 items partitioned across 3 workers");
    end

    // Test 2: requests above 4 clamp to four workers.
    required_cores = 5;
    total_work = 8;
    launch();

    if ({v3, v2, v1, v0} !== 4'b1111) begin
      $display("FAIL: request 5 mask=%b", {v3, v2, v1, v0});
      failures = failures + 1;
    end else begin
      $display("PASS: request above 4 clamps to four slots");
    end

    if (s0 !== 0 || e0 !== 1 ||
        s1 !== 2 || e1 !== 3 ||
        s2 !== 4 || e2 !== 5 ||
        s3 !== 6 || e3 !== 7) begin
      $display("FAIL: 4-slot partition mismatch");
      failures = failures + 1;
    end else begin
      $display("PASS: 8 items partitioned across 4 slots");
    end

    // Test 3: zero work should activate no workers.
    total_work = 0;
    required_cores = 2;
    launch();

    if ({v3, v2, v1, v0} !== 4'b0000) begin
      $display("FAIL: zero-work mask=%b", {v3, v2, v1, v0});
      failures = failures + 1;
    end else begin
      $display("PASS: zero work has no valid ranges");
    end

    $display("----------------------------------------");
    $display("SUMMARY: failures=%0d", failures);

    if (failures == 0)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");

    $finish;
  end

endmodule

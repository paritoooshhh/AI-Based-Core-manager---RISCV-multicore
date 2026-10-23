
`timescale 1ns/1ps

// Clock-gating regression testbench.
// Checks enabled edges, disabled stability, and re-enabling.
module tb_clock_gating;

  reg clk = 0;
  reg reset = 1;
  reg enable = 0;

  wire gated_clk;

  integer gated_rises = 0;
  integer before_count;
  integer disabled_rises;
  integer i;
  integer failures = 0;

  clock_gating dut (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .gated_clk(gated_clk)
  );

  always #5 clk = ~clk;

  always @(posedge gated_clk)
    gated_rises = gated_rises + 1;

  initial begin
    $display("\n=== CLOCK GATING DIAGNOSTICS ===");

    // Assert reset and allow it to be sampled.
    #2;
    reset = 1;
    #10;
    reset = 0;

    // -----------------------------------------------
    // 1. Enable the gated clock.
    // -----------------------------------------------
    @(posedge clk);
    #1;
    enable = 1;

    repeat (4) @(posedge clk);
    #1;

    before_count = gated_rises;

    if (before_count < 3) begin
      $display(
        "FAIL: enabled clock produced too few edges (%0d)",
        before_count
      );
      failures = failures + 1;
    end else begin
      $display(
        "PASS: enabled clock produces edges (%0d observed)",
        before_count
      );
    end

    // -----------------------------------------------
    // 2. Disable and wait for the falling-edge latch
    //    to capture enable=0.
    // -----------------------------------------------
    @(posedge clk);
    #1;
    enable = 0;

    @(negedge clk);
    #1;

    // Record the count after the gate is fully disabled.
    before_count = gated_rises;
    disabled_rises = 0;

    // Observe five complete source-clock cycles.
    // Count any unexpected gated rising edges.
    for (i = 0; i < 5; i = i + 1) begin
      @(posedge clk);
      #1;

      if (gated_clk === 1'b1)
        disabled_rises = disabled_rises + 1;
    end

    if (disabled_rises != 0) begin
      $display(
        "FAIL: gated clock was high on %0d disabled observations",
        disabled_rises
      );
      failures = failures + 1;
    end else if (gated_rises != before_count) begin
      $display(
        "FAIL: gated rising-edge count changed while disabled (%0d -> %0d)",
        before_count, gated_rises
      );
      failures = failures + 1;
    end else begin
      $display("PASS: gated clock remains stopped while disabled");
    end

    // -----------------------------------------------
    // 3. Re-enable the clock.
    // -----------------------------------------------
    @(negedge clk);
    #1;
    enable = 1;

    repeat (3) @(posedge clk);
    #1;

    if (gated_rises <= before_count) begin
      $display("FAIL: gated clock did not resume");
      failures = failures + 1;
    end else begin
      $display("PASS: gated clock resumes when re-enabled");
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

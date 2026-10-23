`timescale 1ns/1ps

module tb_result_combiner;
    reg [31:0] r0, r1, r2, r3;
    reg [3:0] valid_mask;
    reg workload_done;
    wire [31:0] final_result;
    wire result_valid;
    integer failures = 0;

    result_combiner dut (
        .core0_result(r0), .core1_result(r1),
        .core2_result(r2), .core3_result(r3),
        .valid_mask(valid_mask), .workload_done(workload_done),
        .final_result(final_result), .result_valid(result_valid)
    );

    task check;
        input [31:0] expected_result;
        input expected_valid;
        input [255:0] test_name;
        begin
            #1;
            if (final_result !== expected_result || result_valid !== expected_valid) begin
                $display("FAIL: %0s got result=%0d valid=%b expected result=%0d valid=%b",
                         test_name, final_result, result_valid, expected_result, expected_valid);
                failures = failures + 1;
            end else begin
                $display("PASS: %0s result=%0d valid=%b",
                         test_name, final_result, result_valid);
            end
        end
    endtask

    initial begin
        $display("=== HARDWARE RESULT COMBINER TEST ===");
        r0 = 1; r1 = 5; r2 = 9; r3 = 13;
        valid_mask = 4'b1111;
        workload_done = 1'b0;
        check(32'd28, 1'b0, "four active cores, not done yet");

        workload_done = 1'b1;
        check(32'd28, 1'b1, "four active cores completed");

        valid_mask = 4'b0111;
        workload_done = 1'b1;
        check(32'd15, 1'b1, "three active cores ignore core 3");

        valid_mask = 4'b0001;
        check(32'd1, 1'b1, "one active core");

        valid_mask = 4'b0000;
        check(32'd0, 1'b1, "zero active cores");

        // A participating core may legitimately return zero.
        r0 = 0; valid_mask = 4'b0001;
        check(32'd0, 1'b1, "valid zero result");

        if (failures == 0) begin
            $display("SUMMARY: failures=0");
            $display("RESULT: PASS");
        end else begin
            $display("SUMMARY: failures=%0d", failures);
            $display("RESULT: FAIL");
        end
        $finish;
    end
endmodule

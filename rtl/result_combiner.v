`timescale 1ns/1ps

// Combinational sum of partial results from participating CPU workers.
// The caller should assert workload_done only after all valid workers finish.
module result_combiner (
    input  [31:0] core0_result,
    input  [31:0] core1_result,
    input  [31:0] core2_result,
    input  [31:0] core3_result,
    input  [3:0]  valid_mask,
    input         workload_done,
    output reg [31:0] final_result,
    output        result_valid
);
    always @* begin
        final_result = 32'd0;
        if (valid_mask[0]) final_result = final_result + core0_result;
        if (valid_mask[1]) final_result = final_result + core1_result;
        if (valid_mask[2]) final_result = final_result + core2_result;
        if (valid_mask[3]) final_result = final_result + core3_result;
    end

    assign result_valid = workload_done;
endmodule


`timescale 1ns/1ps

module tb_core_manager;
    reg [2:0] required_cores = 0;
    wire core0_enable, core1_enable, core2_enable, core3_enable;

    core_manager dut (
        .required_cores(required_cores),
        .core0_enable(core0_enable),
        .core1_enable(core1_enable),
        .core2_enable(core2_enable),
        .core3_enable(core3_enable)
    );

    initial begin
        $display("=== CORE MANAGER TEST ===");

        #1;
        required_cores = 0; #1;
        $display("requested=0 enables=%b%b%b%b",
                 core3_enable, core2_enable, core1_enable, core0_enable);

        required_cores = 1; #1;
        $display("requested=1 enables=%b%b%b%b",
                 core3_enable, core2_enable, core1_enable, core0_enable);

        required_cores = 2; #1;
        $display("requested=2 enables=%b%b%b%b",
                 core3_enable, core2_enable, core1_enable, core0_enable);

        required_cores = 3; #1;
        $display("requested=3 enables=%b%b%b%b",
                 core3_enable, core2_enable, core1_enable, core0_enable);

        required_cores = 4; #1;
        $display("requested=4 enables=%b%b%b%b",
                 core3_enable, core2_enable, core1_enable, core0_enable);

        required_cores = 7; #1;
        $display("requested=7 enables=%b%b%b%b",
                 core3_enable, core2_enable, core1_enable, core0_enable);

        $finish;
    end
endmodule

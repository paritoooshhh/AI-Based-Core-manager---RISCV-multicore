`timescale 1ns/1ps
module alu_control_regression_tb;
    reg [1:0] ALUOp;
    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7;
    wire [3:0] alu_control;

    alu_control dut(
        .ALUOp(ALUOp),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_control(alu_control)
    );

    initial begin
        // ADDI x1,x0,1024 has immediate[11:5] == 7'b0100000.
        // It must decode as ADD, not SUB.
        ALUOp = 2'b10;
        opcode = 7'b0010011;
        funct3 = 3'b000;
        funct7 = 7'b0100000;
        #1;
        if (alu_control !== 4'b0000) begin
            $display("FAIL: ADDI imm=1024 decoded as ALU control %b", alu_control);
            $finish;
        end

        // R-type SUB must still decode as SUB.
        opcode = 7'b0110011;
        funct7 = 7'b0100000;
        #1;
        if (alu_control !== 4'b0001) begin
            $display("FAIL: SUB decoded as ALU control %b", alu_control);
            $finish;
        end

        $display("PASS: ADDI immediate 1024 decodes as ADD; R-type SUB decodes as SUB.");
        $finish;
    end
endmodule

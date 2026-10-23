`timescale 1ns/1ps

// Standalone directed checks for the supplied control_unit, alu_control, and alu.
// This testbench does not modify or depend on the CPU worker RTL.
module tb_control_alu_verify;
    reg [31:0] operand_a, operand_b;
    reg [3:0] alu_control_direct;
    wire [31:0] alu_result;

    reg [1:0] ALUOp;
    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7;
    wire [3:0] decoded_alu_control;

    wire RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch;
    wire [1:0] control_ALUOp;
    wire [2:0] imm_type;

    integer pass_count = 0;
    integer fail_count = 0;

    alu dut_alu (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .alu_control(alu_control_direct),
        .result(alu_result)
    );

    alu_control dut_alu_control (
        .ALUOp(ALUOp),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_control(decoded_alu_control)
    );

    control_unit dut_control_unit (
        .opcode(opcode),
        .funct3(funct3),
        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),
        .Branch(Branch),
        .ALUOp(control_ALUOp),
        .imm_type(imm_type)
    );

    task check_alu;
        input [255:0] label;
        input [31:0] a;
        input [31:0] b;
        input [3:0] op;
        input [31:0] expected;
        begin
            operand_a = a;
            operand_b = b;
            alu_control_direct = op;
            #1;
            if (alu_result === expected) begin
                pass_count = pass_count + 1;
                $display("PASS,ALU,%0s,result=%08h", label, alu_result);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL,ALU,%0s,a=%08h,b=%08h,op=%b,expected=%08h,actual=%08h",
                         label, a, b, op, expected, alu_result);
            end
        end
    endtask

    task check_decode;
        input [255:0] label;
        input [1:0] aluop_in;
        input [6:0] opcode_in;
        input [2:0] funct3_in;
        input [6:0] funct7_in;
        input [3:0] expected;
        begin
            ALUOp = aluop_in;
            opcode = opcode_in;
            funct3 = funct3_in;
            funct7 = funct7_in;
            #1;
            if (decoded_alu_control === expected) begin
                pass_count = pass_count + 1;
                $display("PASS,DECODE,%0s,control=%b", label, decoded_alu_control);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL,DECODE,%0s,expected=%b,actual=%b",
                         label, expected, decoded_alu_control);
            end
        end
    endtask

    task check_control;
        input [255:0] label;
        input [6:0] opcode_in;
        input [2:0] funct3_in;
        input exp_RegWrite, exp_ALUSrc, exp_MemRead, exp_MemWrite;
        input exp_MemToReg, exp_Branch;
        input [1:0] exp_ALUOp;
        input [2:0] exp_imm_type;
        begin
            opcode = opcode_in;
            funct3 = funct3_in;
            #1;
            if ({RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch,
                 control_ALUOp, imm_type} ===
                {exp_RegWrite, exp_ALUSrc, exp_MemRead, exp_MemWrite,
                 exp_MemToReg, exp_Branch, exp_ALUOp, exp_imm_type}) begin
                pass_count = pass_count + 1;
                $display("PASS,CONTROL,%0s", label);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL,CONTROL,%0s,got=%b%b%b%b%b%b_%b_%b,expected=%b%b%b%b%b%b_%b_%b",
                    label, RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch,
                    control_ALUOp, imm_type,
                    exp_RegWrite, exp_ALUSrc, exp_MemRead, exp_MemWrite,
                    exp_MemToReg, exp_Branch, exp_ALUOp, exp_imm_type);
            end
        end
    endtask

    initial begin
        $display("CONTROL_ALU_VERIFY_BEGIN");
        $display("CSV_HEADER,category,test,status");

        // Direct ALU arithmetic/logical/shift/comparison checks.
        check_alu("ADD", 32'd7, 32'd5, 4'b0000, 32'd12);
        check_alu("SUB", 32'd7, 32'd5, 4'b0001, 32'd2);
        check_alu("AND", 32'hA5, 32'h3C, 4'b0010, 32'h24);
        check_alu("OR",  32'hA5, 32'h3C, 4'b0011, 32'hBD);
        check_alu("XOR", 32'hA5, 32'h3C, 4'b0100, 32'h99);
        check_alu("SLL", 32'd3, 32'd2, 4'b0101, 32'd12);
        check_alu("SRL", 32'd16, 32'd2, 4'b0110, 32'd4);
        check_alu("SRA_negative", 32'hFFFFFFF0, 32'd2, 4'b0111, 32'hFFFFFFFC);
        check_alu("SLT_signed_true", 32'hFFFFFFFF, 32'd1, 4'b1000, 32'd1);
        check_alu("SLTU_unsigned_false", 32'hFFFFFFFF, 32'd1, 4'b1001, 32'd0);

        // ALU control decoder checks: R-type and I-type decode cases.
        check_decode("R_ADD", 2'b10, 7'b0110011, 3'b000, 7'b0000000, 4'b0000);
        check_decode("R_SUB", 2'b10, 7'b0110011, 3'b000, 7'b0100000, 4'b0001);
        check_decode("R_SLL", 2'b10, 7'b0110011, 3'b001, 7'b0000000, 4'b0101);
        check_decode("R_SLT", 2'b10, 7'b0110011, 3'b010, 7'b0000000, 4'b1000);
        check_decode("R_SLTU",2'b10, 7'b0110011, 3'b011, 7'b0000000, 4'b1001);
        check_decode("R_XOR", 2'b10, 7'b0110011, 3'b100, 7'b0000000, 4'b0100);
        check_decode("R_SRL", 2'b10, 7'b0110011, 3'b101, 7'b0000000, 4'b0110);
        check_decode("R_SRA", 2'b10, 7'b0110011, 3'b101, 7'b0100000, 4'b0111);
        check_decode("R_OR",  2'b10, 7'b0110011, 3'b110, 7'b0000000, 4'b0011);
        check_decode("R_AND", 2'b10, 7'b0110011, 3'b111, 7'b0000000, 4'b0010);
        check_decode("I_ADDI_not_misread_as_SUB", 2'b10, 7'b0010011, 3'b000, 7'b0100000, 4'b0000);
        check_decode("LW_address_ADD", 2'b00, 7'b0000011, 3'b010, 7'b0000000, 4'b0000);
        check_decode("Branch_SUB_control", 2'b01, 7'b1100011, 3'b000, 7'b0000000, 4'b0001);

        // Main control unit output checks.
        check_control("R_type", 7'b0110011, 3'b000,
                      1,0,0,0,0,0,2'b10,3'b000);
        check_control("I_type", 7'b0010011, 3'b000,
                      1,1,0,0,0,0,2'b10,3'b000);
        check_control("LW", 7'b0000011, 3'b010,
                      1,1,1,0,1,0,2'b00,3'b000);
        check_control("SW", 7'b0100011, 3'b010,
                      0,1,0,1,0,0,2'b00,3'b001);
        check_control("BEQ", 7'b1100011, 3'b000,
                      0,0,0,0,0,1,2'b01,3'b010);
        check_control("BNE", 7'b1100011, 3'b001,
                      0,0,0,0,0,1,2'b01,3'b010);
        check_control("BLT", 7'b1100011, 3'b100,
                      0,0,0,0,0,1,2'b01,3'b010);
        check_control("BGE", 7'b1100011, 3'b101,
                      0,0,0,0,0,1,2'b01,3'b010);
        check_control("BLTU",7'b1100011, 3'b110,
                      0,0,0,0,0,1,2'b01,3'b010);
        check_control("BGEU",7'b1100011, 3'b111,
                      0,0,0,0,0,1,2'b01,3'b010);
        check_control("reserved_branch_funct3", 7'b1100011, 3'b010,
                      0,0,0,0,0,0,2'b00,3'b000);
        check_control("unsupported_opcode", 7'b1111111, 3'b000,
                      0,0,0,0,0,0,2'b00,3'b000);

        $display("CONTROL_ALU_SUMMARY,pass=%0d,fail=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("CONTROL_ALU_RESULT,PASS");
        else
            $display("CONTROL_ALU_RESULT,FAIL");
        $finish;
    end
endmodule

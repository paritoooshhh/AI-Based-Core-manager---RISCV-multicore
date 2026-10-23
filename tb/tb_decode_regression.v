`timescale 1ns/1ps
// Diagnostic regression tests for alu_control, control_unit, and core_manager.
// Known unsupported instructions are reported as FINDINGs, not hidden.
module tb_decode_regression;
  reg [1:0] ALUOp;
  reg [6:0] opcode;
  reg [2:0] funct3;
  reg [6:0] funct7;
  wire [3:0] alu_control_signal;

  reg [6:0] cu_opcode;
  reg [2:0] cu_funct3;
  wire RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch;
  wire [1:0] cu_ALUOp;
  wire [2:0] imm_type;

  reg [2:0] required_cores;
  wire e0,e1,e2,e3;

  integer failures = 0;
  integer findings = 0;

  alu_control dut_alu_control(
    .ALUOp(ALUOp), .opcode(opcode), .funct3(funct3), .funct7(funct7),
    .alu_control(alu_control_signal)
  );

  control_unit dut_control_unit(
    .opcode(cu_opcode), .funct3(cu_funct3),
    .RegWrite(RegWrite), .ALUSrc(ALUSrc), .MemRead(MemRead),
    .MemWrite(MemWrite), .MemToReg(MemToReg), .Branch(Branch),
    .ALUOp(cu_ALUOp), .imm_type(imm_type)
  );

  core_manager dut_core_manager(
    .required_cores(required_cores),
    .core0_enable(e0), .core1_enable(e1),
    .core2_enable(e2), .core3_enable(e3)
  );

  task check_alu(input [3:0] expected, input [255:0] label_text);
    begin
      #1;
      if (alu_control_signal !== expected) begin
        $display("FAIL: %0s expected=%b got=%b", label_text, expected, alu_control_signal);
        failures = failures + 1;
      end else $display("PASS: %0s", label_text);
    end
  endtask

  task check_branch(input [2:0] f3, input expected, input [255:0] label_text);
    begin
      cu_opcode = 7'b1100011; cu_funct3 = f3; #1;
      if (Branch !== expected) begin
        $display("FAIL: %0s expected Branch=%b got=%b", label_text, expected, Branch);
        failures = failures + 1;
      end else $display("PASS: %0s", label_text);
    end
  endtask

  task check_disabled(input [6:0] op, input [255:0] label_text);
    begin
      cu_opcode = op; cu_funct3 = 3'b000; #1;
      if ({RegWrite,ALUSrc,MemRead,MemWrite,MemToReg,Branch} !== 6'b0) begin
        $display("INFO: %0s has nonzero controls (check support intentionally)", label_text);
      end else begin
        $display("FINDING: %0s is not implemented by current control_unit", label_text);
        findings = findings + 1;
      end
    end
  endtask

  initial begin
    $display("\n=== DECODE / CORE MANAGER DIAGNOSTICS ===");
    ALUOp=2'b10; opcode=7'b0010011; funct3=3'b000; funct7=7'b0100000;
    check_alu(4'b0000, "ADDI immediate bit pattern 0100000 must decode ADD");
    ALUOp=2'b10; opcode=7'b0110011; funct3=3'b000; funct7=7'b0100000;
    check_alu(4'b0001, "R-type SUB must decode SUB");

    check_branch(3'b000,1'b1,"BEQ branch decode");
    check_branch(3'b001,1'b1,"BNE branch decode");
    check_branch(3'b100,1'b1,"BLT branch decode");
    check_branch(3'b101,1'b1,"BGE branch decode");
    check_branch(3'b110,1'b1,"BLTU branch decode");
    check_branch(3'b111,1'b1,"BGEU branch decode");
    check_branch(3'b010,1'b0,"reserved branch funct3 must not assert Branch");
    check_branch(3'b011,1'b0,"reserved branch funct3 must not assert Branch");

    check_disabled(7'b1101111,"JAL");
    check_disabled(7'b1100111,"JALR");
    check_disabled(7'b0110111,"LUI");
    check_disabled(7'b0010111,"AUIPC");

    required_cores=0; #1;
    if ({e3,e2,e1,e0} !== 4'b0000) begin $display("FAIL: request 0 mask=%b",{e3,e2,e1,e0}); failures=failures+1; end
    else $display("PASS: request 0 disables all cores");
    required_cores=1; #1;
    if ({e3,e2,e1,e0} !== 4'b0001) begin $display("FAIL: request 1 mask=%b",{e3,e2,e1,e0}); failures=failures+1; end
    else $display("PASS: request 1 mask");
    required_cores=4; #1;
    if ({e3,e2,e1,e0} !== 4'b1111) begin $display("FAIL: request 4 mask=%b",{e3,e2,e1,e0}); failures=failures+1; end
    else $display("PASS: request 4 mask");
    required_cores=5; #1;
    if ({e3,e2,e1,e0} !== 4'b0000) begin $display("FAIL: invalid request 5 mask=%b",{e3,e2,e1,e0}); failures=failures+1; end
    else $display("PASS: invalid request 5 fails safe");
    required_cores=3'bxxx; #1;
    if ({e3,e2,e1,e0} !== 4'b0000) begin $display("FAIL: X request mask=%b",{e3,e2,e1,e0}); failures=failures+1; end
    else $display("PASS: X request fails safe");

    $display("\nSUMMARY: failures=%0d known_unsupported_instruction_findings=%0d", failures, findings);
    if (failures != 0) $display("RESULT: FAIL - fix failing checks before proceeding");
    else $display("RESULT: PASS for implemented checks; FINDINGs above identify unsupported ISA instructions");
    $finish;
  end
endmodule

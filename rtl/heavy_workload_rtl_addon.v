// Experimental heavy-workload CPU path.
// Compile alongside 14_Multicore-Zeta_corrected.v.
// Existing project modules and testbenches are not modified.
//
// workload_type:
//   0 = arithmetic/logical
//   1 = branch-heavy
//   2 = memory-heavy (word addresses 0..255)
//   3 = mixed
//
// The worker returns the sum of its assigned indices for every workload type,
// allowing the testbench to check an independent triangular-number golden result.
module riscv_partition_core_heavy(
    input clk,
    input reset,
    input enable,
    input [31:0] work_start,
    input [31:0] work_end,
    input work_valid,
    input workload_start,
    input [1:0] workload_type,
    output work_done,
    output [31:0] work_result,
    output [31:0] cycle_count,
    output [31:0] instruction_count,
    output [31:0] alu_count,
    output [31:0] load_count,
    output [31:0] store_count,
    output [31:0] branch_count,
    output [31:0] branch_taken_count
);
    wire [31:0] pc_value, next_pc;
    reg [31:0] instruction;
    wire core_reset = reset | workload_start;
    wire RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch;
    wire [1:0] ALUOp;
    wire [2:0] imm_type;
    wire [31:0] read_data1, read_data2, immediate;
    wire [31:0] alu_operand_b, alu_result, memory_data, write_back_data;
    wire [3:0] alu_control_signal;
    wire branch_taken;
    wire alu_active = (instruction[6:0] == 7'b0110011) ||
                      ((instruction[6:0] == 7'b0010011) &&
                       (instruction != 32'h00000013));
    wire load_active = MemRead;
    wire store_active = MemWrite;
    wire branch_active = Branch;
    wire core_clk;

    // Instruction encoders keep immediate fields correctly positioned.
    function [31:0] enc_addi;
        input [4:0] rd, rs1;
        input integer imm;
        reg [11:0] im;
        begin
            im = imm[11:0];
            enc_addi = {im, rs1, 3'b000, rd, 7'b0010011};
        end
    endfunction

    function [31:0] enc_r;
        input [6:0] funct7;
        input [4:0] rs2, rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
        end
    endfunction

    function [31:0] enc_b;
        input integer offset;
        input [4:0] rs2, rs1;
        input [2:0] funct3;
        reg [12:0] im;
        begin
            im = offset;
            enc_b = {im[12], im[10:5], rs2, rs1, funct3,
                     im[4:1], im[11], 7'b1100011};
        end
    endfunction

    function [31:0] enc_sw;
        input [4:0] rs2, rs1;
        input integer offset;
        reg [11:0] im;
        begin
            im = offset;
            enc_sw = {im[11:5], rs2, rs1, 3'b010, im[4:0], 7'b0100011};
        end
    endfunction

    function [31:0] enc_lw;
        input [4:0] rd, rs1;
        input integer offset;
        reg [11:0] im;
        begin
            im = offset;
            enc_lw = {im, rs1, 3'b010, rd, 7'b0000011};
        end
    endfunction

    function [31:0] enc_slli;
        input [4:0] rd, rs1;
        input [4:0] shamt;
        begin
            enc_slli = {7'b0000000, shamt, rs1, 3'b001, rd, 7'b0010011};
        end
    endfunction

    clock_gating heavy_clock_gate(
        .clk(clk), .reset(core_reset), .enable(enable), .gated_clk(core_clk)
    );

    assign work_done = work_valid && (pc_value == 32'd52);

    pc heavy_pc(
        .clk(core_clk), .reset(core_reset), .next_pc(next_pc), .pc(pc_value)
    );

    // Program:
    // 0  x10=start; 4 x11=end; 8 x12=0; 12 x13=0
    // 16..36 workload body; 40 compare; 44 increment; 48 loop; 52 park.
    always @* begin
        instruction = 32'h00000013; // NOP by default
        case (pc_value)
            32'd0:  instruction = enc_addi(5'd10, 5'd0, work_start);
            32'd4:  instruction = enc_addi(5'd11, 5'd0, work_end);
            32'd8:  instruction = enc_addi(5'd12, 5'd0, 0);
            32'd12: instruction = enc_addi(5'd13, 5'd0, 0);

            32'd16: begin
                case (workload_type)
                    2'd0: instruction = enc_r(7'b0000000, 5'd10, 5'd12, 3'b000, 5'd12); // ADD x12,x12,x10
                    2'd1: instruction = enc_b(4, 5'd0, 5'd0, 3'b000); // BEQ x0,x0,+4
                    2'd2: instruction = enc_slli(5'd14, 5'd10, 5'd2); // x14=x10*4
                    2'd3: instruction = enc_slli(5'd14, 5'd10, 5'd2);
                endcase
            end
            32'd20: begin
                case (workload_type)
                    2'd0: instruction = enc_r(7'b0000000, 5'd10, 5'd13, 3'b100, 5'd13); // XOR x13,x13,x10
                    2'd1: instruction = enc_b(4, 5'd0, 5'd10, 3'b001); // BNE x10,x0,+4
                    2'd2: instruction = enc_sw(5'd10, 5'd14, 0); // SW x10,0(x14)
                    2'd3: instruction = enc_sw(5'd10, 5'd14, 0);
                endcase
            end
            32'd24: begin
                case (workload_type)
                    2'd0: instruction = enc_slli(5'd14, 5'd10, 5'd1);
                    2'd1: instruction = enc_b(4, 5'd0, 5'd0, 3'b000);
                    2'd2: instruction = enc_lw(5'd15, 5'd14, 0); // LW x15,0(x14)
                    2'd3: instruction = enc_lw(5'd15, 5'd14, 0);
                endcase
            end
            32'd28: begin
                case (workload_type)
                    2'd0: instruction = enc_r(7'b0000000, 5'd14, 5'd13, 3'b000, 5'd13); // ADD x13,x13,x14
                    2'd1: instruction = enc_b(4, 5'd0, 5'd10, 3'b001);
                    2'd2: instruction = enc_r(7'b0000000, 5'd15, 5'd12, 3'b000, 5'd12); // sum loaded index
                    2'd3: instruction = enc_r(7'b0000000, 5'd15, 5'd13, 3'b100, 5'd13);
                endcase
            end
            32'd32: begin
                case (workload_type)
                    2'd0: instruction = 32'h00000013;
                    2'd1: instruction = enc_r(7'b0000000, 5'd10, 5'd12, 3'b000, 5'd12); // sum index
                    2'd2: instruction = 32'h00000013;
                    2'd3: instruction = enc_r(7'b0000000, 5'd15, 5'd12, 3'b000, 5'd12); // sum loaded index
                endcase
            end
            32'd36: begin
                case (workload_type)
                    2'd0: instruction = 32'h00000013;
                    2'd1: instruction = enc_b(4, 5'd0, 5'd0, 3'b000);
                    2'd2: instruction = 32'h00000013;
                    2'd3: instruction = enc_b(4, 5'd0, 5'd0, 3'b000);
                endcase
            end
            32'd40: instruction = enc_b(12, 5'd11, 5'd10, 3'b000); // if i==end finish
            32'd44: instruction = enc_addi(5'd10, 5'd10, 1);
            32'd48: instruction = enc_b(-32, 5'd0, 5'd0, 3'b000); // loop to PC 16
            32'd52: instruction = enc_b(0, 5'd0, 5'd0, 3'b000); // park
            default: instruction = 32'h00000013;
        endcase
    end

    control_unit heavy_control(
        .opcode(instruction[6:0]), .funct3(instruction[14:12]),
        .RegWrite(RegWrite), .ALUSrc(ALUSrc), .MemRead(MemRead),
        .MemWrite(MemWrite), .MemToReg(MemToReg), .Branch(Branch),
        .ALUOp(ALUOp), .imm_type(imm_type)
    );

    register_file heavy_registers(
        .clk(core_clk), .reset(core_reset), .reg_write(RegWrite),
        .rs1(instruction[19:15]), .rs2(instruction[24:20]),
        .rd(instruction[11:7]), .write_data(write_back_data),
        .read_data1(read_data1), .read_data2(read_data2), .debug_x12(work_result)
    );

    immediate_generator heavy_immediate(
        .instruction(instruction), .imm_type(imm_type), .immediate(immediate)
    );

    alu_control heavy_alu_decode(
        .ALUOp(ALUOp), .opcode(instruction[6:0]),
        .funct3(instruction[14:12]), .funct7(instruction[31:25]),
        .alu_control(alu_control_signal)
    );

    assign alu_operand_b = ALUSrc ? immediate : read_data2;
    alu heavy_alu(
        .operand_a(read_data1), .operand_b(alu_operand_b),
        .alu_control(alu_control_signal), .result(alu_result)
    );

    data_memory heavy_data_memory(
        .clk(core_clk), .MemRead(MemRead), .MemWrite(MemWrite),
        .address(alu_result), .write_data(read_data2), .read_data(memory_data)
    );

    performance_counter heavy_counters(
        .clk(core_clk), .reset(core_reset), .enable(enable),
        .alu_active(alu_active), .load_active(load_active), .store_active(store_active),
        .branch_active(branch_active), .branch_taken(branch_taken),
        .cycle_count(cycle_count), .instruction_count(instruction_count),
        .alu_count(alu_count), .load_count(load_count), .store_count(store_count),
        .branch_count(branch_count), .branch_taken_count(branch_taken_count)
    );

    assign write_back_data = MemToReg ? memory_data : alu_result;

    reg branch_condition;
    always @* begin
        case (instruction[14:12])
            3'b000: branch_condition = (read_data1 == read_data2);
            3'b001: branch_condition = (read_data1 != read_data2);
            3'b100: branch_condition = ($signed(read_data1) < $signed(read_data2));
            3'b101: branch_condition = ($signed(read_data1) >= $signed(read_data2));
            3'b110: branch_condition = (read_data1 < read_data2);
            3'b111: branch_condition = (read_data1 >= read_data2);
            default: branch_condition = 1'b0;
        endcase
    end

    assign branch_taken = Branch && branch_condition;
    assign next_pc = branch_taken ? (pc_value + immediate) : (pc_value + 32'd4);
endmodule


module multicore_cpu_heavy_workload_system(
    input clk,
    input reset,
    input [2:0] required_cores,
    input workload_start,
    input [31:0] workload_size,
    input [1:0] workload_type,
    output [3:0] core_enable,
    output workload_done,
    output [31:0] core0_result, core1_result, core2_result, core3_result,
    output [31:0] core0_cycles, core1_cycles, core2_cycles, core3_cycles,
    output [31:0] core0_alu, core1_alu, core2_alu, core3_alu
);
    // Up to 256 items: indices 0..255 fit both the worker's 12-bit immediates
    // and the 256-word data memory used by memory/mixed workloads.
    wire [2:0] bounded_cores = (required_cores > 3'd4) ? 3'd4 : required_cores;
    wire [31:0] bounded_work = (workload_size > 32'd256) ? 32'd256 : workload_size;

    wire m0, m1, m2, m3;
    wire [31:0] s0, e0, s1, e1, s2, e2, s3, e3;
    wire v0, v1, v2, v3;
    wire d0, d1, d2, d3;
    wire [3:0] run_enable;
    wire [31:0] ic0, ic1, ic2, ic3;
    wire [31:0] ld0, ld1, ld2, ld3;
    wire [31:0] st0, st1, st2, st3;
    wire [31:0] br0, br1, br2, br3;
    wire [31:0] bt0, bt1, bt2, bt3;

    core_manager manager(
        .required_cores(bounded_cores),
        .core0_enable(m0), .core1_enable(m1), .core2_enable(m2), .core3_enable(m3)
    );

    parallel_workload_controller partitioner(
        .clk(clk), .reset(reset), .start(workload_start),
        .total_work(bounded_work), .required_cores(bounded_cores),
        .core0_done(d0), .core1_done(d1), .core2_done(d2), .core3_done(d3),
        .core0_start(s0), .core0_end(e0), .core0_valid(v0),
        .core1_start(s1), .core1_end(e1), .core1_valid(v1),
        .core2_start(s2), .core2_end(e2), .core2_valid(v2),
        .core3_start(s3), .core3_end(e3), .core3_valid(v3),
        .all_done(workload_done)
    );

    assign run_enable = {m3 & v3, m2 & v2, m1 & v1, m0 & v0};
    assign core_enable = run_enable;

    riscv_partition_core_heavy core0(
        .clk(clk), .reset(reset), .enable(run_enable[0]),
        .work_start(s0), .work_end(e0), .work_valid(v0), .workload_start(workload_start),
        .workload_type(workload_type), .work_done(d0), .work_result(core0_result),
        .cycle_count(core0_cycles), .instruction_count(ic0), .alu_count(core0_alu),
        .load_count(ld0), .store_count(st0), .branch_count(br0), .branch_taken_count(bt0)
    );
    riscv_partition_core_heavy core1(
        .clk(clk), .reset(reset), .enable(run_enable[1]),
        .work_start(s1), .work_end(e1), .work_valid(v1), .workload_start(workload_start),
        .workload_type(workload_type), .work_done(d1), .work_result(core1_result),
        .cycle_count(core1_cycles), .instruction_count(ic1), .alu_count(core1_alu),
        .load_count(ld1), .store_count(st1), .branch_count(br1), .branch_taken_count(bt1)
    );
    riscv_partition_core_heavy core2(
        .clk(clk), .reset(reset), .enable(run_enable[2]),
        .work_start(s2), .work_end(e2), .work_valid(v2), .workload_start(workload_start),
        .workload_type(workload_type), .work_done(d2), .work_result(core2_result),
        .cycle_count(core2_cycles), .instruction_count(ic2), .alu_count(core2_alu),
        .load_count(ld2), .store_count(st2), .branch_count(br2), .branch_taken_count(bt2)
    );
    riscv_partition_core_heavy core3(
        .clk(clk), .reset(reset), .enable(run_enable[3]),
        .work_start(s3), .work_end(e3), .work_valid(v3), .workload_start(workload_start),
        .workload_type(workload_type), .work_done(d3), .work_result(core3_result),
        .cycle_count(core3_cycles), .instruction_count(ic3), .alu_count(core3_alu),
        .load_count(ld3), .store_count(st3), .branch_count(br3), .branch_taken_count(bt3)
    );
endmodule

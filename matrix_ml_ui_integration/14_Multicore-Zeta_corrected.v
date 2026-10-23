module alu(
  input [31:0] operand_a,
  input [31:0] operand_b,
  input [3:0] alu_control,
  output reg [31:0] result);

  parameter ADD = 4'b0000;
  parameter SUB = 4'b0001;
  parameter AND = 4'b0010;
  parameter OR  = 4'b0011;
  parameter XOR = 4'b0100;
  parameter SLL = 4'b0101;
  parameter SRL = 4'b0110;
  parameter SRA = 4'b0111;
  parameter SLT = 4'b1000;
  parameter SLTU = 4'b1001;

  always@(*) begin
    case(alu_control)
      ADD :
        result = operand_a + operand_b;
      SUB :
        result = operand_a - operand_b;
      AND :
        result = operand_a & operand_b;
      OR :
        result = operand_a | operand_b;
      XOR :
        result = operand_a ^ operand_b;
      SLL :
        result = operand_a << operand_b[4:0] ;
      SRL :
        result = operand_a >> operand_b[4:0] ;
      SRA:
        result = ($signed(operand_a) >>>operand_b[4:0]);
      SLT :
        result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
      SLTU :
                  result = (operand_a < operand_b) ? 32'd1 : 32'd0;
      default :
        result = 32'd0;
    endcase
  end
endmodule

module register_file(
  input clk, reset,
  input reg_write,

  input [4:0] rs1,
  input [4:0] rs2,
  input [4:0] rd,

  input [31:0] write_data,

  output [31:0] read_data1,
  output [31:0] read_data2,
  output [31:0] debug_x12);

  reg [31:0] registers [31:0];
  integer i;

always @(posedge clk or posedge reset) begin
  if (reset) begin
    for (i = 0; i < 32; i = i + 1)
      registers[i] <= 32'b0;
  end else if (reg_write && (rd != 5'd0)) begin
    registers[rd] <= write_data;
  end
end

  assign read_data1 = (rs1 == 0)? 32'b0 : registers[rs1];
  assign read_data2 = (rs2 == 0)? 32'b0 : registers[rs2];
     assign debug_x12 = registers[12];
endmodule

  module immediate_generator(
    input  [31:0] instruction,
    input  [2:0]  imm_type,
    output reg [31:0] immediate
);

    // Immediate type encoding
    parameter I_TYPE = 3'b000;
    parameter S_TYPE = 3'b001;
    parameter B_TYPE = 3'b010;
    parameter U_TYPE = 3'b011;
    parameter J_TYPE = 3'b100;


    always @(*) begin

        case (imm_type)

            I_TYPE:
                immediate = {{20{instruction[31]}},
                             instruction[31:20]};

            S_TYPE:
                immediate = {{20{instruction[31]}},
                             instruction[31:25],
                             instruction[11:7]};

            B_TYPE:
                immediate = {{19{instruction[31]}},
                             instruction[31],
                             instruction[7],
                             instruction[30:25],
                             instruction[11:8],
                             1'b0};

            U_TYPE:
                immediate = {instruction[31:12],
                             12'b0};

            J_TYPE:
                immediate = {{11{instruction[31]}},
                             instruction[31],
                             instruction[19:12],
                             instruction[20],
                             instruction[30:21],
                             1'b0};

            default:
                immediate = 32'b0;

        endcase

    end

endmodule

module control_unit(
    input [6:0] opcode,
    input [2:0] funct3,

    output reg RegWrite,
    output reg ALUSrc,
    output reg MemRead,
    output reg MemWrite,
    output reg MemToReg,
    output reg Branch,
    output reg [1:0] ALUOp,
    output reg [2:0] imm_type
);

    localparam R_type = 7'b0110011;
    localparam I_type = 7'b0010011;
    localparam LW     = 7'b0000011;
    localparam SW     = 7'b0100011;
    localparam BEQ    = 7'b1100011;

    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;

    always @(*) begin
        RegWrite = 0;
        ALUSrc   = 0;
        MemRead  = 0;
        MemWrite = 0;
        MemToReg = 0;
        Branch   = 0;
        ALUOp    = 2'b00;
        imm_type = IMM_I;

        case(opcode)

            R_type: begin
                RegWrite = 1;
                ALUSrc   = 0;
                ALUOp    = 2'b10;
            end

            I_type: begin
                RegWrite = 1;
                ALUSrc   = 1;
                ALUOp    = 2'b10;
                imm_type = IMM_I;
            end

            LW: begin
                RegWrite = 1;
                ALUSrc   = 1;
                MemRead  = 1;
                MemToReg = 1;
                ALUOp    = 2'b00;
                imm_type = IMM_I;
            end

            SW: begin
                ALUSrc   = 1;
                MemWrite = 1;
                ALUOp    = 2'b00;
                imm_type = IMM_S;
            end

            BEQ: begin
                // Supported conditional branches: BEQ, BNE, BLT, BGE,
                // BLTU and BGEU. Reserved funct3 encodings remain inactive.
                case (funct3)
                    3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: begin
                        ALUSrc   = 1'b0;
                        Branch   = 1'b1;
                        ALUOp    = 2'b01;
                        imm_type = IMM_B;
                    end
                    default: begin
                        Branch = 1'b0;
                    end
                endcase
            end

            default: begin
            end

        endcase
    end

endmodule
module alu_control(
    input [1:0] ALUOp,
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg [3:0] alu_control
);


    parameter ADD  = 4'b0000;
    parameter SUB  = 4'b0001;
    parameter AND  = 4'b0010;
    parameter OR   = 4'b0011;
    parameter XOR  = 4'b0100;
    parameter SLL  = 4'b0101;
    parameter SRL  = 4'b0110;
    parameter SRA  = 4'b0111;
    parameter SLT  = 4'b1000;
    parameter SLTU = 4'b1001;

    always @(*) begin

        alu_control = ADD;

        case (ALUOp)

            2'b00: begin
                alu_control = ADD;
            end

            2'b01: begin
                alu_control = SUB;
            end

            2'b10: begin

                case (funct3)

                    3'b000: begin
                        // funct7 distinguishes ADD/SUB only for R-type instructions.
                        // For OP-IMM, instruction[31:25] belongs to the immediate.
                        if ((opcode == 7'b0110011) &&
                            (funct7 == 7'b0100000))
                            alu_control = SUB;
                        else
                            alu_control = ADD;
                    end

                    3'b001: begin
                        alu_control = SLL;
                    end

                    3'b010: begin
                        alu_control = SLT;
                    end

                    3'b011: begin
                        alu_control = SLTU;
                    end

                    3'b100: begin
                        alu_control = XOR;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0100000)
                            alu_control = SRA;
                        else
                            alu_control = SRL;
                    end

                    3'b110: begin
                        alu_control = OR;
                    end

                    3'b111: begin
                        alu_control = AND;
                    end

                    default: begin
                        alu_control = ADD;
                    end

                endcase
            end

            default: begin
                alu_control = ADD;
            end

        endcase
    end

endmodule
module pc(
    input clk,
    input reset,
    input [31:0] next_pc,
    output reg [31:0] pc
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 32'b0;
        else
            pc <= next_pc;
    end

endmodule
module instruction_memory(
    input  [31:0] address,
    output reg [31:0] instruction
);

    reg [31:0] memory [0:255];

    // 256 words = 1024 bytes. Out-of-range fetches safely behave as NOPs.
    always @(*) begin
        if (address[31:10] == 0)
            instruction = memory[address[9:2]];
        else
            instruction = 32'h00000013; // ADDI x0, x0, 0 (NOP)
    end

endmodule
module data_memory(
    input clk,
    input MemRead,
    input MemWrite,
    input [31:0] address,
    input [31:0] write_data,
    output reg [31:0] read_data
);

    reg [31:0] memory [0:255];

    // Read operation
    always @(*) begin
        if (MemRead)
            read_data = memory[address[31:2]];
        else
            read_data = 32'b0;
    end

    // Write operation
    always @(posedge clk) begin
        if (MemWrite)
            memory[address[31:2]] <= write_data;
    end

endmodule

module performance_counter(
    input clk,
    input reset,
    input enable,

    input alu_active,
    input load_active,
    input store_active,
    input branch_active,
    input branch_taken,

    output reg [31:0] cycle_count,
    output reg [31:0] instruction_count,
    output reg [31:0] alu_count,
    output reg [31:0] load_count,
    output reg [31:0] store_count,
    output reg [31:0] branch_count,
    output reg [31:0] branch_taken_count
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count        <= 32'd0;
            instruction_count  <= 32'd0;
            alu_count          <= 32'd0;
            load_count         <= 32'd0;
            store_count        <= 32'd0;
            branch_count       <= 32'd0;
            branch_taken_count <= 32'd0;
        end
        else if (enable) begin
            cycle_count       <= cycle_count + 32'd1;
            instruction_count <= instruction_count + 32'd1;

            if (alu_active)
                alu_count <= alu_count + 32'd1;

            if (load_active)
                load_count <= load_count + 32'd1;

            if (store_active)
                store_count <= store_count + 32'd1;

            if (branch_active)
                branch_count <= branch_count + 32'd1;

            if (branch_taken)
                branch_taken_count <= branch_taken_count + 32'd1;
        end
    end

endmodule

module core_manager(
    input [2:0] required_cores,
    output reg core0_enable,
    output reg core1_enable,
    output reg core2_enable,
    output reg core3_enable
);

    always @(*) begin

        core0_enable = 1'b0;
        core1_enable = 1'b0;
        core2_enable = 1'b0;
        core3_enable = 1'b0;

        case(required_cores)

            3'd0: begin
            end

            3'd1: begin
                core0_enable = 1'b1;
            end

            3'd2: begin
                core0_enable = 1'b1;
                core1_enable = 1'b1;
            end

            3'd3: begin
                core0_enable = 1'b1;
                core1_enable = 1'b1;
                core2_enable = 1'b1;
            end

            3'd4: begin
                core0_enable = 1'b1;
                core1_enable = 1'b1;
                core2_enable = 1'b1;
                core3_enable = 1'b1;
            end

            // Invalid or unknown requests fail safe: no core is enabled.
            default: begin
                core0_enable = 1'b0;
                core1_enable = 1'b0;
                core2_enable = 1'b0;
                core3_enable = 1'b0;
            end

        endcase
    end

endmodule

module clock_gating(
    input clk,
    input reset,
    input enable,
    output gated_clk
);

    reg enable_latched;

    always @(negedge clk or posedge reset) begin
        if (reset)
            enable_latched <= 1'b0;
        else
            enable_latched <= enable;
    end

    assign gated_clk = clk & enable_latched;

endmodule

module parallel_workload_controller(
    input clk, reset, start,
    input [31:0] total_work,
    input [2:0] required_cores,

    input core0_done, core1_done, core2_done, core3_done,

    output reg [31:0] core0_start, core0_end,
    output reg core0_valid,
    output reg [31:0] core1_start, core1_end,
    output reg core1_valid,
    output reg [31:0] core2_start, core2_end,
    output reg core2_valid,
    output reg [31:0] core3_start, core3_end,
    output reg core3_valid,
    output reg all_done
);

    reg [31:0] count;
    reg [31:0] base_work;
    reg [31:0] remainder;

    reg [31:0] next_start [0:3];
    reg [31:0] next_end [0:3];
    reg [3:0] next_valid;

    integer i_range;

    // ------------------------------------------------
    // Block 1: Determine worker count and distribution.
    // ------------------------------------------------
    always @(*) begin
        count = 0;
        base_work = 0;
        remainder = 0;

        if ((required_cores != 0) && (total_work != 0)) begin
            if (required_cores > 4)
                count = 32'd4;
            else if (total_work < {29'b0, required_cores})
                count = total_work;
            else
                count = {29'b0, required_cores};

            if (count != 0) begin
                base_work = total_work / count;
                remainder = total_work % count;
            end
        end
    end

    // ------------------------------------------------
    // Block 2: Compute each worker's inclusive range.
    // ------------------------------------------------
    always @(*) begin
        next_valid = 4'b0000;

        for (i_range = 0; i_range < 4; i_range = i_range + 1) begin
            next_start[i_range] = 32'd0;
            next_end[i_range] = 32'd0;

            if ((count != 0) && (i_range < count)) begin
                next_valid[i_range] = 1'b1;

                next_start[i_range] =
                    (i_range * base_work) +
                    ((i_range < remainder) ? i_range : remainder);

                next_end[i_range] =
                    next_start[i_range] + base_work +
                    ((i_range < remainder) ? 32'd1 : 32'd0) - 32'd1;
            end
        end
    end

    // ------------------------------------------------
    // Block 3: Register ranges and completion status.
    // ------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            core0_start <= 0;
            core0_end   <= 0;
            core0_valid <= 0;

            core1_start <= 0;
            core1_end   <= 0;
            core1_valid <= 0;

            core2_start <= 0;
            core2_end   <= 0;
            core2_valid <= 0;

            core3_start <= 0;
            core3_end   <= 0;
            core3_valid <= 0;

            all_done <= 0;
        end else if (start) begin
            core0_start <= next_start[0];
            core0_end   <= next_end[0];
            core0_valid <= next_valid[0];

            core1_start <= next_start[1];
            core1_end   <= next_end[1];
            core1_valid <= next_valid[1];

            core2_start <= next_start[2];
            core2_end   <= next_end[2];
            core2_valid <= next_valid[2];

            core3_start <= next_start[3];
            core3_end   <= next_end[3];
            core3_valid <= next_valid[3];

            all_done <= 0;
        end else if ((total_work == 0) ||
                     (required_cores == 0)) begin
            all_done <= 1;
        end else begin
            all_done <=
                ((!core0_valid) || core0_done) &&
                ((!core1_valid) || core1_done) &&
                ((!core2_valid) || core2_done) &&
                ((!core3_valid) || core3_done) &&
                (core0_valid || core1_valid ||
                 core2_valid || core3_valid);
        end
    end

endmodule


module parallel_shared_vector(
    input clk, reset, start,
    input [31:0] total_work,
    input [2:0] required_cores,
    output done,
    output [31:0] c0,c1,c2,c3,c4,c5,c6,c7
);

    reg [31:0] A [0:7];
    reg [31:0] B [0:7];
    reg [31:0] C [0:7];

    wire [31:0] s0,e0,s1,e1,s2,e2,s3,e3;
    wire v0,v1,v2,v3;
    wire all_done;

    reg d0,d1,d2,d3;
    reg a0,a1,a2,a3;
    reg [31:0] idx0,idx1,idx2,idx3;
    reg launch_pending;

    integer k;

    assign c0=C[0]; assign c1=C[1];
    assign c2=C[2]; assign c3=C[3];
    assign c4=C[4]; assign c5=C[5];
    assign c6=C[6]; assign c7=C[7];
    assign done=all_done;

    parallel_workload_controller ctrl(
        .clk(clk), .reset(reset), .start(start),
        .total_work(total_work),
        .required_cores(required_cores),
        .core0_done(d0), .core1_done(d1),
        .core2_done(d2), .core3_done(d3),
        .core0_start(s0), .core0_end(e0), .core0_valid(v0),
        .core1_start(s1), .core1_end(e1), .core1_valid(v1),
        .core2_start(s2), .core2_end(e2), .core2_valid(v2),
        .core3_start(s3), .core3_end(e3), .core3_valid(v3),
        .all_done(all_done)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            d0<=1; d1<=1; d2<=1; d3<=1;
            a0<=0; a1<=0; a2<=0; a3<=0;
            idx0<=0; idx1<=0; idx2<=0; idx3<=0;
            launch_pending<=0;

            for (k=0; k<8; k=k+1) begin
                A[k]<=k+1;
                B[k]<=(k+1)*10;
                C[k]<=0;
            end
        end else if (start) begin
            a0<=0; a1<=0; a2<=0; a3<=0;

            for (k=0; k<8; k=k+1)
                C[k]<=0;

            if (total_work == 0 || required_cores == 0) begin
                launch_pending<=0;
                d0<=1; d1<=1; d2<=1; d3<=1;
            end else begin
                launch_pending<=1;
                d0<=0;
                d1<=(required_cores < 2 || total_work < 2);
                d2<=(required_cores < 3 || total_work < 3);
                d3<=(required_cores < 4 || total_work < 4);
            end
        end else if (launch_pending) begin
            launch_pending<=0;

            a0<=v0; a1<=v1; a2<=v2; a3<=v3;
            idx0<=s0; idx1<=s1; idx2<=s2; idx3<=s3;

            d0<=!v0; d1<=!v1; d2<=!v2; d3<=!v3;
        end else begin
            if (a0) begin
                C[idx0]<=A[idx0]+B[idx0];
                if (idx0==e0) begin a0<=0; d0<=1; end
                else idx0<=idx0+1;
            end

            if (a1) begin
                C[idx1]<=A[idx1]+B[idx1];
                if (idx1==e1) begin a1<=0; d1<=1; end
                else idx1<=idx1+1;
            end

            if (a2) begin
                C[idx2]<=A[idx2]+B[idx2];
                if (idx2==e2) begin a2<=0; d2<=1; end
                else idx2<=idx2+1;
            end

            if (a3) begin
                C[idx3]<=A[idx3]+B[idx3];
                if (idx3==e3) begin a3<=0; d3<=1; end
                else idx3<=idx3+1;
            end
        end
    end

endmodule


module riscv_core(
    input clk,
    input reset,
	input enable,
	
	output [31:0] cycle_count,
	output [31:0] instruction_count,
	output [31:0] alu_count,
	output [31:0] load_count,
	output [31:0] store_count,
	output [31:0] branch_count,
	output [31:0] branch_taken_count
);

    wire [31:0] pc_value;
    wire [31:0] next_pc;
    wire [31:0] instruction;

    wire RegWrite;
    wire ALUSrc;
    wire MemRead;
    wire MemWrite;
    wire MemToReg;
    wire Branch;
    wire [1:0] ALUOp;
    wire [2:0] imm_type;

    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] immediate;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;
    wire [31:0] memory_data;
    wire [31:0] write_back_data;

    wire [3:0] alu_control_signal;

    wire branch_taken;

	

	wire alu_active;
	wire load_active;
	wire store_active;
	wire branch_active;


    // Count arithmetic/logical instruction classes explicitly.
    // OP     = R-type instructions
    // OP-IMM = immediate arithmetic/logical instructions
    // Exclude the canonical NOP: ADDI x0, x0, 0.
    assign alu_active =
        (instruction[6:0] == 7'b0110011) ||
        ((instruction[6:0] == 7'b0010011) &&
         (instruction != 32'h00000013));

    assign load_active   = MemRead;
    assign store_active  = MemWrite;
    assign branch_active = Branch;

	
	wire core_clk;
	clock_gating clock_gating_unit(
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .gated_clk(core_clk)
);

pc pc_unit(
    .clk(core_clk),
	.reset(reset),
    .next_pc(next_pc),
    .pc(pc_value)
);

    instruction_memory instruction_memory_unit(
        .address(pc_value),
        .instruction(instruction)
    );

    control_unit control_unit_unit(
        .opcode(instruction[6:0]),
        .funct3(instruction[14:12]),
        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),
        .Branch(Branch),
        .ALUOp(ALUOp),
        .imm_type(imm_type)
    );

    register_file register_file_unit(
        .clk(core_clk),
        .reset(reset),
        .reg_write(RegWrite),
        .rs1(instruction[19:15]),
        .rs2(instruction[24:20]),
        .rd(instruction[11:7]),
        .write_data(write_back_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    immediate_generator immediate_generator_unit(
        .instruction(instruction),
        .imm_type(imm_type),
        .immediate(immediate)
    );

    alu_control alu_control_unit(
        .ALUOp(ALUOp),
        .opcode(instruction[6:0]),
        .funct3(instruction[14:12]),
        .funct7(instruction[31:25]),
        .alu_control(alu_control_signal)
    );

    assign alu_operand_b = ALUSrc ? immediate : read_data2;

    alu alu_unit(
        .operand_a(read_data1),
        .operand_b(alu_operand_b),
        .alu_control(alu_control_signal),
        .result(alu_result)
    );

    data_memory data_memory_unit(
        .clk(core_clk),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .address(alu_result),
        .write_data(read_data2),
        .read_data(memory_data)
    );
	
	performance_counter performance_counter_unit(
    .clk(core_clk),
    .reset(reset),
    .enable(enable),
    .alu_active(alu_active),
    .load_active(load_active),
    .store_active(store_active),
    .branch_active(branch_active),
    .branch_taken(branch_taken),
    .cycle_count(cycle_count),
    .instruction_count(instruction_count),
    .alu_count(alu_count),
    .load_count(load_count),
    .store_count(store_count),
    .branch_count(branch_count),
    .branch_taken_count(branch_taken_count)
);

    assign write_back_data = MemToReg ? memory_data : alu_result;

    reg branch_condition;
    always @(*) begin
        case (instruction[14:12])
            3'b000: branch_condition = (read_data1 == read_data2); // BEQ
            3'b001: branch_condition = (read_data1 != read_data2); // BNE
            3'b100: branch_condition = ($signed(read_data1) <  $signed(read_data2)); // BLT
            3'b101: branch_condition = ($signed(read_data1) >= $signed(read_data2)); // BGE
            3'b110: branch_condition = (read_data1 <  read_data2); // BLTU
            3'b111: branch_condition = (read_data1 >= read_data2); // BGEU
            default: branch_condition = 1'b0;
        endcase
    end

    assign branch_taken = Branch && branch_condition;

    assign next_pc = branch_taken ?
                     (pc_value + immediate) :
                     (pc_value + 32'd4);

endmodule

module multicore_system(
    input clk,
    input reset,
    input [2:0] required_cores,
	output [3:0] core_enable,
	
	    // Parallel workload interface
    input workload_start,
    input [31:0] workload_size,
    output workload_done,

    output [31:0] vector_c0,
    output [31:0] vector_c1,
    output [31:0] vector_c2,
    output [31:0] vector_c3,
    output [31:0] vector_c4,
    output [31:0] vector_c5,
    output [31:0] vector_c6,
    output [31:0] vector_c7,
	
	output [31:0] core0_cycle_count,
	output [31:0] core0_instruction_count,
	output [31:0] core0_alu_count,
	output [31:0] core0_load_count,	
	output [31:0] core0_store_count,
	output [31:0] core0_branch_count,
	output [31:0] core0_branch_taken_count,

	output [31:0] core1_cycle_count,
	output [31:0] core1_instruction_count,
	output [31:0] core1_alu_count,
	output [31:0] core1_load_count,
	output [31:0] core1_store_count,
	output [31:0] core1_branch_count,
	output [31:0] core1_branch_taken_count,
		
	output [31:0] core2_cycle_count,
	output [31:0] core2_instruction_count,
	output [31:0] core2_alu_count,
	output [31:0] core2_load_count,
	output [31:0] core2_store_count,
	output [31:0] core2_branch_count,
	output [31:0] core2_branch_taken_count,

	output [31:0] core3_cycle_count,
	output [31:0] core3_instruction_count,
	output [31:0] core3_alu_count,
	output [31:0] core3_load_count,
	output [31:0] core3_store_count,
	output [31:0] core3_branch_count,
	output [31:0] core3_branch_taken_count
);

    wire core0_enable;
    wire core1_enable;
    wire core2_enable;
    wire core3_enable;
	
	assign core_enable = {
    core3_enable,
    core2_enable,
    core1_enable,
    core0_enable
};

    core_manager core_manager_unit(
        .required_cores(required_cores),
        .core0_enable(core0_enable),
        .core1_enable(core1_enable),
        .core2_enable(core2_enable),
        .core3_enable(core3_enable)
    );

    riscv_core core0(
        .clk(clk),
        .reset(reset),
        .enable(core0_enable),
        .cycle_count(core0_cycle_count),
        .instruction_count(core0_instruction_count),
        .alu_count(core0_alu_count),
        .load_count(core0_load_count),
        .store_count(core0_store_count),
        .branch_count(core0_branch_count),
        .branch_taken_count(core0_branch_taken_count)
    );

    riscv_core core1(
        .clk(clk),
        .reset(reset),
        .enable(core1_enable),
        .cycle_count(core1_cycle_count),
        .instruction_count(core1_instruction_count),
        .alu_count(core1_alu_count),
        .load_count(core1_load_count),
        .store_count(core1_store_count),
        .branch_count(core1_branch_count),
        .branch_taken_count(core1_branch_taken_count)
    );

    riscv_core core2(
        .clk(clk),
        .reset(reset),
        .enable(core2_enable),
        .cycle_count(core2_cycle_count),
        .instruction_count(core2_instruction_count),
        .alu_count(core2_alu_count),
        .load_count(core2_load_count),
        .store_count(core2_store_count),
        .branch_count(core2_branch_count),
        .branch_taken_count(core2_branch_taken_count)
    );

    riscv_core core3(
        .clk(clk),
        .reset(reset),
        .enable(core3_enable),
        .cycle_count(core3_cycle_count),
        .instruction_count(core3_instruction_count),
        .alu_count(core3_alu_count),
        .load_count(core3_load_count),
        .store_count(core3_store_count),
        .branch_count(core3_branch_count),
        .branch_taken_count(core3_branch_taken_count)
    );
	
	// Limit workload size to the 8 elements supported
    // by parallel_shared_vector.
    wire [31:0] bounded_workload_size;

    assign bounded_workload_size =
        (workload_size > 32'd8) ? 32'd8 : workload_size;

    parallel_shared_vector vector_workload_unit (
        .clk(clk),
        .reset(reset),
        .start(workload_start),
        .total_work(bounded_workload_size),
        .required_cores(required_cores),
        .done(workload_done),

        .c0(vector_c0),
        .c1(vector_c1),
        .c2(vector_c2),
        .c3(vector_c3),
        .c4(vector_c4),
        .c5(vector_c5),
        .c6(vector_c6),
        .c7(vector_c7)
    );

endmodule

module riscv_partition_core(
    input clk,
    input reset,
	input enable,
    input [31:0] work_start,
    input [31:0] work_end,
    input work_valid,
    input workload_start,
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

    wire [31:0] pc_value;
    wire [31:0] next_pc;
    reg [31:0] instruction;
    wire [31:0] memory_instruction;
    wire core_reset;

    wire RegWrite;
    wire ALUSrc;
    wire MemRead;
    wire MemWrite;
    wire MemToReg;
    wire Branch;
    wire [1:0] ALUOp;
    wire [2:0] imm_type;

    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] immediate;
    wire [31:0] alu_operand_b;
    wire [31:0] alu_result;
    wire [31:0] memory_data;
    wire [31:0] write_back_data;

    wire [3:0] alu_control_signal;

    wire branch_taken;

	

	wire alu_active;
	wire load_active;
	wire store_active;
	wire branch_active;

	assign alu_active = (instruction[6:0] == 7'b0110011) ||
                        ((instruction[6:0] == 7'b0010011) &&
                         (instruction != 32'h00000013));
	assign load_active = MemRead;
	assign store_active = MemWrite;
	assign branch_active = Branch;
	
	wire core_clk;
	clock_gating clock_gating_unit(
    .clk(clk),
    .reset(core_reset),
    .enable(enable),
    .gated_clk(core_clk)
);

assign core_reset = reset | workload_start;

assign work_done = work_valid && (pc_value == 32'd28);

pc pc_unit(
    .clk(core_clk),
	.reset(core_reset),
    .next_pc(next_pc),
    .pc(pc_value)
);

    instruction_memory instruction_memory_unit(
        .address(pc_value),
        .instruction(memory_instruction)
    );

    // A compact built-in worker program. The controller supplies an inclusive
    // start/end index. x10 is the loop index; x11 is the end; x12 accumulates
    // the sum of all indices assigned to this worker.
    always @(*) begin
        case (pc_value)
            32'd0: instruction = {work_start[11:0], 5'd0, 3'b000, 5'd10, 7'b0010011}; // ADDI x10,x0,start
            32'd4: instruction = {work_end[11:0],   5'd0, 3'b000, 5'd11, 7'b0010011}; // ADDI x11,x0,end
            32'd8:  instruction = 32'h00000613; // ADDI x12,x0,0
            32'd12: instruction = 32'h00A60633; // ADD x12,x12,x10
            32'd16: instruction = 32'h00B50663; // BEQ x10,x11,+12 (finish)
            32'd20: instruction = 32'h00150513; // ADDI x10,x10,1
            32'd24: instruction = 32'hFE000AE3; // BEQ x0,x0,-12 (loop)
            32'd28: instruction = 32'h00000063; // BEQ x0,x0,0 (park)
            default: instruction = 32'h00000013; // NOP outside worker program
        endcase
    end

    control_unit control_unit_unit(
        .opcode(instruction[6:0]),
        .funct3(instruction[14:12]),
        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),
        .Branch(Branch),
        .ALUOp(ALUOp),
        .imm_type(imm_type)
    );

    register_file register_file_unit(
        .clk(core_clk),
        .reset(core_reset),
        .reg_write(RegWrite),
        .rs1(instruction[19:15]),
        .rs2(instruction[24:20]),
        .rd(instruction[11:7]),
        .write_data(write_back_data),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .debug_x12(work_result)
    );

    immediate_generator immediate_generator_unit(
        .instruction(instruction),
        .imm_type(imm_type),
        .immediate(immediate)
    );

    alu_control alu_control_unit(
        .ALUOp(ALUOp),
        .opcode(instruction[6:0]),
        .funct3(instruction[14:12]),
        .funct7(instruction[31:25]),
        .alu_control(alu_control_signal)
    );

    assign alu_operand_b = ALUSrc ? immediate : read_data2;

    alu alu_unit(
        .operand_a(read_data1),
        .operand_b(alu_operand_b),
        .alu_control(alu_control_signal),
        .result(alu_result)
    );

    data_memory data_memory_unit(
        .clk(core_clk),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .address(alu_result),
        .write_data(read_data2),
        .read_data(memory_data)
    );
	
	performance_counter performance_counter_unit(
    .clk(core_clk),
    .reset(core_reset),
    .enable(enable),
    .alu_active(alu_active),
    .load_active(load_active),
    .store_active(store_active),
    .branch_active(branch_active),
    .branch_taken(branch_taken),
    .cycle_count(cycle_count),
    .instruction_count(instruction_count),
    .alu_count(alu_count),
    .load_count(load_count),
    .store_count(store_count),
    .branch_count(branch_count),
    .branch_taken_count(branch_taken_count)
);

    assign write_back_data = MemToReg ? memory_data : alu_result;

    reg branch_condition;
    always @(*) begin
        case (instruction[14:12])
            3'b000: branch_condition = (read_data1 == read_data2); // BEQ
            3'b001: branch_condition = (read_data1 != read_data2); // BNE
            3'b100: branch_condition = ($signed(read_data1) <  $signed(read_data2)); // BLT
            3'b101: branch_condition = ($signed(read_data1) >= $signed(read_data2)); // BGE
            3'b110: branch_condition = (read_data1 <  read_data2); // BLTU
            3'b111: branch_condition = (read_data1 >= read_data2); // BGEU
            default: branch_condition = 1'b0;
        endcase
    end

    assign branch_taken = Branch && branch_condition;

    assign next_pc = branch_taken ?
                     (pc_value + immediate) :
                     (pc_value + 32'd4);

endmodule

// Experimental CPU-driven workload top. This is separate from multicore_system
// so the existing vector-FSM interface and regression tests remain unchanged.
module multicore_cpu_workload_system(
    input clk,
    input reset,
    input [2:0] required_cores,
    input workload_start,
    input [31:0] workload_size,
    output [3:0] core_enable,
    output workload_done,
    output [31:0] core0_result, core1_result, core2_result, core3_result,
    output [31:0] core0_cycles, core1_cycles, core2_cycles, core3_cycles,
    output [31:0] core0_alu, core1_alu, core2_alu, core3_alu
);
    wire [2:0] bounded_cores = (required_cores > 3'd4) ? 3'd4 : required_cores;
    wire [31:0] bounded_work = (workload_size > 32'd8) ? 32'd8 : workload_size;

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
        .core0_enable(m0), .core1_enable(m1),
        .core2_enable(m2), .core3_enable(m3)
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

    riscv_partition_core core0(
        .clk(clk), .reset(reset), .enable(run_enable[0]),
        .work_start(s0), .work_end(e0), .work_valid(v0), .workload_start(workload_start),
        .work_done(d0), .work_result(core0_result),
        .cycle_count(core0_cycles), .instruction_count(ic0), .alu_count(core0_alu),
        .load_count(ld0), .store_count(st0), .branch_count(br0), .branch_taken_count(bt0)
    );
    riscv_partition_core core1(
        .clk(clk), .reset(reset), .enable(run_enable[1]),
        .work_start(s1), .work_end(e1), .work_valid(v1), .workload_start(workload_start),
        .work_done(d1), .work_result(core1_result),
        .cycle_count(core1_cycles), .instruction_count(ic1), .alu_count(core1_alu),
        .load_count(ld1), .store_count(st1), .branch_count(br1), .branch_taken_count(bt1)
    );
    riscv_partition_core core2(
        .clk(clk), .reset(reset), .enable(run_enable[2]),
        .work_start(s2), .work_end(e2), .work_valid(v2), .workload_start(workload_start),
        .work_done(d2), .work_result(core2_result),
        .cycle_count(core2_cycles), .instruction_count(ic2), .alu_count(core2_alu),
        .load_count(ld2), .store_count(st2), .branch_count(br2), .branch_taken_count(bt2)
    );
    riscv_partition_core core3(
        .clk(clk), .reset(reset), .enable(run_enable[3]),
        .work_start(s3), .work_end(e3), .work_valid(v3), .workload_start(workload_start),
        .work_done(d3), .work_result(core3_result),
        .cycle_count(core3_cycles), .instruction_count(ic3), .alu_count(core3_alu),
        .load_count(ld3), .store_count(st3), .branch_count(br3), .branch_taken_count(bt3)
    );
endmodule

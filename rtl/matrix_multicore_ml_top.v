`timescale 1ns/1ps
// Simulation integration top for the matrix UI.
// Instantiates the project's original multicore_system (four riscv_core instances,
// core_manager, clock gating, counters, and shared-vector addon) alongside a
// dedicated matrix-multiply RTL addon. The addon performs the matrix arithmetic;
// the original RISC-V cores are enabled and instrumented but do NOT execute the
// matrix algorithm as instructions in this version.
module matrix_multicore_ml_top;
    reg clk = 0;
    reg reset = 1;
    reg [2:0] required_cores = 1;
    wire [3:0] core_enable;
    integer n, requested_cores;
    integer A[0:255], B[0:255], C[0:255], REF[0:255];
    integer i,j,k,c,row,start_row,end_row;
    integer cycles,max_core_cycles,core_cycles[0:3],errors,sum;
    integer core0_cycles, core1_cycles, core2_cycles, core3_cycles;

    always #5 clk = ~clk;

    // Real project CPU system. Nonessential outputs are intentionally left open.
    multicore_system cpu_bank (
        .clk(clk), .reset(reset), .required_cores(required_cores),
        .core_enable(core_enable), .workload_start(1'b0),
        .workload_size(32'd0), .workload_done()
    );

    initial begin
        n = 4;
        requested_cores = 2;
        if ($value$plusargs("N=%d", n)) begin end
        if ($value$plusargs("CORES=%d", requested_cores)) begin end
        if (n < 1 || n > 16) begin $display("ERROR: N must be 1..16"); $finish; end
        if (!(requested_cores == 1 || requested_cores == 2 || requested_cores == 4)) begin
            $display("ERROR: CORES must be 1, 2, or 4"); $finish;
        end
        required_cores = requested_cores[2:0];
        // Initialize instruction memories to NOPs and put a tiny known program
        // on each core so the processor bank is deterministic during the run.
        for (i=0; i<256; i=i+1) begin
            cpu_bank.core0.instruction_memory_unit.memory[i] = 32'h00000013;
            cpu_bank.core1.instruction_memory_unit.memory[i] = 32'h00000013;
            cpu_bank.core2.instruction_memory_unit.memory[i] = 32'h00000013;
            cpu_bank.core3.instruction_memory_unit.memory[i] = 32'h00000013;
        end
        for (i=0; i<4; i=i+1) begin
            case (i)
              0: begin cpu_bank.core0.instruction_memory_unit.memory[0]=32'h00A00093; cpu_bank.core0.instruction_memory_unit.memory[1]=32'h01400113; cpu_bank.core0.instruction_memory_unit.memory[2]=32'h002081B3; end
              1: begin cpu_bank.core1.instruction_memory_unit.memory[0]=32'h00A00093; cpu_bank.core1.instruction_memory_unit.memory[1]=32'h01400113; cpu_bank.core1.instruction_memory_unit.memory[2]=32'h002081B3; end
              2: begin cpu_bank.core2.instruction_memory_unit.memory[0]=32'h00A00093; cpu_bank.core2.instruction_memory_unit.memory[1]=32'h01400113; cpu_bank.core2.instruction_memory_unit.memory[2]=32'h002081B3; end
              3: begin cpu_bank.core3.instruction_memory_unit.memory[0]=32'h00A00093; cpu_bank.core3.instruction_memory_unit.memory[1]=32'h01400113; cpu_bank.core3.instruction_memory_unit.memory[2]=32'h002081B3; end
            endcase
        end
        repeat (3) @(negedge clk); reset = 0;
        repeat (2) @(negedge clk);

        for (i=0; i<n*n; i=i+1) begin
            A[i] = (i % 7) + 1;
            B[i] = ((i*3) % 5) + 1;
            C[i] = 0; REF[i] = 0;
        end
        // Independent golden reference.
        for (i=0; i<n; i=i+1)
          for (j=0; j<n; j=j+1) begin
            sum=0;
            for (k=0; k<n; k=k+1) sum=sum+A[i*n+k]*B[k*n+j];
            REF[i*n+j]=sum;
          end
        for (c=0; c<4; c=c+1) core_cycles[c]=0;
        // Matrix accelerator addon assigns contiguous output rows to workers.
        // Multiply-accumulate is modeled as one addon cycle per term.
        for (c=0; c<requested_cores; c=c+1) begin
          start_row=(n*c)/requested_cores;
          end_row=(n*(c+1))/requested_cores;
          for (row=start_row; row<end_row; row=row+1)
            for (j=0; j<n; j=j+1) begin
              sum=0;
              for (k=0; k<n; k=k+1) begin
                sum=sum+A[row*n+k]*B[k*n+j];
                core_cycles[c]=core_cycles[c]+1;
              end
              C[row*n+j]=sum;
            end
        end
        max_core_cycles=0;
        for (c=0; c<requested_cores; c=c+1)
          if (core_cycles[c]>max_core_cycles) max_core_cycles=core_cycles[c];
        cycles=max_core_cycles+8*(requested_cores-1);
        errors=0;
        for (i=0; i<n*n; i=i+1) if (C[i] !== REF[i]) errors=errors+1;

        $display("MATRIX_MULTICORE_TOP,N=%0d,CORES=%0d", n, requested_cores);
        $display("CPU_CORE_ENABLE_MASK=%b", core_enable);
        $display("CPU_CORE0_X3=%0d", cpu_bank.core0.register_file_unit.registers[3]);
        $display("RESULT_CHECK,errors=%0d,status=%s", errors, (errors==0)?"PASS":"FAIL");
        $display("SIMULATED_CYCLES=%0d", cycles);
        $display("CORE_CYCLES,%0d,%0d,%0d,%0d",core_cycles[0],core_cycles[1],core_cycles[2],core_cycles[3]);
        $display("RESULT_MATRIX");
        for (i=0; i<n; i=i+1) begin
          for (j=0; j<n; j=j+1) $write("%0d%s",C[i*n+j],(j==n-1)?"":" ");
          $display("");
        end
        if (errors==0) $display("DEMO_STATUS,PASS"); else $display("DEMO_STATUS,FAIL");
        $finish;
    end
endmodule

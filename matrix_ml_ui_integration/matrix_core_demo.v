`timescale 1ns/1ps

module matrix_core_demo;
    integer n, requested_cores;
    integer A[0:255], B[0:255], C[0:255], REF[0:255];
    integer i,j,k,c, row, start_row, end_row;
    integer cycles, max_core_cycles, core_cycles[0:3];
    integer errors;
    integer seed;
    integer a,b,sum;

    initial begin
        n = 4;
        requested_cores = 2;
        if ($value$plusargs("N=%d", n)) begin end
        if ($value$plusargs("CORES=%d", requested_cores)) begin end
        if (n < 1 || n > 16) begin
            $display("ERROR: N must be 1..16");
            $finish;
        end
        if (!(requested_cores >= 1 && requested_cores <= 4)) begin
            $display("ERROR: CORES must be 1, 2, 3, or 4");
            $finish;
        end

        for (i=0; i<n*n; i=i+1) begin
            A[i] = (i % 7) + 1;
            B[i] = ((i*3) % 5) + 1;
            C[i] = 0;
            REF[i] = 0;
        end

        // Golden result is computed independently in the testbench.
        for (i=0; i<n; i=i+1)
            for (j=0; j<n; j=j+1) begin
                sum = 0;
                for (k=0; k<n; k=k+1)
                    sum = sum + A[i*n+k] * B[k*n+j];
                REF[i*n+j] = sum;
            end

        for (c=0; c<4; c=c+1) core_cycles[c]=0;
        // Each active worker owns a contiguous block of rows.
        // One multiply-accumulate is modeled as one cycle.
        for (c=0; c<requested_cores; c=c+1) begin
            start_row = (n*c)/requested_cores;
            end_row = (n*(c+1))/requested_cores;
            for (row=start_row; row<end_row; row=row+1)
                for (j=0; j<n; j=j+1) begin
                    sum = 0;
                    for (k=0; k<n; k=k+1) begin
                        sum = sum + A[row*n+k] * B[k*n+j];
                        core_cycles[c] = core_cycles[c] + 1;
                    end
                    C[row*n+j] = sum;
                end
        end

        max_core_cycles = 0;
        for (c=0; c<requested_cores; c=c+1)
            if (core_cycles[c] > max_core_cycles) max_core_cycles=core_cycles[c];
        cycles = max_core_cycles + (8 * (requested_cores - 1)); // modeled coordination overhead
        errors = 0;
        for (i=0; i<n*n; i=i+1)
            if (C[i] !== REF[i]) errors = errors + 1;

        $display("MATRIX_DEMO,N=%0d,CORES=%0d", n, requested_cores);
        $display("RESULT_CHECK,errors=%0d,status=%s", errors, (errors==0) ? "PASS" : "FAIL");
        $display("SIMULATED_CYCLES=%0d", cycles);
        $display("CORE_CYCLES,%0d,%0d,%0d,%0d", core_cycles[0],core_cycles[1],core_cycles[2],core_cycles[3]);
        $display("RESULT_MATRIX");
        for (i=0; i<n; i=i+1) begin
            for (j=0; j<n; j=j+1) $write("%0d%s", C[i*n+j], (j==n-1) ? "" : " ");
            $display("");
        end
        if (errors==0) $display("DEMO_STATUS,PASS");
        else $display("DEMO_STATUS,FAIL");
        $finish;
    end
endmodule

Multicore RTL diagnostic testbench suite
========================================

Files:
- tb_decode_regression.v
  Tests ADDI-vs-SUB ALU decoding, supported/reserved branch funct3 decode,
  JAL/JALR/LUI/AUIPC lack of control-unit support, and core_manager safe masks.
  Unsupported ISA instructions are printed as FINDINGs because the supplied RTL
  currently does not implement them; they are not treated as a passing feature.

- tb_state_memory_counter.v
  Tests x0 behavior, register write/read, uninitialized register/data memory
  diagnostics, counter increments, and counter hold while disabled.

- tb_clock_gating.v
  Tests stable enable/disable/resume behavior. It deliberately avoids changing
  enable exactly at negedge; a separate race/stress test with waveform inspection
  is needed for simultaneous reset/enable changes near negedge.

- tb_parallel_controller.v
  Tests range partitioning, work coverage, clamping requests above four workers,
  and zero-work behavior.

Run from project root in PowerShell (assuming RTL is at .\rtl\14_Multicore-Zeta_corrected.v):

New-Item -ItemType Directory -Force .\build | Out-Null

iverilog -g2012 -s tb_decode_regression -o .\build\tb_decode.vvp .\rtl\14_Multicore-Zeta_corrected.v .\tb\tb_decode_regression.v
vvp .\build\tb_decode.vvp

iverilog -g2012 -s tb_state_memory_counter -o .\build\tb_state.vvp .\rtl\14_Multicore-Zeta_corrected.v .\tb\tb_state_memory_counter.v
vvp .\build\tb_state.vvp

iverilog -g2012 -s tb_clock_gating -o .\build\tb_clock.vvp .\rtl\14_Multicore-Zeta_corrected.v .\tb\tb_clock_gating.v
vvp .\build\tb_clock.vvp

iverilog -g2012 -s tb_parallel_controller -o .\build\tb_parallel.vvp .\rtl\14_Multicore-Zeta_corrected.v .\tb\tb_parallel_controller.v
vvp .\build\tb_parallel.vvp

Important:
- These tests are diagnostic, not proof of complete RV32I compliance.
- The supplied RTL has no reset ports for register_file or data_memory. Their
  initial contents are therefore expected to be X unless the testbench writes
  them. This suite reports that as FINDING, not as an unexpected test failure.
- The multicore architecture issue (CPU cores not actually executing the
  parallel vector workload) requires an architectural/integration test; the
  controller test only verifies range allocation.
- Run tests against the exact RTL file you intend to verify.


Additional integration diagnostics:
- tb_nop_counter.v
  Initializes a core's instruction memory with NOPs and checks whether the ALU
  counter increments for those NOP cycles.
- tb_multicore_architecture.v
  Runs the vector FSM while all four RISC-V cores execute NOPs, demonstrating
  that vector results are generated independently of CPU instruction execution.

Additional commands:

iverilog -g2012 -s tb_nop_counter -o .\build\tb_nop.vvp .\rtl\14_Multicore-Zeta_corrected.v .\tb\tb_nop_counter.v
vvp .\build\tb_nop.vvp

iverilog -g2012 -s tb_multicore_architecture -o .\build\tb_arch.vvp .\rtl\14_Multicore-Zeta_corrected.v .\tb\tb_multicore_architecture.v
vvp .\build\tb_arch.vvp

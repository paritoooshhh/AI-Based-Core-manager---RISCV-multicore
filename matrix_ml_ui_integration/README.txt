AI Multicore Scheduler - Matrix UI integration package

EXPECTED PROJECT LAYOUT
Final Folder\
  rtl\14_Multicore-Zeta_corrected.v
  ml\models\deadline_core_scheduler.joblib
  data\heavy_workload_dataset.csv
  matrix_ml_ui_integration\matrix_scheduler_ui.py
  matrix_ml_ui_integration\predict_and_run.py
  matrix_ml_ui_integration\matrix_multicore_ml_top.v
  matrix_ml_ui_integration\run_matrix_demo.ps1

The UI and helper scripts live in Final Folder\matrix_ml_ui_integration. The scripts find the project root as the parent folder, load the actual RTL from ..\rtl, and look for the saved model/dataset in ..\ml and ..\data. The bundled 14_Multicore-Zeta_corrected.v is a reference snapshot only; the launcher does not compile it.

RUN
Open PowerShell in Final Folder and run:
  .\matrix_ml_ui_integration\run_matrix_demo.ps1
Or launch the UI:
  python .\matrix_ml_ui_integration\matrix_scheduler_ui.py

Requires Python packages pandas, scikit-learn, joblib and Icarus Verilog (iverilog/vvp) on PATH.

SCOPE NOTE
The new top instantiates the original multicore_system (four RISC-V cores, core manager, clock gating and counters) and a matrix computation addon. The CPU bank executes a tiny arithmetic verification program; matrix arithmetic is currently performed by behavioral addon logic, not by RISC-V instructions. The saved scheduler model was trained on non-matrix workload profiles, so its prediction is a proxy rather than a matrix-trained policy. Cycle counts are simulation estimates, not physical timing or measured energy.

"""Run the matrix RTL addon and use the project's saved scheduler when available."""
import sys, subprocess
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
N = int(sys.argv[1]) if len(sys.argv) > 1 else 4
if not 1 <= N <= 16:
    raise SystemExit("Choose matrix size N from 1 to 16.")

# Prefer the user's already-trained project model. Its features were trained on
# arithmetic/branch/memory/mixed workload profiles, not matrix benchmarks, so
# matrix features below are explicitly an approximation/proxy, not retraining.
model_paths = [PROJECT_ROOT / "ml" / "models" / "deadline_core_scheduler.joblib",
               PROJECT_ROOT / "ml" / "models" / "deadline_core_scheduler_144.joblib"]
selected_model = next((p for p in model_paths if p.exists()), None)
model_kind = "project_saved_model"
prediction = None
if selected_model:
    try:
        import joblib
        bundle = joblib.load(selected_model)
        model = bundle["model"] if isinstance(bundle, dict) else bundle
        feature_columns = bundle.get("feature_columns", []) if isinstance(bundle, dict) else []
        dataset_path = PROJECT_ROOT / "data" / "heavy_workload_dataset.csv"
        if not dataset_path.exists():
            dataset_path = PROJECT_ROOT / "data" / "heavy_workload_dataset_144.csv"
        if dataset_path.exists() and feature_columns:
            df = pd.read_csv(dataset_path)
            subset = df[(df["workload_type"] == "mixed") & (df["requested_cores"] == 1)].copy()
            if subset.empty:
                subset = df[df["requested_cores"] == 1].copy()
            target_size = min(256, max(8, N ** 3))
            base = subset.iloc[int((subset["workload_size"] - target_size).abs().to_numpy().argmin())]
            scale = (N ** 3) / max(1, int(base["workload_size"]))
            features = {
                "workload_type": "mixed",
                "workload_size": target_size,
                "deadline_ratio": 0.75,
                "instruction_count_1c": int(round(float(base.get("instruction_count", 1)) * scale)),
                "alu_count_1c": int(round(float(base.get("alu_count", 1)) * scale)),
                "load_count_1c": int(round(float(base.get("load_count", 1)) * scale)),
                "store_count_1c": int(round(float(base.get("store_count", 1)) * scale)),
                "branch_count_1c": int(round(float(base.get("branch_count", 1)) * scale)),
                "branch_taken_count_1c": int(round(float(base.get("branch_taken_count", 1)) * scale)),
            }
            X = pd.DataFrame([{c: features[c] for c in feature_columns}])
            prediction = int(model.predict(X)[0])
            print(f"MODEL_TYPE,{selected_model.name}")
            print(f"MODEL_SCOPE,project scheduler applied to a matrix-workload proxy; validate before treating as matrix-trained policy")
    except Exception as e:
        print(f"MODEL_LOAD_WARNING,{type(e).__name__}:{e}")

if prediction not in (1, 2, 3, 4):
    # Explicit fallback if the trained project model isn't beside the UI.
    model_kind = "fallback_decision_tree_synthetic_labels"
    from sklearn.tree import DecisionTreeClassifier
    rows = []
    for n in range(1, 17):
        candidate = {c: ((n+c-1)//c)*n*n+8*(c-1) for c in (1,2,3,4)}
        best = min((cyc, cores) for cores,cyc in candidate.items())[1]
        rows.append({"matrix_size":n,"operations":n**3,"best_core_label":best})
    train = pd.DataFrame(rows)
    fallback = DecisionTreeClassifier(max_depth=3, random_state=42).fit(train[["matrix_size","operations"]], train["best_core_label"])
    prediction = int(fallback.predict(pd.DataFrame([{"matrix_size":N,"operations":N**3}]))[0])
    print("MODEL_SCOPE,fallback decision tree trained on synthetic cycle labels; not the project scheduler")
print(f"MODEL_PREDICTION,matrix_size={N},selected_cores={prediction}")

exe = ROOT / "matrix_demo.vvp"
if not exe.exists():
    raise SystemExit("Missing matrix_demo.vvp. Launch the UI or run run_matrix_demo.ps1 first.")
results = {}
for cores in (1, 2, 3, 4):
    p = subprocess.run(["vvp", str(exe), f"+N={N}", f"+CORES={cores}"], capture_output=True, text=True)
    output = p.stdout + p.stderr
    print(f"\n--- Candidate: {cores} core(s) ---")
    print(output, end="")
    cyc = None
    for line in output.splitlines():
        if line.startswith("SIMULATED_CYCLES="):
            cyc = int(line.split("=", 1)[1])
    if "DEMO_STATUS,PASS" not in output or cyc is None:
        raise SystemExit("Simulation failed or output could not be parsed.")
    results[cores] = cyc
print("\nCANDIDATE_SUMMARY")
for cores, cyc in results.items(): print(f"cores={cores},cycles={cyc}")
print(f"PREDICTED_CONFIGURATION,cores={prediction},cycles={results.get(prediction, 'unsupported')}")
print("INTERPRETATION,matrix arithmetic runs in a behavioral RTL accelerator addon; original RISC-V core bank is instantiated/enabled and executes a tiny verification program, not the matrix algorithm. Cycle model is not physical timing or measured energy.")

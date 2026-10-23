from pathlib import Path
import csv
import joblib
import pandas as pd
from sklearn.tree import DecisionTreeClassifier, export_text

ROOT = Path(__file__).resolve().parent.parent
RAW_FILE = ROOT / "results" / "benchmark_raw.csv"
DATA_FILE = ROOT / "data" / "scheduler_training_data.csv"
MODEL_FILE = ROOT / "models" / "scheduler_tree.joblib"

def read_benchmark_rows(path: Path) -> pd.DataFrame:
    rows = []
    if not path.exists():
        raise FileNotFoundError(
            f"Cannot find {path}\n"
            "Save the simulator output to ml/results/benchmark_raw.csv first."
        )

    with path.open("r", encoding="utf-16") as handle:
        for line in handle:
            parts = [part.strip() for part in line.strip().split(",")]
            if len(parts) == 6 and parts[0] == "DATA":
                rows.append({
                    "workload_size": int(parts[1]),
                    "requested_cores": int(parts[2]),
                    "active_cores": int(parts[3]),
                    "elapsed_cycles": int(parts[4]),
                    "result_correct": int(parts[5]),
                })

    if not rows:
        raise ValueError(
            "No DATA rows found. Ensure benchmark_raw.csv contains the "
            "simulator's DATA,... lines."
        )

    df = pd.DataFrame(rows)
    if not (df["result_correct"] == 1).all():
        bad = df[df["result_correct"] != 1]
        raise ValueError(f"Benchmark has incorrect result rows:\n{bad}")

    return df

def main():
    df = read_benchmark_rows(RAW_FILE)
    df.to_csv(DATA_FILE, index=False)

    # For each workload size, select the requested core count with the
    # lowest measured completion cycles. Break ties by requesting fewer cores.
    best = (
        df.sort_values(
            ["workload_size", "elapsed_cycles", "requested_cores"],
            ascending=[True, True, True],
        )
        .drop_duplicates(subset=["workload_size"], keep="first")
        .sort_values("workload_size")
        .reset_index(drop=True)
    )
    best = best.rename(columns={"requested_cores": "best_cores"})
    best[["workload_size", "best_cores", "elapsed_cycles"]].to_csv(
        ROOT / "data" / "scheduler_labels.csv", index=False
    )

    X = best[["workload_size"]]
    y = best["best_cores"]

    # Small interpretable proof-of-concept model. Eight workload sizes are
    # not enough to claim generalization; this is a first training milestone.
    model = DecisionTreeClassifier(max_depth=3, random_state=42)
    model.fit(X, y)
    MODEL_FILE.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_FILE)

    best["predicted_cores"] = model.predict(X)
    print("=== ML SCHEDULER TRAINING ===")
    print(f"Benchmark rows parsed: {len(df)}")
    print(f"Unique workload sizes: {len(best)}")
    print(f"All benchmark results correct: {(df['result_correct'] == 1).all()}")
    print("\nTraining labels selected from measured cycle counts:")
    print(best[["workload_size", "best_cores", "elapsed_cycles", "predicted_cores"]].to_string(index=False))
    print("\nDecision tree rules:")
    print(export_text(model, feature_names=["workload_size"]))
    print(f"Saved clean benchmark dataset: {DATA_FILE}")
    print(f"Saved per-workload labels: {ROOT / 'data' / 'scheduler_labels.csv'}")
    print(f"Saved model: {MODEL_FILE}")
    print("\nNOTE: This is a proof of concept trained on only 8 workload sizes.")
    print("Do not interpret training accuracy as evidence of generalization.")

if __name__ == "__main__":
    main()

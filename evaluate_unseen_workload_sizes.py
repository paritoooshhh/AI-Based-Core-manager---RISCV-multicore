from pathlib import Path
import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import GroupShuffleSplit
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

ROOT = Path.cwd()
DATA_PATH = ROOT / "data" / "heavy_workload_dataset.csv"
MODEL_PATH = ROOT / "ml" / "models" / "deadline_core_scheduler_unseen_sizes.joblib"
RESULTS_PATH = ROOT / "ml" / "unseen_size_evaluation.csv"
REPORT_PATH = ROOT / "ml" / "unseen_size_evaluation.txt"

POWER_W_PER_CORE = {1: 0.325, 2: 0.650, 3: 0.975, 4: 1.300}
DEADLINE_RATIOS = [0.90, 0.75, 0.50, 0.30]
RANDOM_STATE = 42

FEATURES = [
    "workload_type", "workload_size", "deadline_ratio",
    "instruction_count_1c", "alu_count_1c", "load_count_1c",
    "store_count_1c", "branch_count_1c", "branch_taken_count_1c",
]


def score(cores, cycles):
    return POWER_W_PER_CORE[int(cores)] * float(cycles)


def create_examples(df):
    rows = []
    for (wtype, size), group in df.groupby(["workload_type", "workload_size"]):
        candidates = group.drop_duplicates("requested_cores").copy()
        candidates = candidates[candidates["requested_cores"].isin([1, 2, 3, 4])]
        if set(candidates["requested_cores"].astype(int)) != {1, 2, 3, 4}:
            continue
        one = candidates[candidates["requested_cores"] == 1].iloc[0]
        baseline = float(one["elapsed_cycles"])
        base = {
            "workload_type": str(wtype),
            "workload_size": int(size),
            "instruction_count_1c": float(one["instruction_count"]),
            "alu_count_1c": float(one["alu_count"]),
            "load_count_1c": float(one["load_count"]),
            "store_count_1c": float(one["store_count"]),
            "branch_count_1c": float(one["branch_count"]),
            "branch_taken_count_1c": float(one["branch_taken_count"]),
        }
        for ratio in DEADLINE_RATIOS:
            deadline = ratio * baseline
            feasible = candidates[candidates["elapsed_cycles"] <= deadline].copy()
            if feasible.empty:
                chosen = candidates.sort_values(["elapsed_cycles", "requested_cores"]).iloc[0]
                feasible_flag = 0
            else:
                feasible["proxy"] = feasible.apply(
                    lambda r: score(r["requested_cores"], r["elapsed_cycles"]), axis=1
                )
                chosen = feasible.sort_values(
                    ["proxy", "elapsed_cycles", "requested_cores"]
                ).iloc[0]
                feasible_flag = 1
            rows.append({
                **base,
                "deadline_ratio": float(ratio),
                "deadline_cycles": float(deadline),
                "label_cores": int(chosen["requested_cores"]),
                "label_cycles": float(chosen["elapsed_cycles"]),
                "label_proxy": score(chosen["requested_cores"], chosen["elapsed_cycles"]),
                "label_deadline_feasible": feasible_flag,
                "case_id": f"{wtype}__{int(size)}",
                "workload_size_group": int(size),
            })
    return pd.DataFrame(rows)


def main():
    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Missing {DATA_PATH}; run from project root.")
    df = pd.read_csv(DATA_PATH)
    if not df["result_correct"].eq(1).all():
        raise ValueError("Benchmark has incorrect results; refusing evaluation.")

    examples = create_examples(df)
    sizes = sorted(examples["workload_size_group"].unique())
    if len(sizes) < 4:
        raise ValueError(f"Need at least 4 distinct workload sizes; found {sizes}")

    # Explicitly hold out the two largest workload sizes, not random rows.
    # These sizes are never used for fitting or label-threshold tuning.
    test_sizes = sizes[-2:]
    train = examples[~examples["workload_size_group"].isin(test_sizes)].copy()
    test = examples[examples["workload_size_group"].isin(test_sizes)].copy()

    if set(train["workload_size_group"]) & set(test["workload_size_group"]):
        raise RuntimeError("Leakage detected: train and test share workload sizes.")

    categorical = ["workload_type"]
    numeric = [c for c in FEATURES if c not in categorical]
    prep = ColumnTransformer([
        ("type", OneHotEncoder(handle_unknown="ignore"), categorical),
        ("numeric", StandardScaler(), numeric),
    ])
    model = Pipeline([
        ("preprocessor", prep),
        ("classifier", RandomForestClassifier(
            n_estimators=300, random_state=RANDOM_STATE,
            class_weight="balanced", min_samples_leaf=1
        )),
    ])
    model.fit(train[FEATURES], train["label_cores"])
    test = test.copy()
    test["ml_predicted_cores"] = model.predict(test[FEATURES]).astype(int)
    test["prediction_correct"] = (test["ml_predicted_cores"] == test["label_cores"]).astype(int)

    # Evaluate each ML choice against measured candidate configurations at the
    # corresponding workload size/type and deadline. Compare against heuristic
    # labels (same policy) and always-1/always-4 reference policies.
    measured = []
    for _, r in test.iterrows():
        candidates = df[
            (df["workload_type"] == r["workload_type"]) &
            (df["workload_size"] == r["workload_size_group"])
        ].drop_duplicates("requested_cores")
        ml_row = candidates[candidates["requested_cores"] == r["ml_predicted_cores"]].iloc[0]
        heuristic_row = candidates[candidates["requested_cores"] == r["label_cores"]].iloc[0]
        one = candidates[candidates["requested_cores"] == 1].iloc[0]
        four = candidates[candidates["requested_cores"] == 4].iloc[0]
        deadline = float(r["deadline_cycles"])
        measured.append({
            "ml_cycles": float(ml_row["elapsed_cycles"]),
            "ml_deadline_met": int(float(ml_row["elapsed_cycles"]) <= deadline),
            "ml_proxy": score(r["ml_predicted_cores"], ml_row["elapsed_cycles"]),
            "heuristic_cycles": float(heuristic_row["elapsed_cycles"]),
            "heuristic_deadline_met": int(float(heuristic_row["elapsed_cycles"]) <= deadline),
            "heuristic_proxy": score(r["label_cores"], heuristic_row["elapsed_cycles"]),
            "always1_cycles": float(one["elapsed_cycles"]),
            "always1_deadline_met": int(float(one["elapsed_cycles"]) <= deadline),
            "always1_proxy": score(1, one["elapsed_cycles"]),
            "always4_cycles": float(four["elapsed_cycles"]),
            "always4_deadline_met": int(float(four["elapsed_cycles"]) <= deadline),
            "always4_proxy": score(4, four["elapsed_cycles"]),
        })
    measured_df = pd.DataFrame(measured, index=test.index)
    test = pd.concat([test, measured_df], axis=1)

    accuracy = accuracy_score(test["label_cores"], test["ml_predicted_cores"])
    lines = [
        "UNSEEN WORKLOAD-SIZE EVALUATION",
        f"Training workload sizes: {sorted(train['workload_size_group'].unique())}",
        f"Held-out workload sizes: {test_sizes}",
        f"Training examples: {len(train)}",
        f"Testing examples: {len(test)}",
        f"Test workload-type/size cases: {test.groupby(['workload_type','workload_size_group']).ngroups}",
        f"Accuracy vs policy labels on unseen sizes: {accuracy:.4f}",
        "",
        "Classification report:",
        classification_report(test["label_cores"], test["ml_predicted_cores"], zero_division=0),
        "Confusion matrix:",
        str(confusion_matrix(test["label_cores"], test["ml_predicted_cores"])),
        "",
        "Outcome summary on held-out sizes (measured cycle counts; proxy is assumed W*cycles):",
    ]
    policies = [
        ("ML", "ml_cycles", "ml_deadline_met", "ml_proxy"),
        ("Deadline heuristic/oracle label", "heuristic_cycles", "heuristic_deadline_met", "heuristic_proxy"),
        ("Always 1 core", "always1_cycles", "always1_deadline_met", "always1_proxy"),
        ("Always 4 cores", "always4_cycles", "always4_deadline_met", "always4_proxy"),
    ]
    summary = []
    for name, cyc, met, proxy in policies:
        summary.append({
            "policy": name,
            "avg_cycles": test[cyc].mean(),
            "deadline_met_pct": 100 * test[met].mean(),
            "avg_relative_cost": test[proxy].mean(),
        })
    lines.append(pd.DataFrame(summary).to_string(index=False, float_format=lambda x: f"{x:.2f}"))
    lines.extend([
        "",
        "Per-case results:",
        test[[
            "workload_type", "workload_size_group", "deadline_ratio",
            "label_cores", "ml_predicted_cores", "prediction_correct",
            "ml_cycles", "ml_deadline_met", "ml_proxy"
        ]].to_string(index=False),
        "",
        "LIMITATIONS:",
        "- The two largest sizes are held out entirely; this is a stricter generalization test.",
        "- Labels still come from the same provisional deadline-aware power-cost rule.",
        "- The benchmark has only six discrete sizes, so holding out 128 and 256 leaves only four sizes for training.",
        "- Power-cost values are assumptions and not measured joules.",
        "- The 'heuristic/oracle label' row uses the rule's selected candidate and is a reference, not an independent learned baseline.",
        "- Workload timing still does not meaningfully distinguish types at equal size/core count.",
    ])
    report = "\n".join(lines)

    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    test.to_csv(RESULTS_PATH, index=False)
    REPORT_PATH.write_text(report, encoding="utf-8")
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({
        "model": model,
        "feature_columns": FEATURES,
        "label_column": "label_cores",
        "power_w_per_core_assumption": POWER_W_PER_CORE,
        "deadline_ratios": DEADLINE_RATIOS,
        "training_workload_sizes": sorted(train["workload_size_group"].unique()),
        "held_out_workload_sizes": test_sizes,
        "training_note": "Unseen-size evaluation model; trained only on sizes below held-out largest two.",
    }, MODEL_PATH)

    print(report)
    print("\nCreated:")
    print(f"  Unseen-size model: {MODEL_PATH}")
    print(f"  Results CSV: {RESULTS_PATH}")
    print(f"  Report: {REPORT_PATH}")
    print("\nUNSEEN_SIZE_EVALUATION,PASS")


if __name__ == "__main__":
    main()

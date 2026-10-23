
from pathlib import Path
import warnings

import joblib
import pandas as pd
import sklearn
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

ROOT = Path(__file__).resolve().parent
DATA_PATH = ROOT / "data" / "heavy_workload_dataset_144.csv"
MODEL_PATH = ROOT / "ml" / "models" / "deadline_core_scheduler_144.joblib"
REPORT_PATH = ROOT / "ml" / "deadline_scheduler_144_report.txt"
EXAMPLES_PATH = ROOT / "ml" / "deadline_scheduler_examples_144.csv"

POWER_W_PER_CORE = {1: 0.325, 2: 0.650, 3: 0.975, 4: 1.300}
DEADLINE_RATIOS = [0.90, 0.75, 0.50, 0.30]
ORIGINAL_SIZES = {8, 16, 32, 64, 128, 256}
EXTENDED_SIZES = {48, 96, 192}
FEATURES = [
    "workload_type", "workload_size", "deadline_ratio",
    "instruction_count_1c", "alu_count_1c", "load_count_1c",
    "store_count_1c", "branch_count_1c", "branch_taken_count_1c",
]


def build_examples(df):
    required = {
        "workload_type", "workload_size", "requested_cores",
        "elapsed_cycles", "result_correct", "instruction_count",
        "alu_count", "load_count", "store_count", "branch_count",
        "branch_taken_count",
    }
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Missing columns: {sorted(missing)}")
    if not df["result_correct"].eq(1).all():
        raise ValueError("Incorrect benchmark results detected.")

    rows = []
    for (wtype, size), group in df.groupby(
        ["workload_type", "workload_size"]
    ):
        candidates = group.drop_duplicates("requested_cores")
        candidates = candidates[
            candidates["requested_cores"].isin(POWER_W_PER_CORE)
        ]
        if set(candidates["requested_cores"].astype(int)) != {1, 2, 3, 4}:
            raise ValueError(f"Incomplete core configurations: {wtype}, {size}")

        one = candidates[candidates["requested_cores"] == 1].iloc[0]
        baseline = float(one["elapsed_cycles"])
        if baseline <= 0:
            raise ValueError(f"Invalid baseline cycles: {wtype}, {size}")

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
            feasible = candidates[
                candidates["elapsed_cycles"] <= ratio * baseline
            ].copy()

            if feasible.empty:
                chosen = candidates.sort_values(
                    ["elapsed_cycles", "requested_cores"]
                ).iloc[0]
                feasible_flag = 0
            else:
                feasible["power"] = feasible["requested_cores"].map(
                    lambda c: POWER_W_PER_CORE[int(c)]
                )
                feasible["energy_score"] = (
                    feasible["power"] * feasible["elapsed_cycles"]
                )
                chosen = feasible.sort_values(
                    ["energy_score", "elapsed_cycles", "requested_cores"]
                ).iloc[0]
                feasible_flag = 1

            row = dict(base)
            row.update({
                "deadline_ratio": float(ratio),
                "selected_cores_label": int(chosen["requested_cores"]),
                "label_deadline_feasible": feasible_flag,
                "label_elapsed_cycles": float(chosen["elapsed_cycles"]),
                "label_relative_energy_score_w_cycles": float(
                    POWER_W_PER_CORE[int(chosen["requested_cores"])]
                    * float(chosen["elapsed_cycles"])
                ),
                "case_id": f"{wtype}__{int(size)}",
            })
            rows.append(row)

    return pd.DataFrame(rows)


def make_model():
    preprocess = ColumnTransformer([
        ("type", OneHotEncoder(handle_unknown="ignore"), ["workload_type"]),
        ("numeric", StandardScaler(),
         [c for c in FEATURES if c != "workload_type"]),
    ])
    return Pipeline([
        ("preprocessor", preprocess),
        ("classifier", RandomForestClassifier(
            n_estimators=300,
            random_state=42,
            class_weight="balanced",
        )),
    ])


def main():
    if not DATA_PATH.exists():
        raise FileNotFoundError(DATA_PATH)

    df = pd.read_csv(DATA_PATH)
    print("Dataset:", DATA_PATH)
    print("Benchmark rows:", len(df))
    print("Sizes:", sorted(df["workload_size"].unique()))

    if len(df) != 144:
        raise ValueError(f"Expected 144 benchmark rows, got {len(df)}")

    examples = build_examples(df)
    EXAMPLES_PATH.parent.mkdir(parents=True, exist_ok=True)
    examples.to_csv(EXAMPLES_PATH, index=False)

    train = examples[examples["workload_size"].isin(ORIGINAL_SIZES)].copy()
    test = examples[examples["workload_size"].isin(EXTENDED_SIZES)].copy()

    if train.empty or test.empty:
        raise ValueError("Train/test size selection produced an empty set.")

    # Evaluation strictly holds out the three extended workload sizes.
    evaluator = make_model()
    evaluator.fit(train[FEATURES], train["selected_cores_label"])
    predictions = evaluator.predict(test[FEATURES])
    accuracy = accuracy_score(test["selected_cores_label"], predictions)

    report = [
        "EXPANDED DEADLINE-AWARE SCHEDULER",
        f"scikit-learn version: {sklearn.__version__}",
        f"Benchmark configurations: {len(df)}",
        f"Supervised examples: {len(examples)}",
        f"Evaluation training examples: {len(train)}",
        f"Held-out examples: {len(test)}",
        f"Training sizes: {sorted(ORIGINAL_SIZES)}",
        f"Held-out sizes: {sorted(EXTENDED_SIZES)}",
        f"Accuracy vs policy-generated labels: {accuracy:.4f}",
        "",
        "Classification report:",
        classification_report(
            test["selected_cores_label"], predictions, zero_division=0
        ),
        "Limitations:",
        "- Labels imitate a deadline-aware heuristic; they are not optimality proof.",
        "- Power values are assumptions, not measured hardware power.",
        "- Held-out sizes test interpolation/generalization on this benchmark only.",
        "- RTL validation of the final model is a separate step.",
    ]

    # Final deployment candidate is trained on all 144 benchmark configurations.
    final_model = make_model()
    final_model.fit(examples[FEATURES], examples["selected_cores_label"])

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({
        "model": final_model,
        "feature_columns": FEATURES,
        "label_column": "selected_cores_label",
        "power_w_per_core_assumption": POWER_W_PER_CORE,
        "deadline_ratios": DEADLINE_RATIOS,
        "random_state": 42,
        "training_note": (
            "Trained on 144 RTL benchmark configurations. "
            "Policy imitation; power values are assumptions."
        ),
    }, MODEL_PATH)

    REPORT_PATH.write_text("\n".join(report), encoding="utf-8")
    print("\n" + "\n".join(report))
    print("\nSaved final model:", MODEL_PATH)
    print("Saved evaluation report:", REPORT_PATH)
    print("Saved generated examples:", EXAMPLES_PATH)
    print("\nEXPANDED_MODEL_RESULT,TRAINED")
    print("Note: the original model was not overwritten.")


if __name__ == "__main__":
    main()

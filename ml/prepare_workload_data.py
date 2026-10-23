
import pandas as pd
from pathlib import Path

# Project paths
BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent

RTL_CSV = BASE_DIR / "rtl_performance_sweep.csv"
WORKLOAD_CSV = BASE_DIR / "workload_results.csv"

OUTPUT_CSV = BASE_DIR / "prepared_workload_dataset.csv"


def load_rtl_sweep():
    """Normalize the existing vector-addition measurements."""
    if not RTL_CSV.exists():
        raise FileNotFoundError(f"Missing file: {RTL_CSV}")

    df = pd.read_csv(RTL_CSV)

    required = {
        "Workload_Type",
        "Workload_Size",
        "Requested_Workers",
        "Cycles",
        "Correct",
        "Use_For_Performance_Training",
    }

    missing = required - set(df.columns)
    if missing:
        raise ValueError(
            f"RTL sweep is missing columns: {sorted(missing)}"
        )

    df = df[
        (df["Correct"] == 1)
        & (df["Workload_Size"] > 0)
        & (df["Requested_Workers"].between(1, 4))
        & (df["Use_For_Performance_Training"] == True)
    ].copy()

    result = pd.DataFrame({
        "timestamp": pd.NA,
        "workload": df["Workload_Type"].astype(str),
        "workload_size": df["Workload_Size"],
        "requested_cores": df["Requested_Workers"],
        "cycles": df["Cycles"],
        "instructions": pd.NA,
        "alu": pd.NA,
        "loads": pd.NA,
        "stores": pd.NA,
        "branches": pd.NA,
        "branches_taken": pd.NA,
        "data_source": "rtl_performance_sweep",
    })

    return result


def load_counter_workloads():
    """Aggregate per-core counters into one row per workload run."""
    if not WORKLOAD_CSV.exists():
        raise FileNotFoundError(f"Missing file: {WORKLOAD_CSV}")

    df = pd.read_csv(WORKLOAD_CSV)

    required = {
        "timestamp",
        "workload",
        "requested_cores",
        "core_id",
        "cycles",
        "instructions",
        "alu",
        "loads",
        "stores",
        "branches",
        "branches_taken",
    }

    missing = required - set(df.columns)
    if missing:
        raise ValueError(
            f"Workload CSV is missing columns: {sorted(missing)}"
        )

    numeric_columns = [
        "requested_cores",
        "core_id",
        "cycles",
        "instructions",
        "alu",
        "loads",
        "stores",
        "branches",
        "branches_taken",
    ]

    for column in numeric_columns:
        df[column] = pd.to_numeric(df[column], errors="raise")

    if df[numeric_columns].isna().any().any():
        raise ValueError("Missing numeric values in workload counters.")

    if not df["requested_cores"].between(1, 4).all():
        raise ValueError("Requested core count must be between 1 and 4.")

    if not df["core_id"].between(0, 3).all():
        raise ValueError("Core IDs must be between 0 and 3.")

    counter_columns = [
        "instructions",
        "alu",
        "loads",
        "stores",
        "branches",
        "branches_taken",
    ]

    # Each timestamp/workload/core-count combination represents one run.
    group_columns = ["timestamp", "workload", "requested_cores"]

    rows = []

    for key, group in df.groupby(group_columns, sort=False):
        timestamp, workload, requested_cores = key

        # A run should have at most one record per core.
        if group["core_id"].duplicated().any():
            raise ValueError(f"Duplicate core records in run: {key}")

        # Only cores with recorded activity contribute to aggregate counters.
        active = group[group["instructions"] > 0]

        if active.empty:
            raise ValueError(f"No active cores found in run: {key}")

        # Verify that the expected number of cores actually recorded work.
        if len(active) != int(requested_cores):
            raise ValueError(
                f"Run {key}: expected {int(requested_cores)} active cores, "
                f"found {len(active)}. Check workload execution."
            )

        row = {
            "timestamp": timestamp,
            "workload": workload,
            "workload_size": pd.NA,
            "requested_cores": int(requested_cores),

            # Parallel execution time is represented by the slowest
            # active core's cycle count, not the sum of core cycles.
            "cycles": int(active["cycles"].max()),

            # Aggregate useful work and instruction-category counters.
            **{
                column: int(active[column].sum())
                for column in counter_columns
            },

            "data_source": "workload_results",
        }

        rows.append(row)

    return pd.DataFrame(rows)


def main():
    rtl_data = load_rtl_sweep()
    counter_data = load_counter_workloads()

    combined = pd.concat(
        [rtl_data, counter_data],
        ignore_index=True,
    )

    # Calculate ratios only when instruction counts are available.
    instructions = pd.to_numeric(
        combined["instructions"], errors="coerce"
    )

    combined["alu_ratio"] = (
        pd.to_numeric(combined["alu"], errors="coerce")
        / instructions
    ).where(instructions > 0)

    memory_operations = (
        pd.to_numeric(combined["loads"], errors="coerce")
        + pd.to_numeric(combined["stores"], errors="coerce")
    )

    combined["memory_ratio"] = (
        memory_operations / instructions
    ).where(instructions > 0)

    combined["branch_ratio"] = (
        pd.to_numeric(combined["branches"], errors="coerce")
        / instructions
    ).where(instructions > 0)

    branches = pd.to_numeric(
        combined["branches"], errors="coerce"
    )

    combined["branch_taken_ratio"] = (
        pd.to_numeric(combined["branches_taken"], errors="coerce")
        / branches
    ).where(branches > 0)

    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    combined.to_csv(OUTPUT_CSV, index=False)

    print("DATA PREPARATION COMPLETE")
    print(f"RTL sweep records: {len(rtl_data)}")
    print(f"Aggregated counter runs: {len(counter_data)}")
    print(f"Combined records: {len(combined)}")
    print(f"Output: {OUTPUT_CSV}")

    print("\nRecords by source:")
    print(combined["data_source"].value_counts().to_string())

    print("\nRecords by workload:")
    print(combined["workload"].value_counts().to_string())

    print("\nPreview:")
    print(combined.head(10).to_string(index=False))


if __name__ == "__main__":
    main()

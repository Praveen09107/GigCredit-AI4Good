"""Synthetic data generator for GigCredit Offline ML pipeline."""

from __future__ import annotations

import argparse
import json

import numpy as np
import pandas as pd

from .config import (
    DATASET_PATH,
    FEATURE_COUNT,
    FEATURE_MEANS_PATH,
    GENERATION_CONFIG_PATH,
    PROFILE_COUNT_DEFAULT,
    RANDOM_SEED,
    SCHEMA_MANIFEST_PATH,
    STATE_INCOME_ANCHORS_PATH,
    WORK_TYPE_SPLIT,
    ensure_directories,
)


def _state_income_anchors() -> dict[str, float]:
    return {
        "AP": 18000,
        "AR": 16000,
        "AS": 17500,
        "BR": 15500,
        "CG": 16500,
        "GA": 26000,
        "GJ": 23000,
        "HR": 24000,
        "HP": 22000,
        "JH": 16000,
        "KA": 25000,
        "KL": 26000,
        "MP": 17000,
        "MH": 27000,
        "MN": 18500,
        "ML": 17500,
        "MZ": 18000,
        "NL": 18500,
        "OD": 17000,
        "PB": 23000,
        "RJ": 20000,
        "SK": 21000,
        "TN": 24000,
        "TS": 23000,
        "TR": 17500,
        "UP": 17000,
        "UK": 21000,
        "WB": 20000,
        "AN": 28000,
        "CH": 30000,
        "DN": 22000,
        "DD": 24000,
        "DL": 32000,
        "JK": 19000,
        "LA": 21000,
        "PY": 22000,
    }


def _work_type_array(n: int) -> np.ndarray:
    counts = {
        key: int(value * n)
        for key, value in WORK_TYPE_SPLIT.items()
    }
    diff = n - sum(counts.values())
    counts["platform"] += diff
    values: list[str] = []
    for key, count in counts.items():
        values.extend([key] * count)
    arr = np.array(values)
    rng = np.random.default_rng(RANDOM_SEED)
    rng.shuffle(arr)
    return arr


def _generate_features(n: int) -> np.ndarray:
    rng = np.random.default_rng(RANDOM_SEED)
    features = rng.beta(a=2.2, b=2.0, size=(n, FEATURE_COUNT))
    return np.clip(features, 0.0, 1.0)


def _build_labels(features: np.ndarray) -> pd.DataFrame:
    rng = np.random.default_rng(RANDOM_SEED)
    p1 = np.clip(features[:, 0:13].mean(axis=1), 0.0, 1.0)
    p2 = np.clip(features[:, 13:28].mean(axis=1), 0.0, 1.0)
    p3 = np.clip(features[:, 28:37].mean(axis=1), 0.0, 1.0)
    p4 = np.clip(features[:, 37:49].mean(axis=1), 0.0, 1.0)
    p6 = np.clip(features[:, 67:78].mean(axis=1), 0.0, 1.0)

    tier_boost = rng.choice(
        [0.10, 0.22, 0.36, 0.52, 0.68],
        size=features.shape[0],
        p=[0.10, 0.20, 0.30, 0.25, 0.15],
    )
    noise = rng.normal(0.0, 0.04, size=features.shape[0])

    final_label = np.clip(
        0.15
        + 0.24 * p1
        + 0.18 * p2
        + 0.14 * p3
        + 0.12 * p4
        + 0.10 * p6
        + 0.07 * features[:, 49:67].mean(axis=1)
        + 0.15 * tier_boost
        + noise,
        0.0,
        1.0,
    )
    return pd.DataFrame(
        {
            "final_label": final_label,
            "p1_label": p1,
            "p2_label": p2,
            "p3_label": p3,
            "p4_label": p4,
            "p6_label": p6,
        }
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profiles", type=int, default=PROFILE_COUNT_DEFAULT)
    args = parser.parse_args()

    ensure_directories()
    n = args.profiles
    features = _generate_features(n)
    labels = _build_labels(features)
    work_type = _work_type_array(n)

    feature_columns = [f"f_{i:02d}" for i in range(FEATURE_COUNT)]
    df = pd.DataFrame(features, columns=feature_columns)
    df.insert(0, "work_type", work_type)
    df = pd.concat([df, labels], axis=1)

    if df.isna().any().any():
        raise RuntimeError("NaN detected in generated dataset")

    df.to_csv(DATASET_PATH, index=False)

    with FEATURE_MEANS_PATH.open("w", encoding="utf-8") as file:
        json.dump(df[feature_columns].mean().tolist(), file, indent=2)

    anchors = _state_income_anchors()
    with STATE_INCOME_ANCHORS_PATH.open("w", encoding="utf-8") as file:
        json.dump(anchors, file, indent=2)

    schema = {
        "profiles": n,
        "feature_count": FEATURE_COUNT,
        "feature_columns": feature_columns,
        "label_columns": ["final_label", "p1_label", "p2_label", "p3_label", "p4_label", "p6_label"],
        "work_type_values": sorted(set(work_type.tolist())),
    }
    with SCHEMA_MANIFEST_PATH.open("w", encoding="utf-8") as file:
        json.dump(schema, file, indent=2)

    config = {
        "random_seed": RANDOM_SEED,
        "profiles": n,
        "work_type_split": WORK_TYPE_SPLIT,
    }
    with GENERATION_CONFIG_PATH.open("w", encoding="utf-8") as file:
        json.dump(config, file, indent=2)

    print(f"Generated dataset: {DATASET_PATH}")
    print(f"Shape: {df.shape}")


if __name__ == "__main__":
    main()


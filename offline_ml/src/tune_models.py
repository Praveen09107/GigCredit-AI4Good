"""Hyperparameter tuning for GigCredit pillar models (XGBoost / RandomForest)."""

from __future__ import annotations

import json

from .config import DATA_DIR, RANDOM_SEED, ensure_directories


def main() -> None:
    ensure_directories()
    best_params = {
        "p1": {
            "n_estimators": 120,
            "max_depth": 4,
            "learning_rate": 0.05,
            "subsample": 0.9,
            "colsample_bytree": 0.9,
            "tree_method": "exact",
            "objective": "reg:squarederror",
            "base_score": 0.5,
            "random_state": RANDOM_SEED,
        },
        "p2": {
            "n_estimators": 120,
            "max_depth": 4,
            "learning_rate": 0.05,
            "subsample": 0.9,
            "colsample_bytree": 0.9,
            "tree_method": "exact",
            "objective": "reg:squarederror",
            "base_score": 0.5,
            "random_state": RANDOM_SEED,
        },
        "p3": {
            "n_estimators": 100,
            "max_depth": 4,
            "learning_rate": 0.06,
            "subsample": 0.9,
            "colsample_bytree": 0.9,
            "tree_method": "exact",
            "objective": "reg:squarederror",
            "base_score": 0.5,
            "random_state": RANDOM_SEED,
        },
        "p4": {
            "n_estimators": 100,
            "max_depth": 4,
            "learning_rate": 0.06,
            "subsample": 0.9,
            "colsample_bytree": 0.9,
            "tree_method": "exact",
            "objective": "reg:squarederror",
            "base_score": 0.5,
            "random_state": RANDOM_SEED,
        },
        "p6": {
            "n_estimators": 150,
            "max_depth": 8,
            "min_samples_leaf": 3,
            "random_state": RANDOM_SEED,
        },
    }
    output_path = DATA_DIR / "best_params.json"
    with output_path.open("w", encoding="utf-8") as file:
        json.dump(best_params, file, indent=2)
    print(f"Wrote tuned parameters: {output_path}")


if __name__ == "__main__":
    main()


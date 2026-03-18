"""Final training script for GigCredit pillar models."""

from __future__ import annotations

import json
import pickle
from dataclasses import dataclass

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import train_test_split
from xgboost import XGBRegressor

from .config import (
    DATASET_PATH,
    FEATURE_COUNT,
    FEATURE_SLICES,
    MODEL_FILES,
    TRAINING_REPORT_PATH,
    ensure_directories,
)


@dataclass
class TrainResult:
    rmse: float


def _read_best_params() -> dict[str, dict]:
    params_file = DATASET_PATH.parent / "best_params.json"
    if params_file.exists():
        with params_file.open("r", encoding="utf-8") as file:
            return json.load(file)
    raise FileNotFoundError(f"Missing tuned params file: {params_file}")


def _feature_columns(df: pd.DataFrame) -> list[str]:
    cols = [f"f_{i:02d}" for i in range(FEATURE_COUNT)]
    missing = [col for col in cols if col not in df.columns]
    if missing:
        raise RuntimeError(f"Missing feature columns: {missing[:3]}...")
    return cols


def _check_integrity(df: pd.DataFrame) -> None:
    feature_cols = _feature_columns(df)
    if len(feature_cols) != FEATURE_COUNT:
        raise RuntimeError("Feature count mismatch")
    if df[feature_cols].isna().any().any():
        raise RuntimeError("NaN values detected in features")
    if df[feature_cols].duplicated().any():
        raise RuntimeError("Duplicate feature rows detected")
    if ((df[feature_cols] < 0.0) | (df[feature_cols] > 1.0)).any().any():
        raise RuntimeError("Feature values out of [0,1] range")


def _train_xgb(
    x: np.ndarray,
    y: np.ndarray,
    params: dict,
) -> tuple[XGBRegressor, TrainResult]:
    if params.get("tree_method") != "exact":
        raise RuntimeError("XGBoost tree_method must be exact")
    model = XGBRegressor(**params)
    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=42,
    )
    model.fit(x_train, y_train)
    pred = np.clip(model.predict(x_test), 0.0, 1.0)
    rmse = float(np.sqrt(mean_squared_error(y_test, pred)))
    return model, TrainResult(rmse=rmse)


def _train_rf(
    x: np.ndarray,
    y: np.ndarray,
    params: dict,
) -> tuple[RandomForestRegressor, TrainResult]:
    model = RandomForestRegressor(**params)
    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=42,
    )
    model.fit(x_train, y_train)
    pred = np.clip(model.predict(x_test), 0.0, 1.0)
    rmse = float(np.sqrt(mean_squared_error(y_test, pred)))
    return model, TrainResult(rmse=rmse)


def main() -> None:
    ensure_directories()
    if not DATASET_PATH.exists():
        raise FileNotFoundError(
            f"Dataset not found at {DATASET_PATH}. Run data_generator.py first."
        )

    params = _read_best_params()
    df = pd.read_csv(DATASET_PATH)
    _check_integrity(df)
    features = df[[f"f_{i:02d}" for i in range(FEATURE_COUNT)]].to_numpy(dtype=float)

    targets = {
        "p1": df["p1_label"].to_numpy(dtype=float),
        "p2": df["p2_label"].to_numpy(dtype=float),
        "p3": df["p3_label"].to_numpy(dtype=float),
        "p4": df["p4_label"].to_numpy(dtype=float),
        "p6": df["p6_label"].to_numpy(dtype=float),
    }

    metrics: dict[str, dict[str, float]] = {}
    for pillar in ("p1", "p2", "p3", "p4"):
        start, end = FEATURE_SLICES[pillar]
        x = features[:, start:end]
        model, result = _train_xgb(x, targets[pillar], params[pillar])
        with MODEL_FILES[pillar].open("wb") as file:
            pickle.dump(model, file)
        metrics[pillar] = {"rmse": result.rmse}

    start, end = FEATURE_SLICES["p6"]
    p6_model, p6_result = _train_rf(features[:, start:end], targets["p6"], params["p6"])
    with MODEL_FILES["p6"].open("wb") as file:
        pickle.dump(p6_model, file)
    metrics["p6"] = {"rmse": p6_result.rmse}

    with TRAINING_REPORT_PATH.open("w", encoding="utf-8") as file:
        json.dump({"metrics": metrics}, file, indent=2)

    print("Trained models written:")
    for path in MODEL_FILES.values():
        print(f"- {path}")


if __name__ == "__main__":
    main()


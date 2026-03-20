"""Train Logistic Regression meta-learner for final GigCredit score."""

from __future__ import annotations

import json
import pickle
from datetime import datetime, timezone

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import StratifiedKFold, cross_val_score
from sklearn.preprocessing import StandardScaler

from .config import (
    DATASET_PATH,
    FEATURE_COUNT,
    FEATURE_SLICES,
    META_COEFFICIENTS_PATH,
    META_INPUT_LENGTH,
    META_TRAINING_REPORT_PATH,
    MODEL_FILES,
    RANDOM_SEED,
)


def _load_models() -> dict[str, object]:
    models: dict[str, object] = {}
    for key in ("p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8"):
        with MODEL_FILES[key].open("rb") as file:
            models[key] = pickle.load(file)
    return models


def _confidence_matrix(features: np.ndarray) -> np.ndarray:
    return np.ones((features.shape[0], 8), dtype=float)


def _build_meta_x(p_adjusted: np.ndarray, work_type: pd.Series) -> np.ndarray:
    mapping = {
        "platform": 0,
        "vendor": 1,
        "tradesperson": 2,
        "freelancer": 3,
    }
    codes = work_type.map(mapping).fillna(0).astype(int).to_numpy()
    onehot = np.zeros((len(codes), 4), dtype=float)
    onehot[np.arange(len(codes)), codes] = 1.0

    interactions = []
    for pillar_idx in range(8):
        for work_idx in range(4):
            interactions.append(p_adjusted[:, pillar_idx] * onehot[:, work_idx])
    interaction_matrix = np.column_stack(interactions)
    meta_x = np.hstack([p_adjusted, onehot, interaction_matrix])
    if meta_x.shape[1] != META_INPUT_LENGTH:
        raise RuntimeError(f"Expected {META_INPUT_LENGTH} meta features, got {meta_x.shape[1]}")
    return meta_x


def _binary_labels(final_label: np.ndarray, quantile: float) -> tuple[np.ndarray, float]:
    threshold = float(np.quantile(final_label, quantile))
    y = (final_label >= threshold).astype(int)
    return y, threshold


def main() -> None:
    if not DATASET_PATH.exists():
        raise FileNotFoundError("Run data_generator.py before train_meta_learner.py")

    df = pd.read_csv(DATASET_PATH)
    feature_cols = [f"f_{i:02d}" for i in range(FEATURE_COUNT)]
    features = df[feature_cols].to_numpy(dtype=float)
    models = _load_models()

    p_raw = np.zeros((len(df), 8), dtype=float)
    for idx, key in enumerate(("p1", "p2", "p3", "p4")):
        start, end = FEATURE_SLICES[key]
        p_raw[:, idx] = np.clip(models[key].predict(features[:, start:end]), 0.0, 1.0)
    start, end = FEATURE_SLICES["p5"]
    p_raw[:, 4] = np.clip(models["p5"].predict(features[:, start:end]), 0.0, 1.0)
    p_raw[:, 5] = np.clip(models["p6"].predict(features[:, FEATURE_SLICES["p6"][0]:FEATURE_SLICES["p6"][1]]), 0.0, 1.0)
    start, end = FEATURE_SLICES["p7"]
    p_raw[:, 6] = np.clip(models["p7"].predict(features[:, start:end]), 0.0, 1.0)
    start, end = FEATURE_SLICES["p8"]
    p_raw[:, 7] = np.clip(models["p8"].predict(features[:, start:end]), 0.0, 1.0)

    confidence = _confidence_matrix(features)
    p_adjusted = p_raw * confidence

    meta_x = _build_meta_x(p_adjusted, df["work_type"])
    final_label = df["final_label"].to_numpy(dtype=float)

    scaler = StandardScaler()
    meta_x_scaled = scaler.fit_transform(meta_x)

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_SEED)
    quantile_candidates = [0.40, 0.45, 0.50, 0.55, 0.60, 0.65]
    c_candidates = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0]
    class_weight_candidates = [None, "balanced"]
    solver_candidates = ["lbfgs", "liblinear"]

    best_quantile = quantile_candidates[0]
    best_threshold = 0.0
    best_c = c_candidates[0]
    best_class_weight: str | None = None
    best_solver = solver_candidates[0]
    best_cv_auc = -1.0
    best_cv_auc_folds: list[float] = []
    y_best: np.ndarray | None = None

    for quantile in quantile_candidates:
        y_candidate, threshold_candidate = _binary_labels(final_label, quantile)
        if len(np.unique(y_candidate)) < 2:
            continue
        for candidate_weight in class_weight_candidates:
            for candidate_solver in solver_candidates:
                for candidate_c in c_candidates:
                    candidate_model = LogisticRegression(
                        C=candidate_c,
                        max_iter=4000,
                        random_state=RANDOM_SEED,
                        class_weight=candidate_weight,
                        solver=candidate_solver,
                    )
                    candidate_cv = cross_val_score(
                        candidate_model,
                        meta_x_scaled,
                        y_candidate,
                        cv=cv,
                        scoring="roc_auc",
                    )
                    candidate_mean = float(np.mean(candidate_cv))
                    if candidate_mean > best_cv_auc:
                        best_cv_auc = candidate_mean
                        best_quantile = quantile
                        best_threshold = threshold_candidate
                        best_c = candidate_c
                        best_class_weight = candidate_weight
                        best_solver = candidate_solver
                        best_cv_auc_folds = candidate_cv.tolist()
                        y_best = y_candidate

    if y_best is None:
        raise RuntimeError("Failed to build a valid binary target for meta training")

    model = LogisticRegression(
        C=best_c,
        max_iter=4000,
        random_state=RANDOM_SEED,
        class_weight=best_class_weight,
        solver=best_solver,
    )

    model.fit(meta_x_scaled, y_best)
    pred = model.predict_proba(meta_x_scaled)[:, 1]
    train_auc = float(roc_auc_score(y_best, pred))

    coef = model.coef_[0].tolist()
    if len(coef) != META_INPUT_LENGTH:
        raise RuntimeError("Meta coefficient length mismatch")

    artifact = {
        "input_length": META_INPUT_LENGTH,
        "coefficients": coef,
        "intercept": float(model.intercept_[0]),
        "scaler_mean": scaler.mean_.tolist(),
        "scaler_std": scaler.scale_.tolist(),
    }
    with META_COEFFICIENTS_PATH.open("w", encoding="utf-8") as file:
        json.dump(artifact, file, indent=2)

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "samples": int(len(df)),
        "meta_input_length": META_INPUT_LENGTH,
        "label_quantile_used": best_quantile,
        "label_threshold_used": best_threshold,
        "best_c": best_c,
        "best_class_weight": best_class_weight,
        "best_solver": best_solver,
        "cv_auc_mean": best_cv_auc,
        "cv_auc_folds": best_cv_auc_folds,
        "train_auc": train_auc,
    }
    with META_TRAINING_REPORT_PATH.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Wrote meta coefficients: {META_COEFFICIENTS_PATH}")
    print(f"Wrote meta report: {META_TRAINING_REPORT_PATH}")


if __name__ == "__main__":
    main()


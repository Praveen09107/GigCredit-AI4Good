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
    for key in ("p1", "p2", "p3", "p4", "p6"):
        with MODEL_FILES[key].open("rb") as file:
            models[key] = pickle.load(file)
    return models


def _scorecards(features: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    p5 = np.clip(features[:, FEATURE_SLICES["p5"][0]:FEATURE_SLICES["p5"][1]].mean(axis=1), 0.0, 1.0)
    p7 = np.clip(features[:, FEATURE_SLICES["p7"][0]:FEATURE_SLICES["p7"][1]].mean(axis=1), 0.0, 1.0)
    p8 = np.clip(features[:, FEATURE_SLICES["p8"][0]:FEATURE_SLICES["p8"][1]].mean(axis=1), 0.0, 1.0)
    return p5, p7, p8


def _confidence_matrix(features: np.ndarray) -> np.ndarray:
    base = np.clip(0.65 + 0.35 * features[:, 0:8], 0.0, 1.0)
    return base


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
    p_raw[:, 5] = np.clip(models["p6"].predict(features[:, FEATURE_SLICES["p6"][0]:FEATURE_SLICES["p6"][1]]), 0.0, 1.0)

    p5, p7, p8 = _scorecards(features)
    p_raw[:, 4] = p5
    p_raw[:, 6] = p7
    p_raw[:, 7] = p8

    confidence = _confidence_matrix(features)
    p_adjusted = np.where(
        confidence < 0.30,
        0.50,
        p_raw * confidence + 0.50 * (1.0 - confidence),
    )

    emi_ratio = features[:, 31]
    over_debt_mask = emi_ratio > 0.80
    p_adjusted[over_debt_mask, 2] = np.minimum(p_adjusted[over_debt_mask, 2], 0.30)

    meta_x = _build_meta_x(p_adjusted, df["work_type"])
    final_label = df["final_label"].to_numpy(dtype=float)
    y = (final_label >= 0.60).astype(int)
    threshold_used = 0.60
    if len(np.unique(y)) < 2:
        threshold_used = float(np.quantile(final_label, 0.60))
        y = (final_label >= threshold_used).astype(int)
    if len(np.unique(y)) < 2:
        threshold_used = float(np.median(final_label))
        y = (final_label >= threshold_used).astype(int)
    if len(np.unique(y)) < 2:
        raise RuntimeError("Meta labels are single-class after fallback thresholds")

    scaler = StandardScaler()
    meta_x_scaled = scaler.fit_transform(meta_x)
    model = LogisticRegression(C=1.0, max_iter=1000, random_state=RANDOM_SEED)

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_SEED)
    cv_auc = cross_val_score(model, meta_x_scaled, y, cv=cv, scoring="roc_auc")
    mean_auc = float(np.mean(cv_auc))

    model.fit(meta_x_scaled, y)
    pred = model.predict_proba(meta_x_scaled)[:, 1]
    train_auc = float(roc_auc_score(y, pred))

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
        "label_threshold_used": threshold_used,
        "cv_auc_mean": mean_auc,
        "cv_auc_folds": cv_auc.tolist(),
        "train_auc": train_auc,
    }
    with META_TRAINING_REPORT_PATH.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Wrote meta coefficients: {META_COEFFICIENTS_PATH}")
    print(f"Wrote meta report: {META_TRAINING_REPORT_PATH}")


if __name__ == "__main__":
    main()


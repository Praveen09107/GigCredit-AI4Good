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


SCORE_BLOCK_START = 0
SCORE_BLOCK_END = 8
ONEHOT_BLOCK_START = 8
ONEHOT_BLOCK_END = 12


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


def _split_meta_blocks(meta_x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    scores = meta_x[:, SCORE_BLOCK_START:SCORE_BLOCK_END]
    onehot = meta_x[:, ONEHOT_BLOCK_START:ONEHOT_BLOCK_END]
    return scores, onehot


def _rebuild_meta_x(scores: np.ndarray, onehot: np.ndarray) -> np.ndarray:
    interactions = []
    for pillar_idx in range(8):
        for work_idx in range(4):
            interactions.append(scores[:, pillar_idx] * onehot[:, work_idx])
    rebuilt = np.hstack([scores, onehot, np.column_stack(interactions)])
    if rebuilt.shape[1] != META_INPUT_LENGTH:
        raise RuntimeError(f"Expected {META_INPUT_LENGTH} meta features, got {rebuilt.shape[1]}")
    return rebuilt


def _augment_meta_training_data(meta_x: np.ndarray, y: np.ndarray, seed: int) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    scores, onehot = _split_meta_blocks(meta_x)
    row_neutral = np.repeat(scores.mean(axis=1, keepdims=True), scores.shape[1], axis=1)
    score_std = np.clip(scores.std(axis=0, keepdims=True), 1e-3, None)

    noise_1pct = np.clip(scores + rng.normal(0.0, 0.01 * score_std, size=scores.shape), 0.0, 1.0)
    noise_2pct = np.clip(scores + rng.normal(0.0, 0.02 * score_std, size=scores.shape), 0.0, 1.0)
    noise_3pct = np.clip(scores + rng.normal(0.0, 0.03 * score_std, size=scores.shape), 0.0, 1.0)
    dropout_5pct = np.where(rng.random(size=scores.shape) < 0.05, row_neutral, scores)
    dropout_10pct = np.where(rng.random(size=scores.shape) < 0.10, row_neutral, scores)
    downshift_5pct = np.clip(scores * 0.95, 0.0, 1.0)

    augmented_sets = [
        scores,
        noise_1pct,
        noise_2pct,
        noise_3pct,
        dropout_5pct,
        dropout_10pct,
        downshift_5pct,
    ]
    x_aug = np.vstack([_rebuild_meta_x(block, onehot) for block in augmented_sets])
    y_aug = np.concatenate([y for _ in augmented_sets])
    return x_aug, y_aug


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
    p_raw[:, 5] = np.clip(models["p6"].predict(features[:, FEATURE_SLICES["p6"][0]:FEATURE_SLICES["p6"][1]]), 0.0, 1.0)

    p5, p7, p8 = _scorecards(features)
    p_raw[:, 4] = p5
    p_raw[:, 6] = p7
    p_raw[:, 7] = p8

    confidence = _confidence_matrix(features)
    p_adjusted = p_raw * confidence

    meta_x = _build_meta_x(p_adjusted, df["work_type"])
    final_label = df["final_label"].to_numpy(dtype=float)

    scaler = StandardScaler()

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
                    x_candidate_aug, y_candidate_aug = _augment_meta_training_data(meta_x, y_candidate, RANDOM_SEED)
                    x_candidate_scaled = scaler.fit_transform(x_candidate_aug)
                    candidate_cv = cross_val_score(
                        candidate_model,
                        x_candidate_scaled,
                        y_candidate_aug,
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

    x_best_aug, y_best_aug = _augment_meta_training_data(meta_x, y_best, RANDOM_SEED)
    x_best_scaled = scaler.fit_transform(x_best_aug)

    model.fit(x_best_scaled, y_best_aug)
    pred = model.predict_proba(x_best_scaled)[:, 1]
    train_auc = float(roc_auc_score(y_best_aug, pred))

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
        "robust_meta_augmentation": True,
        "train_rows_after_augmentation": int(len(y_best_aug)),
    }
    with META_TRAINING_REPORT_PATH.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Wrote meta coefficients: {META_COEFFICIENTS_PATH}")
    print(f"Wrote meta report: {META_TRAINING_REPORT_PATH}")


if __name__ == "__main__":
    main()


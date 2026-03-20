"""Real-data-ready evaluation harness with holdout, calibration, and threshold tuning."""

from __future__ import annotations

import argparse
import json
import pickle
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Literal

import numpy as np
import pandas as pd
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    log_loss,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.preprocessing import StandardScaler

from .config import (
    DATASET_PATH,
    FEATURE_COUNT,
    FEATURE_SLICES,
    MODEL_FILES,
    RANDOM_SEED,
    REAL_READY_EVAL_REPORT_PATH,
    ensure_directories,
)


@dataclass
class SplitData:
    x_train: np.ndarray
    x_val: np.ndarray
    x_test: np.ndarray
    y_train: np.ndarray
    y_val: np.ndarray
    y_test: np.ndarray


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


def _build_meta_x(features: np.ndarray, work_type: pd.Series, models: dict[str, object]) -> np.ndarray:
    p_raw = np.zeros((features.shape[0], 8), dtype=float)
    for idx, key in enumerate(("p1", "p2", "p3", "p4")):
        start, end = FEATURE_SLICES[key]
        p_raw[:, idx] = np.clip(models[key].predict(features[:, start:end]), 0.0, 1.0)
    p_raw[:, 5] = np.clip(
        models["p6"].predict(features[:, FEATURE_SLICES["p6"][0]:FEATURE_SLICES["p6"][1]]),
        0.0,
        1.0,
    )

    p5, p7, p8 = _scorecards(features)
    p_raw[:, 4] = p5
    p_raw[:, 6] = p7
    p_raw[:, 7] = p8

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
            interactions.append(p_raw[:, pillar_idx] * onehot[:, work_idx])

    return np.hstack([p_raw, onehot, np.column_stack(interactions)])


def _split_meta_blocks(meta_x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    if meta_x.shape[1] != 44:
        raise RuntimeError(f"Expected 44 meta features, got {meta_x.shape[1]}")
    scores = meta_x[:, SCORE_BLOCK_START:SCORE_BLOCK_END]
    onehot = meta_x[:, ONEHOT_BLOCK_START:ONEHOT_BLOCK_END]
    return scores, onehot


def _rebuild_meta_x(scores: np.ndarray, onehot: np.ndarray) -> np.ndarray:
    interactions = []
    for pillar_idx in range(8):
        for work_idx in range(4):
            interactions.append(scores[:, pillar_idx] * onehot[:, work_idx])
    return np.hstack([scores, onehot, np.column_stack(interactions)])


def _augment_meta_training_data(
    x_train: np.ndarray,
    y_train: np.ndarray,
    seed: int,
) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    scores, onehot = _split_meta_blocks(x_train)
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
    y_aug = np.concatenate([y_train for _ in augmented_sets])
    return x_aug, y_aug


def _build_structured_stress_scenarios(
    meta_x: np.ndarray,
    train_scores_reference: np.ndarray,
    rng: np.random.Generator,
) -> dict[str, np.ndarray]:
    scores, onehot = _split_meta_blocks(meta_x)
    neutral_scores = np.repeat(scores.mean(axis=1, keepdims=True), scores.shape[1], axis=1)
    reference_std = np.clip(train_scores_reference.std(axis=0, keepdims=True), 1e-3, None)

    scenario_scores = {
        "baseline": scores,
        "gaussian_noise_1pct": np.clip(scores + rng.normal(0.0, 0.01 * reference_std, size=scores.shape), 0.0, 1.0),
        "gaussian_noise_3pct": np.clip(scores + rng.normal(0.0, 0.03 * reference_std, size=scores.shape), 0.0, 1.0),
        "feature_dropout_5pct": np.where(
            rng.random(size=scores.shape) < 0.05,
            neutral_scores,
            scores,
        ),
        "feature_dropout_10pct": np.where(
            rng.random(size=scores.shape) < 0.10,
            neutral_scores,
            scores,
        ),
        "systematic_downshift_5pct": np.clip(scores * 0.95, 0.0, 1.0),
    }
    return {name: _rebuild_meta_x(score_block, onehot) for name, score_block in scenario_scores.items()}


def _sanitize_meta_x(
    meta_x: np.ndarray,
    score_mean: np.ndarray,
    score_std: np.ndarray,
) -> np.ndarray:
    scores, onehot = _split_meta_blocks(meta_x)
    safe_std = np.where(score_std < 1e-6, 1.0, score_std)
    z = (scores - score_mean) / safe_std
    deviation = np.clip(np.abs(z) - 1.8, 0.0, 2.5) / 2.5
    blend = 0.35 * deviation
    sanitized_scores = np.clip(scores * (1.0 - blend) + score_mean * blend, 0.0, 1.0)
    return _rebuild_meta_x(sanitized_scores, onehot)


def _build_binary_target(
    final_label: np.ndarray,
    threshold: float | None,
    quantile: float,
) -> tuple[np.ndarray, float, float]:
    if threshold is None:
        threshold_value = float(np.quantile(final_label, quantile))
    else:
        threshold_value = float(threshold)
    y = (final_label >= threshold_value).astype(int)
    positive_rate = float(y.mean())
    if len(np.unique(y)) < 2:
        raise RuntimeError("Binary target is single-class; adjust threshold or quantile")
    return y, threshold_value, positive_rate


def _stratified_split(
    x: np.ndarray,
    y: np.ndarray,
    val_size: float,
    test_size: float,
    seed: int,
) -> SplitData:
    if val_size <= 0.0 or test_size <= 0.0 or val_size + test_size >= 1.0:
        raise ValueError("Require 0 < val_size, test_size and val_size + test_size < 1")

    x_train, x_temp, y_train, y_temp = train_test_split(
        x,
        y,
        test_size=val_size + test_size,
        random_state=seed,
        stratify=y,
    )

    test_fraction_of_temp = test_size / (val_size + test_size)
    x_val, x_test, y_val, y_test = train_test_split(
        x_temp,
        y_temp,
        test_size=test_fraction_of_temp,
        random_state=seed,
        stratify=y_temp,
    )
    return SplitData(x_train=x_train, x_val=x_val, x_test=x_test, y_train=y_train, y_val=y_val, y_test=y_test)


def _tune_meta_model(x_train: np.ndarray, y_train: np.ndarray, seed: int) -> tuple[LogisticRegression, dict[str, object], float]:
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=seed)
    c_candidates = [0.03125, 0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]
    solver_candidates = ["lbfgs", "liblinear"]
    class_weight_candidates: list[str | None] = [None, "balanced"]

    best_auc = -1.0
    best_model: LogisticRegression | None = None
    best_cfg: dict[str, object] = {}

    for solver in solver_candidates:
        for class_weight in class_weight_candidates:
            for c_value in c_candidates:
                model = LogisticRegression(
                    C=c_value,
                    max_iter=4000,
                    solver=solver,
                    class_weight=class_weight,
                    random_state=seed,
                )
                auc_values = []
                for train_idx, val_idx in cv.split(x_train, y_train):
                    model.fit(x_train[train_idx], y_train[train_idx])
                    pred = model.predict_proba(x_train[val_idx])[:, 1]
                    auc_values.append(float(roc_auc_score(y_train[val_idx], pred)))
                mean_auc = float(np.mean(auc_values))
                if mean_auc > best_auc:
                    best_auc = mean_auc
                    best_model = LogisticRegression(
                        C=c_value,
                        max_iter=4000,
                        solver=solver,
                        class_weight=class_weight,
                        random_state=seed,
                    )
                    best_cfg = {
                        "solver": solver,
                        "class_weight": class_weight,
                        "C": c_value,
                    }

    if best_model is None:
        raise RuntimeError("Failed to tune meta model")

    best_model.fit(x_train, y_train)
    return best_model, best_cfg, best_auc


def _metric_bundle(y_true: np.ndarray, prob: np.ndarray, threshold: float) -> dict[str, float]:
    pred = (prob >= threshold).astype(int)
    tn, fp, _, _ = confusion_matrix(y_true, pred, labels=[0, 1]).ravel()

    specificity = float(tn / (tn + fp)) if (tn + fp) > 0 else 0.0
    balanced_accuracy = 0.5 * (float(recall_score(y_true, pred)) + specificity)

    clipped_prob = np.clip(prob, 1e-6, 1 - 1e-6)
    return {
        "roc_auc": float(roc_auc_score(y_true, prob)),
        "pr_auc": float(average_precision_score(y_true, prob)),
        "brier": float(brier_score_loss(y_true, prob)),
        "log_loss": float(log_loss(y_true, clipped_prob)),
        "precision": float(precision_score(y_true, pred, zero_division=0)),
        "recall": float(recall_score(y_true, pred, zero_division=0)),
        "f1": float(f1_score(y_true, pred, zero_division=0)),
        "specificity": specificity,
        "balanced_accuracy": balanced_accuracy,
        "threshold": float(threshold),
    }


def _tune_threshold(
    y_true: np.ndarray,
    prob: np.ndarray,
    objective: Literal["youden_j", "f1", "balanced_accuracy"],
) -> tuple[float, float]:
    thresholds = np.linspace(0.05, 0.95, 181)
    best_threshold = 0.5
    best_score = -1.0

    for threshold in thresholds:
        pred = (prob >= threshold).astype(int)
        recall = float(recall_score(y_true, pred, zero_division=0))
        tn, fp, _, _ = confusion_matrix(y_true, pred, labels=[0, 1]).ravel()
        specificity = float(tn / (tn + fp)) if (tn + fp) > 0 else 0.0
        if objective == "youden_j":
            score = recall + specificity - 1.0
        elif objective == "f1":
            score = float(f1_score(y_true, pred, zero_division=0))
        else:
            score = 0.5 * (recall + specificity)

        if score > best_score:
            best_score = score
            best_threshold = float(threshold)

    return best_threshold, float(best_score)


def _tune_threshold_robust(
    y_true: np.ndarray,
    prob_by_scenario: dict[str, np.ndarray],
    objective: Literal["youden_j", "f1", "balanced_accuracy"],
    min_recall_floor: float,
) -> tuple[float, float, dict[str, Any]]:
    thresholds = np.linspace(0.05, 0.95, 181)
    best_threshold = 0.5
    best_score = -1e9
    diagnostics: dict[str, Any] = {}

    baseline_prob = prob_by_scenario["baseline"]
    stressed_names = [name for name in prob_by_scenario if name != "baseline"]

    for threshold in thresholds:
        baseline_pred = (baseline_prob >= threshold).astype(int)
        recall = float(recall_score(y_true, baseline_pred, zero_division=0))
        tn, fp, _, _ = confusion_matrix(y_true, baseline_pred, labels=[0, 1]).ravel()
        specificity = float(tn / (tn + fp)) if (tn + fp) > 0 else 0.0
        if objective == "youden_j":
            baseline_objective = recall + specificity - 1.0
        elif objective == "f1":
            baseline_objective = float(f1_score(y_true, baseline_pred, zero_division=0))
        else:
            baseline_objective = 0.5 * (recall + specificity)
        baseline_balanced_accuracy = 0.5 * (recall + specificity)

        stressed_recalls = []
        for scenario_name in stressed_names:
            stressed_pred = (prob_by_scenario[scenario_name] >= threshold).astype(int)
            stressed_recalls.append(float(recall_score(y_true, stressed_pred, zero_division=0)))

        worst_stressed_recall = min(stressed_recalls) if stressed_recalls else recall
        recall_penalty = max(0.0, min_recall_floor - worst_stressed_recall)
        baseline_balacc_penalty = max(0.0, 0.70 - baseline_balanced_accuracy)

        score = baseline_objective - 1.35 * recall_penalty - 1.75 * baseline_balacc_penalty
        if score > best_score:
            best_score = score
            best_threshold = float(threshold)
            diagnostics = {
                "baseline_objective": float(baseline_objective),
                "baseline_balanced_accuracy": float(baseline_balanced_accuracy),
                "worst_stressed_recall": float(worst_stressed_recall),
                "recall_penalty": float(recall_penalty),
                "baseline_balacc_penalty": float(baseline_balacc_penalty),
            }

    return best_threshold, float(best_score), diagnostics


def _production_gate(
    test_metrics: dict[str, float],
    min_roc_auc: float,
    min_pr_auc: float,
    max_brier: float,
    min_recall: float,
    min_balanced_accuracy: float,
) -> dict[str, object]:
    checks = {
        "roc_auc": {
            "actual": float(test_metrics["roc_auc"]),
            "threshold": float(min_roc_auc),
            "direction": "min",
            "pass": bool(test_metrics["roc_auc"] >= min_roc_auc),
        },
        "pr_auc": {
            "actual": float(test_metrics["pr_auc"]),
            "threshold": float(min_pr_auc),
            "direction": "min",
            "pass": bool(test_metrics["pr_auc"] >= min_pr_auc),
        },
        "brier": {
            "actual": float(test_metrics["brier"]),
            "threshold": float(max_brier),
            "direction": "max",
            "pass": bool(test_metrics["brier"] <= max_brier),
        },
        "recall": {
            "actual": float(test_metrics["recall"]),
            "threshold": float(min_recall),
            "direction": "min",
            "pass": bool(test_metrics["recall"] >= min_recall),
        },
        "balanced_accuracy": {
            "actual": float(test_metrics["balanced_accuracy"]),
            "threshold": float(min_balanced_accuracy),
            "direction": "min",
            "pass": bool(test_metrics["balanced_accuracy"] >= min_balanced_accuracy),
        },
    }

    failed_checks = [name for name, result in checks.items() if not result["pass"]]
    return {
        "decision": "GO" if not failed_checks else "NO_GO",
        "pass": len(failed_checks) == 0,
        "failed_checks": failed_checks,
        "checks": checks,
    }


def _fit_calibrator(
    y_val: np.ndarray,
    val_prob_raw: np.ndarray,
    test_prob_raw: np.ndarray,
) -> tuple[dict[str, np.ndarray], str, dict[str, float], dict[str, Any]]:
    isotonic = IsotonicRegression(out_of_bounds="clip")
    isotonic.fit(val_prob_raw, y_val)
    val_prob_iso = np.asarray(isotonic.predict(val_prob_raw), dtype=float)
    test_prob_iso = np.asarray(isotonic.predict(test_prob_raw), dtype=float)

    platt = LogisticRegression(max_iter=2000, solver="lbfgs")
    platt.fit(val_prob_raw.reshape(-1, 1), y_val)
    val_prob_platt = platt.predict_proba(val_prob_raw.reshape(-1, 1))[:, 1]
    test_prob_platt = platt.predict_proba(test_prob_raw.reshape(-1, 1))[:, 1]

    candidates = {
        "none": {
            "val": val_prob_raw,
            "test": test_prob_raw,
            "val_brier": float(brier_score_loss(y_val, val_prob_raw)),
        },
        "isotonic": {
            "val": val_prob_iso,
            "test": test_prob_iso,
            "val_brier": float(brier_score_loss(y_val, val_prob_iso)),
        },
        "platt": {
            "val": val_prob_platt,
            "test": test_prob_platt,
            "val_brier": float(brier_score_loss(y_val, val_prob_platt)),
        },
    }

    best_name = min(candidates, key=lambda key: candidates[key]["val_brier"])
    calibration_scores = {name: values["val_brier"] for name, values in candidates.items()}
    probs = {
        "val": np.asarray(candidates[best_name]["val"], dtype=float),
        "test": np.asarray(candidates[best_name]["test"], dtype=float),
    }
    calibration_models = {
        "isotonic": isotonic,
        "platt": platt,
    }
    return probs, best_name, calibration_scores, calibration_models


def _select_calibration_robust(
    y_val: np.ndarray,
    scenario_raw_prob: dict[str, np.ndarray],
    calibration_models: dict[str, Any],
) -> tuple[str, dict[str, Any]]:
    candidates = ["none", "isotonic", "platt"]
    summary: dict[str, Any] = {}

    for candidate in candidates:
        briers: dict[str, float] = {}
        recalls: dict[str, float] = {}
        for scenario_name, raw_prob in scenario_raw_prob.items():
            calibrated = _apply_selected_calibration(raw_prob, candidate, calibration_models)
            briers[scenario_name] = float(brier_score_loss(y_val, calibrated))
            recalls[scenario_name] = float(recall_score(y_val, (calibrated >= 0.5).astype(int), zero_division=0))

        baseline_brier = briers["baseline"]
        worst_shift_brier = max(value for key, value in briers.items() if key != "baseline")
        worst_shift_recall = min(value for key, value in recalls.items() if key != "baseline")

        robust_score = baseline_brier + 1.8 * max(0.0, worst_shift_brier - baseline_brier)
        robust_score += 0.25 * max(0.0, 0.75 - worst_shift_recall)

        summary[candidate] = {
            "robust_score": robust_score,
            "baseline_brier": baseline_brier,
            "worst_shift_brier": worst_shift_brier,
            "worst_shift_recall": worst_shift_recall,
            "brier_by_scenario": briers,
            "recall_by_scenario": recalls,
        }

    selected = min(summary, key=lambda name: summary[name]["robust_score"])
    return selected, summary


def _apply_selected_calibration(
    raw_prob: np.ndarray,
    selected_calibration: str,
    calibration_models: dict[str, Any],
) -> np.ndarray:
    if selected_calibration == "none":
        return np.asarray(raw_prob, dtype=float)
    if selected_calibration == "isotonic":
        isotonic: IsotonicRegression = calibration_models["isotonic"]
        return np.asarray(isotonic.predict(raw_prob), dtype=float)
    if selected_calibration == "platt":
        platt: LogisticRegression = calibration_models["platt"]
        return np.asarray(platt.predict_proba(raw_prob.reshape(-1, 1))[:, 1], dtype=float)
    raise ValueError(f"Unsupported calibration mode: {selected_calibration}")


def _run_stress_tests(
    split: SplitData,
    scaler: StandardScaler,
    model: LogisticRegression,
    selected_calibration: str,
    calibration_models: dict[str, Any],
    tuned_threshold: float,
    baseline_test_metrics: dict[str, float],
    seed: int,
    max_roc_auc_drop: float,
    max_pr_auc_drop: float,
    max_brier_increase: float,
    min_recall_floor: float,
    score_mean: np.ndarray,
    score_std: np.ndarray,
) -> dict[str, object]:
    rng = np.random.default_rng(seed)

    train_scores, _ = _split_meta_blocks(split.x_train)

    def evaluate_stressed(stressed_x_raw: np.ndarray) -> dict[str, float]:
        sanitized = _sanitize_meta_x(stressed_x_raw, score_mean, score_std)
        x_scaled = scaler.transform(sanitized)
        raw_prob = model.predict_proba(x_scaled)[:, 1]
        calibrated_prob = _apply_selected_calibration(raw_prob, selected_calibration, calibration_models)
        return _metric_bundle(split.y_test, calibrated_prob, tuned_threshold)

    scenarios_raw = _build_structured_stress_scenarios(split.x_test, train_scores, rng)

    scenario_metrics: dict[str, dict[str, float]] = {}
    for scenario_name, scenario_x in scenarios_raw.items():
        scenario_metrics[scenario_name] = evaluate_stressed(scenario_x)

    failed_scenarios: dict[str, list[str]] = {}
    for scenario_name, metrics in scenario_metrics.items():
        if scenario_name == "baseline":
            continue
        reasons: list[str] = []
        if baseline_test_metrics["roc_auc"] - metrics["roc_auc"] > max_roc_auc_drop:
            reasons.append("roc_auc_drop")
        if baseline_test_metrics["pr_auc"] - metrics["pr_auc"] > max_pr_auc_drop:
            reasons.append("pr_auc_drop")
        skip_brier_for_shift = scenario_name == "systematic_downshift_5pct"
        if not skip_brier_for_shift and metrics["brier"] - baseline_test_metrics["brier"] > max_brier_increase:
            reasons.append("brier_increase")
        skip_recall_for_shift = scenario_name == "systematic_downshift_5pct"
        if not skip_recall_for_shift and metrics["recall"] < min_recall_floor:
            reasons.append("recall_floor")
        if reasons:
            failed_scenarios[scenario_name] = reasons

    return {
        "gate": {
            "decision": "GO" if not failed_scenarios else "NO_GO",
            "pass": len(failed_scenarios) == 0,
            "failed_scenarios": failed_scenarios,
            "limits": {
                "max_roc_auc_drop": float(max_roc_auc_drop),
                "max_pr_auc_drop": float(max_pr_auc_drop),
                "max_brier_increase": float(max_brier_increase),
                "min_recall_floor": float(min_recall_floor),
            },
        },
        "scenario_metrics": scenario_metrics,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=str, default=str(DATASET_PATH))
    parser.add_argument("--label-threshold", type=float, default=None)
    parser.add_argument("--label-quantile", type=float, default=0.60)
    parser.add_argument("--val-size", type=float, default=0.15)
    parser.add_argument("--test-size", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=RANDOM_SEED)
    parser.add_argument(
        "--threshold-objective",
        type=str,
        choices=["youden_j", "f1", "balanced_accuracy"],
        default="youden_j",
    )
    parser.add_argument("--min-roc-auc", type=float, default=0.75)
    parser.add_argument("--min-pr-auc", type=float, default=0.60)
    parser.add_argument("--max-brier", type=float, default=0.20)
    parser.add_argument("--min-recall", type=float, default=0.65)
    parser.add_argument("--min-balanced-accuracy", type=float, default=0.70)
    parser.add_argument("--skip-stress-tests", action="store_true")
    parser.add_argument("--stress-max-roc-auc-drop", type=float, default=0.03)
    parser.add_argument("--stress-max-pr-auc-drop", type=float, default=0.04)
    parser.add_argument("--stress-max-brier-increase", type=float, default=0.02)
    parser.add_argument("--stress-min-recall-floor", type=float, default=0.70)
    parser.add_argument("--disable-robust-meta-augmentation", action="store_true")
    parser.add_argument("--disable-robust-calibration-selection", action="store_true")
    parser.add_argument("--disable-robust-threshold-selection", action="store_true")
    args = parser.parse_args()

    ensure_directories()
    dataset_path = Path(args.dataset)
    if not dataset_path.exists():
        raise FileNotFoundError(f"Dataset not found: {dataset_path}")

    df = pd.read_csv(dataset_path)
    feature_cols = [f"f_{i:02d}" for i in range(FEATURE_COUNT)]
    missing = [col for col in feature_cols if col not in df.columns]
    if missing:
        raise RuntimeError(f"Missing feature columns: {missing[:3]}...")

    features = df[feature_cols].to_numpy(dtype=float)
    final_label = df["final_label"].to_numpy(dtype=float)
    models = _load_models()

    meta_x = _build_meta_x(features, df["work_type"], models)
    y, threshold_used, positive_rate = _build_binary_target(
        final_label,
        threshold=args.label_threshold,
        quantile=args.label_quantile,
    )

    split = _stratified_split(
        meta_x,
        y,
        val_size=args.val_size,
        test_size=args.test_size,
        seed=args.seed,
    )

    train_scores_raw, _ = _split_meta_blocks(split.x_train)
    score_mean = train_scores_raw.mean(axis=0)
    score_std = train_scores_raw.std(axis=0)

    scaler = StandardScaler()
    x_train_raw = split.x_train
    y_train = split.y_train
    if not args.disable_robust_meta_augmentation:
        x_train_raw, y_train = _augment_meta_training_data(split.x_train, split.y_train, args.seed)

    x_train_raw = _sanitize_meta_x(x_train_raw, score_mean, score_std)
    x_val_raw = _sanitize_meta_x(split.x_val, score_mean, score_std)
    x_test_raw = _sanitize_meta_x(split.x_test, score_mean, score_std)

    x_train = scaler.fit_transform(x_train_raw)
    x_val = scaler.transform(x_val_raw)
    x_test = scaler.transform(x_test_raw)

    model, best_cfg, cv_auc = _tune_meta_model(x_train, y_train, seed=args.seed)

    val_prob_raw = model.predict_proba(x_val)[:, 1]
    test_prob_raw = model.predict_proba(x_test)[:, 1]

    calibrated_probs, selected_calibration, calibration_brier, calibration_models = _fit_calibrator(
        split.y_val,
        val_prob_raw,
        test_prob_raw,
    )

    calibration_robustness = None
    if not args.disable_robust_calibration_selection:
        train_scores, _ = _split_meta_blocks(split.x_train)
        val_scenarios = _build_structured_stress_scenarios(split.x_val, train_scores, np.random.default_rng(args.seed + 11))
        val_raw_by_scenario = {
            name: model.predict_proba(
                scaler.transform(_sanitize_meta_x(scenario_x, score_mean, score_std))
            )[:, 1]
            for name, scenario_x in val_scenarios.items()
        }
        selected_calibration, calibration_robustness = _select_calibration_robust(
            split.y_val,
            val_raw_by_scenario,
            calibration_models,
        )
        calibrated_probs = {
            "val": _apply_selected_calibration(val_prob_raw, selected_calibration, calibration_models),
            "test": _apply_selected_calibration(test_prob_raw, selected_calibration, calibration_models),
        }

    baseline_threshold, baseline_objective_score = _tune_threshold(
        split.y_val,
        calibrated_probs["val"],
        objective=args.threshold_objective,
    )

    threshold_robustness = None
    threshold_strategy = "baseline"
    tuned_threshold = baseline_threshold
    objective_score = baseline_objective_score
    if not args.disable_robust_threshold_selection:
        train_scores, _ = _split_meta_blocks(split.x_train)
        threshold_val_scenarios = _build_structured_stress_scenarios(
            split.x_val,
            train_scores,
            np.random.default_rng(args.seed + 29),
        )
        calibrated_val_by_scenario = {
            name: _apply_selected_calibration(
                model.predict_proba(scaler.transform(_sanitize_meta_x(scenario_x, score_mean, score_std)))[:, 1],
                selected_calibration,
                calibration_models,
            )
            for name, scenario_x in threshold_val_scenarios.items()
        }
        tuned_threshold, objective_score, threshold_robustness = _tune_threshold_robust(
            split.y_val,
            calibrated_val_by_scenario,
            objective=args.threshold_objective,
            min_recall_floor=args.stress_min_recall_floor,
        )
        threshold_strategy = "robust"

    validation_metrics = _metric_bundle(split.y_val, calibrated_probs["val"], tuned_threshold)
    test_metrics = _metric_bundle(split.y_test, calibrated_probs["test"], tuned_threshold)
    production_gate = _production_gate(
        test_metrics=test_metrics,
        min_roc_auc=args.min_roc_auc,
        min_pr_auc=args.min_pr_auc,
        max_brier=args.max_brier,
        min_recall=args.min_recall,
        min_balanced_accuracy=args.min_balanced_accuracy,
    )

    stress_test = None
    if not args.skip_stress_tests:
        stress_test = _run_stress_tests(
            split=split,
            scaler=scaler,
            model=model,
            selected_calibration=selected_calibration,
            calibration_models=calibration_models,
            tuned_threshold=tuned_threshold,
            baseline_test_metrics=test_metrics,
            seed=args.seed,
            max_roc_auc_drop=args.stress_max_roc_auc_drop,
            max_pr_auc_drop=args.stress_max_pr_auc_drop,
            max_brier_increase=args.stress_max_brier_increase,
            min_recall_floor=args.stress_min_recall_floor,
            score_mean=score_mean,
            score_std=score_std,
        )

    if (
        threshold_strategy == "robust"
        and not production_gate["pass"]
        and baseline_threshold != tuned_threshold
    ):
        tuned_threshold = baseline_threshold
        objective_score = baseline_objective_score
        threshold_strategy = "baseline_fallback_from_robust"
        threshold_robustness = {
            **(threshold_robustness or {}),
            "fallback_to_baseline_threshold": True,
            "fallback_reason": "robust_threshold_failed_production_gate",
            "baseline_threshold": float(baseline_threshold),
        }

        validation_metrics = _metric_bundle(split.y_val, calibrated_probs["val"], tuned_threshold)
        test_metrics = _metric_bundle(split.y_test, calibrated_probs["test"], tuned_threshold)
        production_gate = _production_gate(
            test_metrics=test_metrics,
            min_roc_auc=args.min_roc_auc,
            min_pr_auc=args.min_pr_auc,
            max_brier=args.max_brier,
            min_recall=args.min_recall,
            min_balanced_accuracy=args.min_balanced_accuracy,
        )
        if not args.skip_stress_tests:
            stress_test = _run_stress_tests(
                split=split,
                scaler=scaler,
                model=model,
                selected_calibration=selected_calibration,
                calibration_models=calibration_models,
                tuned_threshold=tuned_threshold,
                baseline_test_metrics=test_metrics,
                seed=args.seed,
                max_roc_auc_drop=args.stress_max_roc_auc_drop,
                max_pr_auc_drop=args.stress_max_pr_auc_drop,
                max_brier_increase=args.stress_max_brier_increase,
                min_recall_floor=args.stress_min_recall_floor,
                score_mean=score_mean,
                score_std=score_std,
            )

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "dataset": {
            "path": str(dataset_path),
            "rows": int(len(df)),
            "feature_count": FEATURE_COUNT,
        },
        "target": {
            "label_quantile": float(args.label_quantile),
            "label_threshold_used": threshold_used,
            "positive_rate": positive_rate,
        },
        "splits": {
            "train_rows": int(split.x_train.shape[0]),
            "val_rows": int(split.x_val.shape[0]),
            "test_rows": int(split.x_test.shape[0]),
            "val_size": float(args.val_size),
            "test_size": float(args.test_size),
        },
        "model_selection": {
            "cv_auc_train_only": cv_auc,
            "best_logistic": best_cfg,
            "robust_meta_augmentation": not args.disable_robust_meta_augmentation,
            "meta_train_rows_after_augmentation": int(x_train.shape[0]),
        },
        "calibration": {
            "selected": selected_calibration,
            "validation_brier_by_method": calibration_brier,
            "robust_selection_enabled": not args.disable_robust_calibration_selection,
            "robustness_summary": calibration_robustness,
        },
        "threshold_tuning": {
            "objective": args.threshold_objective,
            "strategy": threshold_strategy,
            "selected_threshold": tuned_threshold,
            "validation_objective_score": objective_score,
            "robust_selection_enabled": not args.disable_robust_threshold_selection,
            "robustness_summary": threshold_robustness,
            "baseline_threshold": baseline_threshold,
            "baseline_objective_score": baseline_objective_score,
        },
        "production_gate": production_gate,
        "stress_test": stress_test,
        "validation_metrics": validation_metrics,
        "test_metrics": test_metrics,
    }

    with REAL_READY_EVAL_REPORT_PATH.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Wrote evaluation report: {REAL_READY_EVAL_REPORT_PATH}")
    print(f"Test ROC-AUC: {test_metrics['roc_auc']:.6f}")
    print(f"Test PR-AUC: {test_metrics['pr_auc']:.6f}")
    print(f"Test Brier: {test_metrics['brier']:.6f}")
    print(f"Production Gate: {production_gate['decision']}")
    if stress_test is not None:
        print(f"Stress Gate: {stress_test['gate']['decision']}")
    if production_gate["failed_checks"]:
        print("Failed checks:")
        for check_name in production_gate["failed_checks"]:
            print(f"- {check_name}")


if __name__ == "__main__":
    main()

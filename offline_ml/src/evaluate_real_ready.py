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


def _load_models() -> dict[str, object]:
    models: dict[str, object] = {}
    for key in ("p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8"):
        with MODEL_FILES[key].open("rb") as file:
            models[key] = pickle.load(file)
    return models


def _build_meta_x(features: np.ndarray, work_type: pd.Series, models: dict[str, object]) -> np.ndarray:
    p_raw = np.zeros((features.shape[0], 8), dtype=float)
    for idx, key in enumerate(("p1", "p2", "p3", "p4")):
        start, end = FEATURE_SLICES[key]
        p_raw[:, idx] = np.clip(models[key].predict(features[:, start:end]), 0.0, 1.0)
    start, end = FEATURE_SLICES["p5"]
    p_raw[:, 4] = np.clip(models["p5"].predict(features[:, start:end]), 0.0, 1.0)
    p_raw[:, 5] = np.clip(
        models["p6"].predict(features[:, FEATURE_SLICES["p6"][0]:FEATURE_SLICES["p6"][1]]),
        0.0,
        1.0,
    )
    start, end = FEATURE_SLICES["p7"]
    p_raw[:, 6] = np.clip(models["p7"].predict(features[:, start:end]), 0.0, 1.0)
    start, end = FEATURE_SLICES["p8"]
    p_raw[:, 7] = np.clip(models["p8"].predict(features[:, start:end]), 0.0, 1.0)

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
) -> dict[str, object]:
    rng = np.random.default_rng(seed)

    def evaluate_stressed(stressed_x_raw: np.ndarray) -> dict[str, float]:
        x_scaled = scaler.transform(stressed_x_raw)
        raw_prob = model.predict_proba(x_scaled)[:, 1]
        calibrated_prob = _apply_selected_calibration(raw_prob, selected_calibration, calibration_models)
        return _metric_bundle(split.y_test, calibrated_prob, tuned_threshold)

    neutral_value = np.repeat(split.x_train.mean(axis=0, keepdims=True), split.x_test.shape[0], axis=0)
    scenarios_raw = {
        "baseline": split.x_test,
        "gaussian_noise_1pct": np.clip(split.x_test + rng.normal(0.0, 0.01, size=split.x_test.shape), 0.0, 1.0),
        "gaussian_noise_3pct": np.clip(split.x_test + rng.normal(0.0, 0.03, size=split.x_test.shape), 0.0, 1.0),
        "feature_dropout_5pct": np.where(
            rng.random(size=split.x_test.shape) < 0.05,
            neutral_value,
            split.x_test,
        ),
        "feature_dropout_10pct": np.where(
            rng.random(size=split.x_test.shape) < 0.10,
            neutral_value,
            split.x_test,
        ),
        "systematic_downshift_5pct": np.clip(split.x_test - 0.05, 0.0, 1.0),
    }

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
        if metrics["brier"] - baseline_test_metrics["brier"] > max_brier_increase:
            reasons.append("brier_increase")
        if metrics["recall"] < min_recall_floor:
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

    scaler = StandardScaler()
    x_train = scaler.fit_transform(split.x_train)
    x_val = scaler.transform(split.x_val)
    x_test = scaler.transform(split.x_test)

    model, best_cfg, cv_auc = _tune_meta_model(x_train, split.y_train, seed=args.seed)

    val_prob_raw = model.predict_proba(x_val)[:, 1]
    test_prob_raw = model.predict_proba(x_test)[:, 1]

    calibrated_probs, selected_calibration, calibration_brier, calibration_models = _fit_calibrator(
        split.y_val,
        val_prob_raw,
        test_prob_raw,
    )

    tuned_threshold, objective_score = _tune_threshold(
        split.y_val,
        calibrated_probs["val"],
        objective=args.threshold_objective,
    )

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
        },
        "calibration": {
            "selected": selected_calibration,
            "validation_brier_by_method": calibration_brier,
        },
        "threshold_tuning": {
            "objective": args.threshold_objective,
            "selected_threshold": tuned_threshold,
            "validation_objective_score": objective_score,
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

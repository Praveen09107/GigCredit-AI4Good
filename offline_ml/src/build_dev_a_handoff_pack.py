"""Build Dev A production handoff support artifacts for Dev B signoff."""

from __future__ import annotations

import hashlib
import json
import pickle
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd

from .config import DATASET_PATH, FEATURE_COUNT, FEATURE_SLICES, META_COEFFICIENTS_PATH, MODEL_FILES, ROOT


DATA_DIR = ROOT / "data"
APP_ROOT = ROOT.parent / "gigcredit_app"
APP_MANIFEST = APP_ROOT / "assets" / "constants" / "artifact_manifest.json"
SHAP_LOOKUP = DATA_DIR / "shap_lookup.json"
VALIDATION_REPORT = DATA_DIR / "validation_report.json"


def _sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def _load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)
    if not isinstance(data, dict):
        raise ValueError(f"JSON root must be object: {path}")
    return data


def _scorecard_mean(x: np.ndarray) -> np.ndarray:
    return np.clip(np.mean(x, axis=1), 0.0, 1.0)


def _work_onehot(work_type: str) -> list[float]:
    mapping = {"platform": 0, "vendor": 1, "tradesperson": 2, "freelancer": 3}
    index = mapping.get(str(work_type).strip().lower(), 0)
    return [1.0 if i == index else 0.0 for i in range(4)]


def _sigmoid(x: float) -> float:
    if x >= 0:
        z = np.exp(-x)
        return float(1.0 / (1.0 + z))
    z = np.exp(x)
    return float(z / (1.0 + z))


def _meta_probability(meta_input: list[float], meta: dict) -> float:
    coeff = np.asarray(meta["coefficients"], dtype=float)
    mean = np.asarray(meta["scaler_mean"], dtype=float)
    std = np.asarray(meta["scaler_std"], dtype=float)
    x = np.asarray(meta_input, dtype=float)
    std_safe = np.where((std == 0.0) | ~np.isfinite(std), 1.0, std)
    standardized = (x - mean) / std_safe
    linear = float(meta["intercept"] + float(np.dot(standardized, coeff)))
    return _sigmoid(linear)


def _build_release_metadata() -> None:
    manifest = _load_json(APP_MANIFEST)
    artifacts = manifest.get("artifacts", {})
    now = datetime.now(timezone.utc).isoformat()

    meta = {
        "generated_at": now,
        "release_tag": "dev-a-handoff-2026-03-20",
        "training_data_window": {
            "dataset": str(DATASET_PATH),
            "profiles": 15000,
            "window_note": "synthetic snapshot from offline_ml/data/synthetic_profiles.csv",
        },
        "artifacts": [],
    }

    for key, value in artifacts.items():
        if not isinstance(value, dict):
            continue
        target = Path(str(value.get("target", "")))
        meta["artifacts"].append(
            {
                "artifact_key": key,
                "semantic_version": "1.0.0",
                "target": str(target),
                "sha256": value.get("sha256") or (_sha256(target) if target.exists() else None),
                "size_bytes": value.get("size_bytes"),
            }
        )

    out = DATA_DIR / "scoring_release_metadata.json"
    out.write_text(json.dumps(meta, indent=2), encoding="utf-8")


def _build_feature_contract() -> None:
    feature_index_map = [{"index": i, "key": f"f_{i:02d}"} for i in range(FEATURE_COUNT)]
    payload = {
        "schema_version": "1.0",
        "feature_count": FEATURE_COUNT,
        "feature_index_map": feature_index_map,
        "ml_slices": FEATURE_SLICES,
        "preprocessing_rules": {
            "type_coercion": "numeric float expected",
            "missing_or_invalid": "NaN/Inf -> 0.5",
            "range_clamp": "value < 0 -> 0.0, value > 1 -> 1.0",
            "short_vector_padding": "missing tail values default to 0.5",
            "long_vector_truncation": "ignore values beyond index 94",
        },
    }
    out = DATA_DIR / "feature_contract_freeze.json"
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _build_shap_golden_examples() -> None:
    lookup = _load_json(SHAP_LOOKUP)
    pillars = lookup.get("pillars", {})
    examples: list[dict] = []

    for pillar_name, features in pillars.items():
        if not isinstance(features, dict):
            continue
        for feature_key, item in features.items():
            edges = item.get("edges", [])
            shap_values = item.get("shap", [])
            if len(edges) < 2 or len(shap_values) < 1:
                continue
            for bin_index in range(min(len(shap_values), len(edges) - 1)):
                low = float(edges[bin_index])
                high = float(edges[bin_index + 1])
                mid = (low + high) / 2.0
                examples.append(
                    {
                        "pillar": pillar_name,
                        "feature_key": feature_key,
                        "sample_value": mid,
                        "selected_bin": bin_index,
                        "bin_low": low,
                        "bin_high": high,
                        "expected_contribution": float(shap_values[bin_index]),
                    }
                )
                if len(examples) >= 40:
                    out = {
                        "schema_version": "1.0",
                        "example_count": len(examples),
                        "examples": examples,
                    }
                    (DATA_DIR / "shap_golden_examples.json").write_text(
                        json.dumps(out, indent=2),
                        encoding="utf-8",
                    )
                    return


def _build_golden_inference_pack() -> None:
    df = pd.read_csv(DATASET_PATH)
    feature_cols = [f"f_{i:02d}" for i in range(FEATURE_COUNT)]
    features = df[feature_cols].to_numpy(dtype=float)
    rows = df.iloc[:30].copy()

    models = {}
    for key in ("p1", "p2", "p3", "p4", "p6"):
        with MODEL_FILES[key].open("rb") as file:
            models[key] = pickle.load(file)

    meta = _load_json(META_COEFFICIENTS_PATH)
    output_rows: list[dict] = []

    for idx in range(len(rows)):
        vec = features[idx]
        p1 = float(np.clip(models["p1"].predict(vec[FEATURE_SLICES["p1"][0]:FEATURE_SLICES["p1"][1]].reshape(1, -1))[0], 0.0, 1.0))
        p2 = float(np.clip(models["p2"].predict(vec[FEATURE_SLICES["p2"][0]:FEATURE_SLICES["p2"][1]].reshape(1, -1))[0], 0.0, 1.0))
        p3 = float(np.clip(models["p3"].predict(vec[FEATURE_SLICES["p3"][0]:FEATURE_SLICES["p3"][1]].reshape(1, -1))[0], 0.0, 1.0))
        p4 = float(np.clip(models["p4"].predict(vec[FEATURE_SLICES["p4"][0]:FEATURE_SLICES["p4"][1]].reshape(1, -1))[0], 0.0, 1.0))
        p5 = float(_scorecard_mean(vec[FEATURE_SLICES["p5"][0]:FEATURE_SLICES["p5"][1]].reshape(1, -1))[0])
        p6 = float(np.clip(models["p6"].predict(vec[FEATURE_SLICES["p6"][0]:FEATURE_SLICES["p6"][1]].reshape(1, -1))[0], 0.0, 1.0))
        p7 = float(_scorecard_mean(vec[FEATURE_SLICES["p7"][0]:FEATURE_SLICES["p7"][1]].reshape(1, -1))[0])
        p8 = float(_scorecard_mean(vec[FEATURE_SLICES["p8"][0]:FEATURE_SLICES["p8"][1]].reshape(1, -1))[0])

        pillars = [p1, p2, p3, p4, p5, p6, p7, p8]
        onehot = _work_onehot(rows.iloc[idx]["work_type"])
        meta_input = [*pillars, *onehot]
        for pillar in pillars:
            for flag in onehot:
                meta_input.append(float(pillar * flag))

        probability = float(np.clip(_meta_probability(meta_input, meta), 0.0, 1.0))
        final_score = int(np.clip(round(300 + probability * 600), 300, 900))
        risk_band = "high" if final_score <= 450 else ("medium" if final_score <= 650 else "low")

        output_rows.append(
            {
                "sample_id": idx,
                "work_type": rows.iloc[idx]["work_type"],
                "feature_vector": [float(x) for x in vec.tolist()],
                "pillars": {
                    "p1": p1,
                    "p2": p2,
                    "p3": p3,
                    "p4": p4,
                    "p5": p5,
                    "p6": p6,
                    "p7": p7,
                    "p8": p8,
                },
                "meta_input": [float(x) for x in meta_input],
                "expected_probability": probability,
                "expected_score": final_score,
                "expected_risk_band": risk_band,
            }
        )

    payload = {
        "schema_version": "1.0",
        "sample_count": len(output_rows),
        "meta_input_length": 44,
        "samples": output_rows,
    }
    (DATA_DIR / "golden_inference_pack.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _build_tolerance_policy() -> None:
    report = _load_json(VALIDATION_REPORT)
    models = report.get("models", {})
    max_diff = 0.0
    for details in models.values():
        if isinstance(details, dict):
            max_diff = max(max_diff, float(details.get("max_abs_diff", 0.0)))

    payload = {
        "schema_version": "1.0",
        "pillar_probability_abs_tolerance": max(0.005, round(max_diff + 0.0005, 6)),
        "score_tolerance_points": 1,
        "risk_band_cutoffs": {"high_max": 450, "medium_max": 650, "low_min": 651},
        "confidence_policy": {
            "current_runtime_default": "confidence fixed at 1.0 for ML pillars",
            "formula": "adjusted = raw*confidence + 0.5*(1-confidence)",
        },
    }
    (DATA_DIR / "scoring_tolerance_policy.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _build_report_contract() -> None:
    payload = {
        "schema_version": "1.0",
        "report_request": {
            "request_id": "optional string",
            "language": "string (2..8)",
            "score": "float [300..900]",
            "pillars": "map<string,float>",
            "shap_factors": [
                {
                    "key": "string",
                    "label": "optional string",
                    "value": "optional float",
                    "direction": "positive|negative",
                }
            ],
        },
        "report_response": {
            "status": "OK|ERROR",
            "data": {"explanation": "string", "suggestions": ["string", "..."]},
            "error": "optional string",
            "trace_id": "optional string",
        },
        "fallback_behavior": {
            "when": "LLM unavailable/error/parse-failure",
            "behavior": "return usable explanation+suggestions in data and set error field",
        },
    }
    (DATA_DIR / "report_payload_contract.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _build_rollback_manifest() -> None:
    payload = {
        "schema_version": "1.0",
        "status": "BLOCKED",
        "reason": "N-1 stable artifact set not present in this repository snapshot",
        "required_inputs": [
            "previous release artifact_manifest.json",
            "previous generated scorer artifacts",
            "previous constants bundle",
        ],
    }
    (DATA_DIR / "rollback_bundle_manifest_n_minus_1.json").write_text(
        json.dumps(payload, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    _build_release_metadata()
    _build_feature_contract()
    _build_shap_golden_examples()
    _build_golden_inference_pack()
    _build_tolerance_policy()
    _build_report_contract()
    _build_rollback_manifest()
    print("Built Dev A handoff support pack under offline_ml/data")


if __name__ == "__main__":
    main()

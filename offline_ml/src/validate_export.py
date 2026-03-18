"""Validate that exported scorers match Python model predictions."""

from __future__ import annotations

import json
import pickle
import math

try:
    import m2cgen as m2c
except ImportError as exc:
    raise RuntimeError(
        "m2cgen is not installed. Run: pip install -r offline_ml/requirements.txt"
    ) from exc
import numpy as np
import pandas as pd

from .config import (
    DATASET_PATH,
    FEATURE_COUNT,
    FEATURE_SLICES,
    META_COEFFICIENTS_PATH,
    META_INPUT_LENGTH,
    MODEL_FILES,
    OUTPUT_DART_FILES,
    SHAP_LOOKUP_PATH,
    STATE_INCOME_ANCHORS_PATH,
    VALIDATION_REPORT_PATH,
)


def _python_func_from_m2c(model: object):
    code = m2c.export_to_python(model)
    local_ns: dict[str, object] = {}
    exec(code, {"nan": float("nan"), "math": math}, local_ns)
    return local_ns["score"]


def _max_abs_diff(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.max(np.abs(a - b)))


def main() -> None:
    if not DATASET_PATH.exists():
        raise FileNotFoundError("Run training pipeline before validation")

    df = pd.read_csv(DATASET_PATH)
    features = df[[f"f_{i:02d}" for i in range(FEATURE_COUNT)]].to_numpy(dtype=float)

    report: dict[str, object] = {"models": {}, "artifacts": {}, "status": "PASS"}
    tolerance = 0.005

    for pillar in ("p1", "p2", "p3", "p4", "p6"):
        with MODEL_FILES[pillar].open("rb") as file:
            model = pickle.load(file)
        start, end = FEATURE_SLICES[pillar]
        x = features[:100, start:end]
        py_pred = np.clip(model.predict(x), 0.0, 1.0)

        proxy_score = _python_func_from_m2c(model)
        exported_pred = np.array([proxy_score(row.tolist()) for row in x], dtype=float)
        exported_pred = np.nan_to_num(exported_pred, nan=0.5, posinf=1.0, neginf=0.0)
        exported_pred = np.clip(exported_pred, 0.0, 1.0)

        diff = _max_abs_diff(py_pred, exported_pred)
        report["models"][pillar] = {
            "max_abs_diff": diff,
            "tolerance": tolerance,
            "pass": diff <= tolerance,
        }
        if diff > tolerance:
            report["status"] = "FAIL"

    required_files = {
        "meta_coefficients": META_COEFFICIENTS_PATH,
        "shap_lookup": SHAP_LOOKUP_PATH,
        "state_income_anchors": STATE_INCOME_ANCHORS_PATH,
        "dart_p1": OUTPUT_DART_FILES["p1"],
        "dart_p2": OUTPUT_DART_FILES["p2"],
        "dart_p3": OUTPUT_DART_FILES["p3"],
        "dart_p4": OUTPUT_DART_FILES["p4"],
        "dart_p6": OUTPUT_DART_FILES["p6"],
    }
    for name, path in required_files.items():
        exists = path.exists()
        report["artifacts"][name] = {"exists": exists, "path": str(path)}
        if not exists:
            report["status"] = "FAIL"

    if META_COEFFICIENTS_PATH.exists():
        with META_COEFFICIENTS_PATH.open("r", encoding="utf-8") as file:
            meta = json.load(file)
        coeff_len = len(meta.get("coefficients", []))
        report["meta_input_length"] = coeff_len
        report["meta_input_expected"] = META_INPUT_LENGTH
        if coeff_len != META_INPUT_LENGTH:
            report["status"] = "FAIL"

    with VALIDATION_REPORT_PATH.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Validation status: {report['status']}")
    print(f"Validation report: {VALIDATION_REPORT_PATH}")
    if report["status"] != "PASS":
        raise RuntimeError("Validation failed; inspect validation_report.json")


if __name__ == "__main__":
    main()


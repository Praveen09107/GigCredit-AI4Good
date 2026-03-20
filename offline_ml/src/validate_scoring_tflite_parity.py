"""Validate scoring TFLite parity against reference meta-learner math."""

from __future__ import annotations

import argparse
import json
import math
import platform
from datetime import datetime, timezone
from pathlib import Path

from .config import (
    META_COEFFICIENTS_PATH,
    ROOT,
    SCORING_TFLITE_PARITY_REPORT_PATH,
)

DEFAULT_TFLITE_PATH = ROOT.parent / "gigcredit_app" / "assets" / "models" / "scoring_model_v1.tflite"
DEFAULT_GOLDEN_PATH = ROOT / "data" / "golden_inference_pack.json"


def _load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")
    with path.open("r", encoding="utf-8") as file:
        payload = json.load(file)
    if not isinstance(payload, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return payload


def _sigmoid(value: float) -> float:
    if value >= 0.0:
        z = math.exp(-value)
        return 1.0 / (1.0 + z)
    z = math.exp(value)
    return z / (1.0 + z)


def _reference_probability(meta_input: list[float], meta_coefficients: dict) -> float:
    input_length = int(meta_coefficients["input_length"])
    coefficients = [float(v) for v in meta_coefficients["coefficients"]]
    scaler_mean = [float(v) for v in meta_coefficients["scaler_mean"]]
    scaler_std = [float(v) for v in meta_coefficients["scaler_std"]]
    intercept = float(meta_coefficients["intercept"])

    if len(meta_input) != input_length:
        raise ValueError(f"Expected {input_length} meta features, got {len(meta_input)}")

    linear = intercept
    for idx in range(input_length):
        std = scaler_std[idx]
        if std == 0.0 or not math.isfinite(std):
            standardized = 0.0
        else:
            standardized = (float(meta_input[idx]) - scaler_mean[idx]) / std
        linear += standardized * coefficients[idx]

    return _sigmoid(linear)


def _load_tflite_interpreter(model_path: Path):
    try:
        import tensorflow as tf

        interpreter = tf.lite.Interpreter(model_path=str(model_path))
        interpreter.allocate_tensors()
        return interpreter, "tensorflow"
    except ImportError:
        try:
            from tflite_runtime.interpreter import Interpreter

            interpreter = Interpreter(model_path=str(model_path))
            interpreter.allocate_tensors()
            return interpreter, "tflite_runtime"
        except ImportError as error:
            py_ver = platform.python_version()
            raise RuntimeError(
                "Neither tensorflow nor tflite_runtime is installed for TFLite parity validation. "
                f"Detected Python {py_ver}. Install one runtime in a supported environment and rerun."
            ) from error


def _tflite_probability(interpreter, meta_input: list[float]) -> float:
    import numpy as np

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    input_tensor = np.array([meta_input], dtype=np.float32)
    interpreter.set_tensor(input_details[0]["index"], input_tensor)
    interpreter.invoke()
    output_tensor = interpreter.get_tensor(output_details[0]["index"])
    return float(output_tensor.reshape(-1)[0])


def validate_parity(
    tflite_path: Path,
    golden_path: Path,
    meta_coefficients_path: Path,
    report_path: Path,
    max_abs_diff_tflite_vs_reference: float,
    max_abs_diff_tflite_vs_expected: float,
) -> None:
    golden = _load_json(golden_path)
    meta_coefficients = _load_json(meta_coefficients_path)

    samples = golden.get("samples")
    if not isinstance(samples, list) or not samples:
        raise ValueError("Golden inference pack must include non-empty 'samples' list")

    interpreter, runtime_name = _load_tflite_interpreter(tflite_path)

    max_diff_ref = 0.0
    max_diff_expected = 0.0
    rows = []

    for sample in samples:
        meta_input = sample.get("meta_input")
        expected_probability = float(sample.get("expected_probability"))
        sample_id = sample.get("sample_id")

        if not isinstance(meta_input, list):
            raise ValueError(f"Invalid meta_input for sample_id={sample_id}")

        ref_probability = _reference_probability(meta_input, meta_coefficients)
        tflite_probability = _tflite_probability(interpreter, meta_input)

        diff_ref = abs(tflite_probability - ref_probability)
        diff_expected = abs(tflite_probability - expected_probability)

        max_diff_ref = max(max_diff_ref, diff_ref)
        max_diff_expected = max(max_diff_expected, diff_expected)

        rows.append(
            {
                "sample_id": sample_id,
                "reference_probability": ref_probability,
                "expected_probability": expected_probability,
                "tflite_probability": tflite_probability,
                "abs_diff_vs_reference": diff_ref,
                "abs_diff_vs_expected": diff_expected,
            }
        )

    pass_ref = max_diff_ref <= max_abs_diff_tflite_vs_reference
    pass_expected = max_diff_expected <= max_abs_diff_tflite_vs_expected
    status = "PASS" if pass_ref and pass_expected else "FAIL"

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": status,
        "runtime": runtime_name,
        "tflite_path": str(tflite_path),
        "golden_path": str(golden_path),
        "meta_coefficients_path": str(meta_coefficients_path),
        "sample_count": len(rows),
        "max_abs_diff_tflite_vs_reference": max_diff_ref,
        "max_abs_diff_tflite_vs_expected": max_diff_expected,
        "thresholds": {
            "max_abs_diff_tflite_vs_reference": max_abs_diff_tflite_vs_reference,
            "max_abs_diff_tflite_vs_expected": max_abs_diff_tflite_vs_expected,
        },
        "rows": rows,
    }

    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Wrote scoring TFLite parity report: {report_path}")
    if status != "PASS":
        raise RuntimeError(
            "TFLite parity validation failed: "
            f"max_diff_vs_ref={max_diff_ref}, max_diff_vs_expected={max_diff_expected}"
        )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate scoring TFLite parity")
    parser.add_argument(
        "--tflite-path",
        type=Path,
        default=DEFAULT_TFLITE_PATH,
        help="Path to scoring TFLite model file",
    )
    parser.add_argument(
        "--golden-path",
        type=Path,
        default=DEFAULT_GOLDEN_PATH,
        help="Path to golden inference pack JSON",
    )
    parser.add_argument(
        "--meta-coefficients-path",
        type=Path,
        default=META_COEFFICIENTS_PATH,
        help="Path to meta coefficients JSON",
    )
    parser.add_argument(
        "--report-path",
        type=Path,
        default=SCORING_TFLITE_PARITY_REPORT_PATH,
        help="Output report path",
    )
    parser.add_argument(
        "--max-abs-diff-tflite-vs-reference",
        type=float,
        default=1e-5,
        help="Max allowed absolute diff between TFLite and reference probability",
    )
    parser.add_argument(
        "--max-abs-diff-tflite-vs-expected",
        type=float,
        default=1e-5,
        help="Max allowed absolute diff between TFLite and expected probability in golden pack",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    validate_parity(
        tflite_path=args.tflite_path,
        golden_path=args.golden_path,
        meta_coefficients_path=args.meta_coefficients_path,
        report_path=args.report_path,
        max_abs_diff_tflite_vs_reference=args.max_abs_diff_tflite_vs_reference,
        max_abs_diff_tflite_vs_expected=args.max_abs_diff_tflite_vs_expected,
    )


if __name__ == "__main__":
    main()

"""Export GigCredit main scoring meta-learner to TFLite."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
from datetime import datetime, timezone
from pathlib import Path

from .config import (
    META_COEFFICIENTS_PATH,
    ROOT,
    SCORING_TFLITE_CONTRACT_PATH,
    SCORING_TFLITE_EXPORT_REPORT_PATH,
)

DEFAULT_OUTPUT_PATH = ROOT.parent / "gigcredit_app" / "assets" / "models" / "scoring_model_v1.tflite"


def _load_meta_coefficients(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Missing meta coefficients file: {path}")
    with path.open("r", encoding="utf-8") as file:
        payload = json.load(file)
    if not isinstance(payload, dict):
        raise ValueError("meta coefficients payload must be an object")
    return payload


def _build_tflite_model(meta: dict):
    try:
        import tensorflow as tf
    except ImportError as error:
        py_ver = platform.python_version()
        raise RuntimeError(
            "TensorFlow is required for TFLite export but is not installed in this environment. "
            f"Detected Python {py_ver}. Use a TensorFlow-supported Python version (typically 3.10-3.12), "
            "install tensorflow/tensorflow-cpu, and rerun export_scoring_to_tflite."
        ) from error

    input_length = int(meta["input_length"])
    coefficients = [float(value) for value in meta["coefficients"]]
    intercept = float(meta["intercept"])
    scaler_mean = [float(value) for value in meta["scaler_mean"]]
    scaler_std = [float(value) for value in meta["scaler_std"]]

    if len(coefficients) != input_length:
        raise ValueError("Coefficient length mismatch with input_length")
    if len(scaler_mean) != input_length or len(scaler_std) != input_length:
        raise ValueError("Scaler length mismatch with input_length")

    mean = tf.constant(scaler_mean, dtype=tf.float32)
    std = tf.constant(scaler_std, dtype=tf.float32)
    coef = tf.constant(coefficients, dtype=tf.float32)
    bias = tf.constant(intercept, dtype=tf.float32)

    class ScoringMetaModule(tf.Module):
        @tf.function(input_signature=[tf.TensorSpec(shape=[None, input_length], dtype=tf.float32, name="meta_input")])
        def __call__(self, x):
            safe_std = tf.where(tf.equal(std, 0.0), tf.ones_like(std), std)
            standardized = (x - mean) / safe_std
            standardized = tf.where(tf.equal(std, 0.0), tf.zeros_like(standardized), standardized)
            linear = tf.linalg.matvec(standardized, coef) + bias
            prob = tf.math.sigmoid(linear)
            return tf.expand_dims(prob, axis=-1, name="meta_prob")

    module = ScoringMetaModule()
    concrete = module.__call__.get_concrete_function()

    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete], module)
    converter.experimental_enable_resource_variables = False
    tflite_model = converter.convert()

    return tflite_model, {
        "tensorflow_version": tf.__version__,
        "input_length": input_length,
    }


def _sha256_bytes(data: bytes) -> str:
    hasher = hashlib.sha256()
    hasher.update(data)
    return hasher.hexdigest()


def export_scoring_to_tflite(
    meta_coefficients_path: Path,
    output_path: Path,
    contract_path: Path,
    report_path: Path,
) -> None:
    meta = _load_meta_coefficients(meta_coefficients_path)
    tflite_bytes, build_meta = _build_tflite_model(meta)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(tflite_bytes)

    generated_at = datetime.now(timezone.utc).isoformat()
    sha256 = _sha256_bytes(tflite_bytes)
    size_bytes = output_path.stat().st_size

    contract = {
        "schema_version": "1.0",
        "generated_at": generated_at,
        "artifact": {
            "file_name": output_path.name,
            "relative_path": str(output_path.relative_to(ROOT.parent)),
            "sha256": sha256,
            "size_bytes": size_bytes,
            "model_name": "gigcredit_scoring_meta",
            "semantic_version": "1.0.0",
            "input_shape": [1, build_meta["input_length"]],
            "input_dtype": "float32",
            "output_schema": {
                "probability": "float32",
                "range": [0.0, 1.0],
            },
            "preprocessing_contract": {
                "source": "offline_ml/data/meta_coefficients.json",
                "standardization": "(x-mean)/std with std==0 -> 0",
            },
            "postprocessing_contract": {
                "probability_to_score": "score = clamp(round(300 + prob * 600), 300, 900)",
                "risk_bands": {
                    "high": [300, 450],
                    "medium": [451, 650],
                    "low": [651, 900],
                },
            },
            "runtime_compatibility": {
                "android": True,
                "ios": True,
            },
        },
    }

    contract_path.parent.mkdir(parents=True, exist_ok=True)
    with contract_path.open("w", encoding="utf-8") as file:
        json.dump(contract, file, indent=2)

    report = {
        "generated_at": generated_at,
        "status": "PASS",
        "meta_coefficients_path": str(meta_coefficients_path),
        "tflite_path": str(output_path),
        "contract_path": str(contract_path),
        "sha256": sha256,
        "size_bytes": size_bytes,
        "tensorflow_version": build_meta["tensorflow_version"],
        "input_length": build_meta["input_length"],
    }

    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Wrote scoring TFLite model: {output_path}")
    print(f"Wrote scoring TFLite contract: {contract_path}")
    print(f"Wrote scoring TFLite export report: {report_path}")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export scoring meta-learner to TFLite")
    parser.add_argument(
        "--meta-coefficients-path",
        type=Path,
        default=META_COEFFICIENTS_PATH,
        help="Path to meta_coefficients.json",
    )
    parser.add_argument(
        "--output-path",
        type=Path,
        default=DEFAULT_OUTPUT_PATH,
        help="Output path for scoring_model_v1.tflite",
    )
    parser.add_argument(
        "--contract-path",
        type=Path,
        default=SCORING_TFLITE_CONTRACT_PATH,
        help="Output path for scoring TFLite contract JSON",
    )
    parser.add_argument(
        "--report-path",
        type=Path,
        default=SCORING_TFLITE_EXPORT_REPORT_PATH,
        help="Output path for export report JSON",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    export_scoring_to_tflite(
        meta_coefficients_path=args.meta_coefficients_path,
        output_path=args.output_path,
        contract_path=args.contract_path,
        report_path=args.report_path,
    )


if __name__ == "__main__":
    main()

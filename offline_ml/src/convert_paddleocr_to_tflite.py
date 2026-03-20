"""Convert PaddleOCR Lite inference model to TensorFlow Lite.

Usage (convert Paddle inference files):
    python -m offline_ml.src.convert_paddleocr_to_tflite \
        --paddle-model-dir path/to/inference_model_dir \
        --output gigcredit_app/assets/models/ocr_model.tflite

Usage (already have PaddleOCR Lite TFLite):
    python -m offline_ml.src.convert_paddleocr_to_tflite \
        --ocr-tflite-source path/to/ocr_model.tflite \
        --output gigcredit_app/assets/models/ocr_model.tflite

Expected files inside --paddle-model-dir:
  - inference.pdmodel
  - inference.pdiparams

This script orchestrates external CLI tools:
  1) paddle2onnx
  2) onnxsim
  3) onnx2tf
  4) TensorFlow Lite conversion
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def _run(cmd: list[str], cwd: Path | None = None) -> None:
    print("[run]", " ".join(cmd))
    completed = subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"Command failed ({completed.returncode}): {' '.join(cmd)}")


def _require_cli(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(
            f"Missing required CLI: {name}. Install it and ensure it is on PATH."
        )


def convert_paddleocr_to_tflite(paddle_model_dir: Path, output_path: Path) -> Path:
    pdmodel = paddle_model_dir / "inference.pdmodel"
    pdparams = paddle_model_dir / "inference.pdiparams"

    if not pdmodel.exists() or not pdparams.exists():
        raise FileNotFoundError(
            "Paddle inference files not found. Expected inference.pdmodel and "
            "inference.pdiparams in --paddle-model-dir."
        )

    _require_cli("paddle2onnx")
    _require_cli("onnxsim")
    _require_cli("onnx2tf")

    with tempfile.TemporaryDirectory(prefix="gigcredit_ocr_convert_") as tmp:
        tmp_dir = Path(tmp)
        onnx_raw = tmp_dir / "ocr_raw.onnx"
        onnx_sim = tmp_dir / "ocr_sim.onnx"
        saved_model_dir = tmp_dir / "saved_model"

        _run(
            [
                "paddle2onnx",
                "--model_dir",
                str(paddle_model_dir),
                "--model_filename",
                "inference.pdmodel",
                "--params_filename",
                "inference.pdiparams",
                "--save_file",
                str(onnx_raw),
                "--opset_version",
                "11",
                "--enable_onnx_checker",
                "True",
            ]
        )

        _run(["onnxsim", str(onnx_raw), str(onnx_sim)])

        _run(
            [
                "onnx2tf",
                "-i",
                str(onnx_sim),
                "-o",
                str(saved_model_dir),
            ]
        )

        python_exe = sys.executable
        convert_snippet = (
            "import tensorflow as tf; "
            "conv=tf.lite.TFLiteConverter.from_saved_model(r'{}'); "
            "conv.optimizations=[tf.lite.Optimize.DEFAULT]; "
            "tfl=conv.convert(); "
            "open(r'{}','wb').write(tfl)"
        ).format(saved_model_dir.as_posix(), output_path.as_posix())
        _run([python_exe, "-c", convert_snippet])

    return output_path


def place_existing_tflite(source_tflite: Path, output_path: Path) -> Path:
    if not source_tflite.exists():
        raise FileNotFoundError(f"OCR TFLite source file not found: {source_tflite}")
    if source_tflite.suffix.lower() != ".tflite":
        raise ValueError(f"Expected a .tflite source file, got: {source_tflite.name}")
    shutil.copyfile(source_tflite, output_path)
    return output_path


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert PaddleOCR Lite model to TFLite.")
    parser.add_argument(
        "--paddle-model-dir",
        required=False,
        help="Directory containing inference.pdmodel and inference.pdiparams",
    )
    parser.add_argument(
        "--ocr-tflite-source",
        required=False,
        help="Existing OCR TFLite file path to copy into output location",
    )
    parser.add_argument(
        "--output",
        default="gigcredit_app/assets/models/ocr_model.tflite",
        help="Output TFLite file path",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    paddle_dir_arg = (args.paddle_model_dir or "").strip()
    source_tflite_arg = (args.ocr_tflite_source or "").strip()
    if not paddle_dir_arg and not source_tflite_arg:
        raise ValueError("Provide either --paddle-model-dir or --ocr-tflite-source.")

    if source_tflite_arg:
        out = place_existing_tflite(Path(source_tflite_arg).resolve(), output)
    else:
        model_dir = Path(paddle_dir_arg).resolve()
        out = convert_paddleocr_to_tflite(model_dir, output)

    print(f"[ok] wrote OCR TFLite model: {out}")


if __name__ == "__main__":
    main()

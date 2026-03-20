"""Verify on-device model bundle integrity for GigCredit APK assets.

Checks:
- required assets exist
- OCR and scoring model hashes are different
- runtime model contract requires runtime artifacts

Usage:
  python -m offline_ml.src.verify_ondevice_model_bundle
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = ROOT / "gigcredit_app" / "assets" / "models"
CONSTANTS_DIR = ROOT / "gigcredit_app" / "assets" / "constants"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def _require(path: Path, name: str) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required {name}: {path}")


def main() -> None:
    ocr = MODELS_DIR / "ocr_model.tflite"
    scoring = MODELS_DIR / "scoring_model.tflite"
    shap = CONSTANTS_DIR / "shap_lookup.json"
    contract = CONSTANTS_DIR / "runtime_model_contract.json"

    _require(ocr, "OCR model")
    _require(scoring, "scoring model")
    _require(shap, "SHAP lookup")
    _require(contract, "runtime model contract")

    with contract.open("r", encoding="utf-8") as f:
        contract_data = json.load(f)

    strategy = contract_data.get("runtime_strategy", {})
    if strategy.get("runtime_model_artifacts_required") is not True:
        raise RuntimeError("runtime_model_contract.json must set runtime_model_artifacts_required=true")

    ocr_hash = _sha256(ocr)
    scoring_hash = _sha256(scoring)
    if ocr_hash == scoring_hash:
        raise RuntimeError(
            "OCR and scoring model binaries are identical. "
            "Replace assets/models/ocr_model.tflite with real OCR model."
        )

    print("[ok] on-device model bundle integrity check passed")
    print(f"ocr_model.tflite sha256     : {ocr_hash}")
    print(f"scoring_model.tflite sha256 : {scoring_hash}")


if __name__ == "__main__":
    main()

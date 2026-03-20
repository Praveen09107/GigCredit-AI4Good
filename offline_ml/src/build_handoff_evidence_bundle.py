"""Build consolidated production handoff evidence bundle for PR/review."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .config import REAL_READY_EVAL_REPORT_PATH, ROOT

DEFAULT_HANDOFF_REPORT_PATH = ROOT / "data" / "runtime_model_handoff_report.json"
DEFAULT_MANIFEST_PATH = ROOT.parent / "gigcredit_app" / "assets" / "constants" / "artifact_manifest.json"
DEFAULT_OUTPUT_PATH = ROOT / "data" / "production_handoff_bundle.json"
DEFAULT_CONTRACT_PATH = ROOT / "data" / "runtime_model_contract.json"


def _sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def _load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")
    with path.open("r", encoding="utf-8") as file:
        payload = json.load(file)
    if not isinstance(payload, dict):
        raise ValueError(f"Expected object JSON root: {path}")
    return payload


def _runtime_file_evidence(runtime_models: dict[str, Any]) -> dict[str, Any]:
    evidence: dict[str, Any] = {}
    for artifact_name, metadata in runtime_models.items():
        if not isinstance(metadata, dict):
            raise ValueError(f"Invalid runtime model metadata: {artifact_name}")
        target = metadata.get("target")
        if not target:
            raise ValueError(f"Missing runtime model target in manifest entry: {artifact_name}")
        path = Path(target)
        if not path.exists():
            raise FileNotFoundError(f"Runtime model file missing on disk: {path}")
        evidence[artifact_name] = {
            "path": str(path),
            "size_bytes": path.stat().st_size,
            "sha256": _sha256_file(path),
            "manifest_sha256": metadata.get("sha256"),
            "sha256_match": metadata.get("sha256") == _sha256_file(path),
            "semantic_version": metadata.get("semantic_version"),
        }
    return evidence


def build_bundle(
    eval_report_path: Path,
    handoff_report_path: Path,
    manifest_path: Path,
    contract_path: Path,
    output_path: Path,
) -> None:
    eval_report = _load_json(eval_report_path)
    handoff_report = _load_json(handoff_report_path)
    manifest = _load_json(manifest_path)
    contract = _load_json(contract_path)

    runtime_models = manifest.get("runtime_models")
    runtime_strategy = contract.get("runtime_strategy") if isinstance(contract.get("runtime_strategy"), dict) else {}
    runtime_required = bool(runtime_strategy.get("runtime_model_artifacts_required", True))
    if "runtime_model_artifacts_required" in handoff_report:
        runtime_required = bool(handoff_report.get("runtime_model_artifacts_required"))

    if runtime_required:
        if not isinstance(runtime_models, dict) or not runtime_models:
            raise ValueError("Manifest has no runtime_models block")
        runtime_files = _runtime_file_evidence(runtime_models)
    else:
        runtime_models = runtime_models if isinstance(runtime_models, dict) else {}
        runtime_files = {}
    bundle = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generator": "offline_ml.src.build_handoff_evidence_bundle",
        "inputs": {
            "evaluation_report": str(eval_report_path),
            "runtime_handoff_report": str(handoff_report_path),
            "artifact_manifest": str(manifest_path),
        },
        "status_summary": {
            "production_gate_pass": bool(eval_report.get("production_gate", {}).get("pass")),
            "stress_gate_pass": bool(eval_report.get("stress_test", {}).get("gate", {}).get("pass")),
            "runtime_handoff_status": handoff_report.get("status"),
            "runtime_model_artifacts_required": runtime_required,
        },
        "runtime_strategy": runtime_strategy,
        "runtime_models": runtime_models,
        "runtime_files": runtime_files,
        "evaluation_excerpt": {
            "production_gate": eval_report.get("production_gate"),
            "stress_gate": eval_report.get("stress_test", {}).get("gate"),
            "test_metrics": eval_report.get("test_metrics"),
        },
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as file:
        json.dump(bundle, file, indent=2)

    print(f"Wrote production handoff bundle: {output_path}")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build production handoff evidence bundle.")
    parser.add_argument(
        "--eval-report-path",
        type=Path,
        default=REAL_READY_EVAL_REPORT_PATH,
        help="Path to evaluation report JSON.",
    )
    parser.add_argument(
        "--handoff-report-path",
        type=Path,
        default=DEFAULT_HANDOFF_REPORT_PATH,
        help="Path to runtime model handoff report JSON.",
    )
    parser.add_argument(
        "--manifest-path",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
        help="Path to artifact manifest JSON.",
    )
    parser.add_argument(
        "--contract-path",
        type=Path,
        default=DEFAULT_CONTRACT_PATH,
        help="Path to runtime model contract JSON.",
    )
    parser.add_argument(
        "--output-path",
        type=Path,
        default=DEFAULT_OUTPUT_PATH,
        help="Path to write evidence bundle JSON.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    build_bundle(
        eval_report_path=args.eval_report_path,
        handoff_report_path=args.handoff_report_path,
        manifest_path=args.manifest_path,
        contract_path=args.contract_path,
        output_path=args.output_path,
    )


if __name__ == "__main__":
    main()

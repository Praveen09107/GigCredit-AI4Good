"""Fail-fast production readiness gate for ML artifact handoff."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .config import REAL_READY_EVAL_REPORT_PATH, ROOT

DEFAULT_HANDOFF_REPORT_PATH = ROOT / "data" / "runtime_model_handoff_report.json"
DEFAULT_MANIFEST_PATH = ROOT.parent / "gigcredit_app" / "assets" / "constants" / "artifact_manifest.json"
DEFAULT_CONTRACT_PATH = ROOT / "data" / "runtime_model_contract.json"
DEFAULT_REQUIRED_MODELS = ["efficientnet_lite0.tflite", "mobilefacenet.tflite"]


def _load_json(path: Path) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")
    with path.open("r", encoding="utf-8") as file:
        payload = json.load(file)
    if not isinstance(payload, dict):
        raise ValueError(f"Invalid JSON root (must be object): {path}")
    return payload


def _assert_eval_gates(eval_report: dict) -> None:
    production_gate = eval_report.get("production_gate")
    stress_gate = eval_report.get("stress_test", {}).get("gate")

    if not isinstance(production_gate, dict) or production_gate.get("pass") is not True:
        raise RuntimeError("Production gate is not PASS in real_ready_evaluation_report.json")
    if not isinstance(stress_gate, dict) or stress_gate.get("pass") is not True:
        raise RuntimeError("Stress gate is not PASS in real_ready_evaluation_report.json")


def _assert_runtime_handoff(handoff_report: dict) -> None:
    if handoff_report.get("status") != "PASS":
        raise RuntimeError("Runtime model handoff report status is not PASS")


def _assert_manifest_runtime_models(manifest: dict, required_models: list[str]) -> None:
    runtime_models = manifest.get("runtime_models")
    if not isinstance(runtime_models, dict) or not runtime_models:
        raise RuntimeError("Manifest has no runtime_models block")

    for model_name in required_models:
        if model_name not in runtime_models:
            raise RuntimeError(f"Manifest missing required runtime model: {model_name}")
        metadata = runtime_models[model_name]
        if not isinstance(metadata, dict):
            raise RuntimeError(f"Invalid metadata for runtime model: {model_name}")
        if not metadata.get("sha256"):
            raise RuntimeError(f"Missing sha256 for runtime model: {model_name}")


def _resolve_runtime_required(contract: dict, handoff_report: dict) -> bool:
    runtime_strategy = contract.get("runtime_strategy")
    if isinstance(runtime_strategy, dict) and "runtime_model_artifacts_required" in runtime_strategy:
        return bool(runtime_strategy.get("runtime_model_artifacts_required"))
    if "runtime_model_artifacts_required" in handoff_report:
        return bool(handoff_report.get("runtime_model_artifacts_required"))
    return True


def check_production_readiness(
    eval_report_path: Path,
    handoff_report_path: Path,
    manifest_path: Path,
    required_models: list[str] | None,
    contract_path: Path,
) -> None:
    eval_report = _load_json(eval_report_path)
    handoff_report = _load_json(handoff_report_path)
    manifest = _load_json(manifest_path)
    contract = _load_json(contract_path)

    _assert_eval_gates(eval_report)
    _assert_runtime_handoff(handoff_report)

    runtime_required = _resolve_runtime_required(contract, handoff_report)
    resolved_required_models = required_models
    if resolved_required_models is None:
        resolved_required_models = list(DEFAULT_REQUIRED_MODELS) if runtime_required else []

    if runtime_required:
        _assert_manifest_runtime_models(manifest, resolved_required_models)

    print("PASS: production readiness gate satisfied")
    print(f"- evaluation report: {eval_report_path}")
    print(f"- runtime handoff report: {handoff_report_path}")
    print(f"- manifest: {manifest_path}")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check production readiness gate for runtime model handoff."
    )
    parser.add_argument(
        "--eval-report-path",
        type=Path,
        default=REAL_READY_EVAL_REPORT_PATH,
        help="Path to real-ready evaluation report.",
    )
    parser.add_argument(
        "--handoff-report-path",
        type=Path,
        default=DEFAULT_HANDOFF_REPORT_PATH,
        help="Path to runtime handoff report.",
    )
    parser.add_argument(
        "--manifest-path",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
        help="Path to app artifact manifest.",
    )
    parser.add_argument(
        "--contract-path",
        type=Path,
        default=DEFAULT_CONTRACT_PATH,
        help="Path to runtime model contract JSON.",
    )
    parser.add_argument(
        "--require-runtime-model",
        action="append",
        default=None,
        help="Required runtime model filename. Can be repeated.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    required_models = args.require_runtime_model if args.require_runtime_model else None
    check_production_readiness(
        eval_report_path=args.eval_report_path,
        handoff_report_path=args.handoff_report_path,
        manifest_path=args.manifest_path,
        required_models=required_models,
        contract_path=args.contract_path,
    )


if __name__ == "__main__":
    main()

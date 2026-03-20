"""Validate and package runtime model artifacts into app manifest with checksums."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .config import ROOT

APP_ROOT = ROOT.parent / "gigcredit_app"
DEFAULT_MODELS_DIR = APP_ROOT / "assets" / "models"
DEFAULT_MANIFEST_PATH = APP_ROOT / "assets" / "constants" / "artifact_manifest.json"
DEFAULT_CONTRACT_PATH = ROOT / "data" / "runtime_model_contract.json"
DEFAULT_REPORT_PATH = ROOT / "data" / "runtime_model_handoff_report.json"
DEFAULT_REQUIRED = ["efficientnet_lite0.tflite", "mobilefacenet.tflite"]

REQUIRED_META_FIELDS = {
    "model_name",
    "semantic_version",
    "input_shape",
    "input_dtype",
    "output_schema",
    "preprocessing_contract",
    "postprocessing_thresholds",
    "runtime_compatibility",
}


def _sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def _require_dict(value: Any, field_name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{field_name} must be an object")
    return value


def _validate_runtime_compatibility(value: Any, artifact_name: str) -> dict[str, Any]:
    compatibility = _require_dict(value, f"{artifact_name}.runtime_compatibility")
    for platform in ("android", "ios"):
        if platform not in compatibility:
            raise ValueError(f"{artifact_name}.runtime_compatibility missing '{platform}'")
    return compatibility


def _validate_artifact_meta(artifact_name: str, metadata: Any) -> dict[str, Any]:
    artifact_meta = _require_dict(metadata, f"artifacts.{artifact_name}")
    missing_fields = sorted(REQUIRED_META_FIELDS - set(artifact_meta.keys()))
    if missing_fields:
        raise ValueError(f"{artifact_name} missing required fields: {', '.join(missing_fields)}")

    artifact_meta["runtime_compatibility"] = _validate_runtime_compatibility(
        artifact_meta["runtime_compatibility"],
        artifact_name,
    )
    return artifact_meta


def _load_contract(contract_path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    if not contract_path.exists():
        raise FileNotFoundError(
            f"Runtime contract not found: {contract_path}. "
            "Create it from runtime_model_contract.template.json."
        )
    with contract_path.open("r", encoding="utf-8") as file:
        contract = json.load(file)
    if not isinstance(contract, dict):
        raise ValueError("Contract root must be a JSON object")
    runtime_strategy = contract.get("runtime_strategy")
    if runtime_strategy is None:
        runtime_strategy = {}
    runtime_strategy = _require_dict(runtime_strategy, "contract.runtime_strategy")
    artifacts = contract.get("artifacts")
    if artifacts is None:
        artifacts = {}
    artifacts = _require_dict(artifacts, "contract.artifacts")
    return runtime_strategy, artifacts


def _load_existing_manifest(manifest_path: Path) -> dict[str, Any]:
    if manifest_path.exists():
        with manifest_path.open("r", encoding="utf-8") as file:
            manifest = json.load(file)
        if not isinstance(manifest, dict):
            raise ValueError(f"Manifest root must be object: {manifest_path}")
        return manifest
    return {}


def _build_runtime_entry(
    artifact_name: str,
    metadata: dict[str, Any],
    model_path: Path,
) -> dict[str, Any]:
    entry = {
        "file_name": artifact_name,
        "target": str(model_path),
        "sha256": _sha256_file(model_path),
        "size_bytes": model_path.stat().st_size,
    }
    entry.update(metadata)
    return entry


def package_runtime_models(
    contract_path: Path,
    models_dir: Path,
    manifest_path: Path,
    report_path: Path,
    required_artifacts: list[str] | None,
) -> None:
    runtime_strategy, artifacts = _load_contract(contract_path)
    runtime_model_artifacts_required = bool(runtime_strategy.get("runtime_model_artifacts_required", True))

    required_list = required_artifacts
    if required_list is None:
        required_list = list(DEFAULT_REQUIRED) if runtime_model_artifacts_required else []

    for required in required_list:
        if required not in artifacts:
            raise ValueError(f"Missing required runtime artifact in contract: {required}")

    if runtime_model_artifacts_required and not artifacts:
        raise ValueError("Contract marks runtime model artifacts as required, but artifacts map is empty")

    packaged: dict[str, dict[str, Any]] = {}
    for artifact_name, raw_metadata in artifacts.items():
        metadata = _validate_artifact_meta(artifact_name, raw_metadata)
        model_path = models_dir / artifact_name
        if not model_path.exists():
            raise FileNotFoundError(f"Runtime model file not found: {model_path}")
        packaged[artifact_name] = _build_runtime_entry(artifact_name, metadata, model_path)

    manifest = _load_existing_manifest(manifest_path)
    generated_at = datetime.now(timezone.utc).isoformat()
    manifest["runtime_models_generated_at"] = generated_at
    manifest["runtime_models_generator"] = "offline_ml.src.package_runtime_models_for_app"
    manifest["runtime_model_artifacts_required"] = runtime_model_artifacts_required
    manifest["runtime_strategy"] = runtime_strategy
    manifest["runtime_models"] = packaged

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with manifest_path.open("w", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2)

    report = {
        "generated_at": generated_at,
        "generator": "offline_ml.src.package_runtime_models_for_app",
        "contract_path": str(contract_path),
        "models_dir": str(models_dir),
        "manifest_path": str(manifest_path),
        "required_artifacts": required_artifacts,
        "runtime_model_artifacts_required": runtime_model_artifacts_required,
        "runtime_strategy": runtime_strategy,
        "packaged_count": len(packaged),
        "packaged_artifacts": {
            name: {
                "target": details["target"],
                "sha256": details["sha256"],
                "size_bytes": details["size_bytes"],
                "semantic_version": details.get("semantic_version"),
            }
            for name, details in packaged.items()
        },
        "status": "PASS",
    }

    report_path.parent.mkdir(parents=True, exist_ok=True)
    with report_path.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Updated runtime models in manifest: {manifest_path}")
    print(f"Wrote runtime handoff report: {report_path}")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate runtime model artifacts and write runtime entries to app manifest."
    )
    parser.add_argument(
        "--contract-path",
        type=Path,
        default=DEFAULT_CONTRACT_PATH,
        help="Path to runtime model contract JSON.",
    )
    parser.add_argument(
        "--models-dir",
        type=Path,
        default=DEFAULT_MODELS_DIR,
        help="Directory containing runtime model files.",
    )
    parser.add_argument(
        "--manifest-path",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
        help="Path to app artifact manifest JSON.",
    )
    parser.add_argument(
        "--report-path",
        type=Path,
        default=DEFAULT_REPORT_PATH,
        help="Path to write runtime handoff report JSON.",
    )
    parser.add_argument(
        "--require-artifact",
        action="append",
        default=None,
        help="Required runtime artifact file name. Can be repeated.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    required_artifacts = args.require_artifact if args.require_artifact else None
    package_runtime_models(
        contract_path=args.contract_path,
        models_dir=args.models_dir,
        manifest_path=args.manifest_path,
        report_path=args.report_path,
        required_artifacts=required_artifacts,
    )


if __name__ == "__main__":
    main()

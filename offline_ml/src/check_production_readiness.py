"""Compatibility production-readiness checker for Dev B integration runbook."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from .config import ROOT

APP_ROOT = ROOT.parent / "gigcredit_app"
CONSTANTS_DIR = APP_ROOT / "assets" / "constants"
REPORT_PATH = ROOT / "data" / "production_readiness_report.json"


def _load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def main() -> None:
    contract_path = CONSTANTS_DIR / "runtime_model_contract.json"
    manifest_path = CONSTANTS_DIR / "artifact_manifest.json"

    checks: list[dict[str, object]] = []

    contract_exists = contract_path.exists()
    checks.append(
        {
            "name": "runtime_model_contract_present",
            "pass": contract_exists,
            "detail": str(contract_path),
        }
    )

    manifest_exists = manifest_path.exists()
    checks.append(
        {
            "name": "artifact_manifest_present",
            "pass": manifest_exists,
            "detail": str(manifest_path),
        }
    )

    contract = _load_json(contract_path) if contract_exists else {}
    manifest = _load_json(manifest_path) if manifest_exists else {}

    required_flag_contract = (
        contract.get("runtime_strategy", {}).get("runtime_model_artifacts_required") is False
    )
    checks.append(
        {
            "name": "runtime_contract_requires_models",
            "pass": required_flag_contract,
            "detail": "runtime_strategy.runtime_model_artifacts_required == false",
        }
    )

    required_flag_manifest = (
        manifest.get("runtime_strategy", {}).get("runtime_model_artifacts_required") is False
    )
    checks.append(
        {
            "name": "manifest_requires_models",
            "pass": required_flag_manifest,
            "detail": "artifact_manifest.runtime_strategy.runtime_model_artifacts_required == false",
        }
    )

    runtime_models_manifest = manifest.get("runtime_models", {}) if isinstance(manifest, dict) else {}
    checks.append(
        {
            "name": "runtime_models_manifest_empty",
            "pass": isinstance(runtime_models_manifest, dict) and len(runtime_models_manifest) == 0,
            "detail": "runtime_models should be empty when external authenticity/face models are not required",
        }
    )

    passed = all(bool(item["pass"]) for item in checks)
    result = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "result": "PASS" if passed else "FAIL",
        "checks": checks,
    }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with REPORT_PATH.open("w", encoding="utf-8") as file:
        json.dump(result, file, indent=2)

    print(f"Wrote production readiness report: {REPORT_PATH}")
    print(f"Result: {result['result']}")

    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

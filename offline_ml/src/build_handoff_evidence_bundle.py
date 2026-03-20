"""Build Dev B handoff evidence bundle for runtime integration checks."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from .config import REAL_READY_EVAL_REPORT_PATH, ROOT

DATA_DIR = ROOT / "data"
APP_CONSTANTS = ROOT.parent / "gigcredit_app" / "assets" / "constants"
BUNDLE_PATH = DATA_DIR / "handoff_evidence_bundle.json"


def _read_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def main() -> None:
    production_report = _read_json(DATA_DIR / "production_readiness_report.json")
    real_ready_report = _read_json(REAL_READY_EVAL_REPORT_PATH)
    artifact_manifest = _read_json(APP_CONSTANTS / "artifact_manifest.json")
    runtime_contract = _read_json(APP_CONSTANTS / "runtime_model_contract.json")

    bundle = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generator": "offline_ml.src.build_handoff_evidence_bundle",
        "evidence": {
            "production_readiness_report": production_report,
            "real_ready_evaluation_report": real_ready_report,
            "artifact_manifest": artifact_manifest,
            "runtime_model_contract": runtime_contract,
        },
    }

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with BUNDLE_PATH.open("w", encoding="utf-8") as file:
        json.dump(bundle, file, indent=2)

    print(f"Wrote handoff evidence bundle: {BUNDLE_PATH}")


if __name__ == "__main__":
    main()

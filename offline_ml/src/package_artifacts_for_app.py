"""Package offline ML artifacts into Flutter app runtime paths with checksums."""

from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

from .config import (
    FEATURE_MEANS_PATH,
    META_COEFFICIENTS_PATH,
    OUTPUT_DART_FILES,
    ROOT,
    SHAP_LOOKUP_PATH,
    STATE_INCOME_ANCHORS_PATH,
)

APP_ROOT = ROOT.parent / "gigcredit_app"
TARGET_SCORING_DIR = APP_ROOT / "lib" / "scoring" / "generated"
TARGET_CONSTANTS_DIR = APP_ROOT / "assets" / "constants"
MANIFEST_PATH = TARGET_CONSTANTS_DIR / "artifact_manifest.json"
RUNTIME_CONTRACT_PATH = TARGET_CONSTANTS_DIR / "runtime_model_contract.json"


def _sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def _copy_file(src: Path, dst: Path) -> dict[str, str | int]:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "source": str(src),
        "target": str(dst),
        "sha256": _sha256_file(dst),
        "size_bytes": dst.stat().st_size,
    }


def main() -> None:
    if not APP_ROOT.exists():
        raise FileNotFoundError(f"Flutter app root not found: {APP_ROOT}")

    copied: dict[str, dict[str, str | int]] = {}

    for key, src in OUTPUT_DART_FILES.items():
        if not src.exists():
            raise FileNotFoundError(f"Missing scorer artifact: {src}")
        target = TARGET_SCORING_DIR / src.name
        copied[f"scorer_{key}"] = _copy_file(src, target)

    constants = {
        "meta_coefficients": META_COEFFICIENTS_PATH,
        "shap_lookup": SHAP_LOOKUP_PATH,
        "state_income_anchors": STATE_INCOME_ANCHORS_PATH,
        "feature_means": FEATURE_MEANS_PATH,
    }
    for key, src in constants.items():
        if not src.exists():
            raise FileNotFoundError(f"Missing constants artifact: {src}")
        target = TARGET_CONSTANTS_DIR / src.name
        copied[key] = _copy_file(src, target)

    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generator": "offline_ml.src.package_artifacts_for_app",
        "runtime_strategy": {
            "runtime_model_artifacts_required": False,
        },
        "runtime_models": {},
        "artifacts": copied,
    }
    TARGET_CONSTANTS_DIR.mkdir(parents=True, exist_ok=True)
    with MANIFEST_PATH.open("w", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2)

    runtime_contract = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "generator": "offline_ml.src.package_artifacts_for_app",
        "runtime_strategy": {
            "runtime_model_artifacts_required": False,
        },
        "required_models": {},
    }
    with RUNTIME_CONTRACT_PATH.open("w", encoding="utf-8") as file:
        json.dump(runtime_contract, file, indent=2)

    print(f"Packaged artifacts into: {TARGET_SCORING_DIR}")
    print(f"Packaged constants into: {TARGET_CONSTANTS_DIR}")
    print(f"Manifest: {MANIFEST_PATH}")
    print(f"Runtime contract: {RUNTIME_CONTRACT_PATH}")


if __name__ == "__main__":
    main()

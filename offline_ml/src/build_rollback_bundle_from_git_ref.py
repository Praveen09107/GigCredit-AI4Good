"""Build an N-1 rollback artifact bundle from a git reference."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from .config import ROOT


REPO_ROOT = ROOT.parent
DATA_DIR = ROOT / "data"
ROLLBACK_DIR = DATA_DIR / "rollback_bundle_n_minus_1"
ROLLBACK_MANIFEST = DATA_DIR / "rollback_bundle_manifest_n_minus_1.json"

ARTIFACT_PATHS = [
    "gigcredit_app/lib/scoring/generated/p1_scorer.dart",
    "gigcredit_app/lib/scoring/generated/p2_scorer.dart",
    "gigcredit_app/lib/scoring/generated/p3_scorer.dart",
    "gigcredit_app/lib/scoring/generated/p4_scorer.dart",
    "gigcredit_app/lib/scoring/generated/p6_scorer.dart",
    "gigcredit_app/assets/constants/meta_coefficients.json",
    "gigcredit_app/assets/constants/shap_lookup.json",
    "gigcredit_app/assets/constants/state_income_anchors.json",
    "gigcredit_app/assets/constants/feature_means.json",
    "gigcredit_app/assets/constants/artifact_manifest.json",
]


def _sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def _git_show(ref: str, rel_path: str) -> bytes:
    result = subprocess.run(
        ["git", "show", f"{ref}:{rel_path}"],
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise FileNotFoundError(rel_path)
    return result.stdout


def build_rollback_bundle(ref: str) -> None:
    ROLLBACK_DIR.mkdir(parents=True, exist_ok=True)

    copied: list[dict[str, object]] = []
    missing: list[str] = []
    for rel_path in ARTIFACT_PATHS:
        try:
            content = _git_show(ref, rel_path)
        except FileNotFoundError:
            missing.append(rel_path)
            continue

        destination = ROLLBACK_DIR / rel_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)

        copied.append(
            {
                "path": rel_path,
                "target": str(destination),
                "size_bytes": destination.stat().st_size,
                "sha256": _sha256(destination),
            }
        )

    payload = {
        "schema_version": "1.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_ref": ref,
        "status": "PASS" if not missing else "PARTIAL",
        "copied_count": len(copied),
        "missing_count": len(missing),
        "artifacts": copied,
        "missing_artifacts": missing,
    }
    ROLLBACK_MANIFEST.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    print(f"Wrote rollback manifest: {ROLLBACK_MANIFEST}")
    print(f"Rollback bundle root: {ROLLBACK_DIR}")
    print(f"Status: {payload['status']} | copied={len(copied)} missing={len(missing)}")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build N-1 rollback artifacts from git ref")
    parser.add_argument("--ref", default="HEAD~1", help="Git ref to extract rollback artifacts from")
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    build_rollback_bundle(args.ref)


if __name__ == "__main__":
    main()

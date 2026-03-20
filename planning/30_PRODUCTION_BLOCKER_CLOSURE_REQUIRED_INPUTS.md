# 30) Production Blocker Closure — Required External Inputs

Last Updated: 2026-03-20

Status summary:
- Resolved: rollback N-1 bundle
- Resolved: Flutter analyze/full test evidence
- Remaining blockers require external assets/environment

Related plan:
- `planning/32_DEV_A_SCORING_TFLITE_EXPORT_AND_PARITY_EXECUTION_PLAN.md` (Dev A plan for scoring-model TFLite export + contract + parity evidence)

## Blocker 1: Runtime model binaries missing

Required files (exact names):
- `gigcredit_app/assets/models/efficientnet_lite0.tflite`
- `gigcredit_app/assets/models/mobilefacenet.tflite`

What to do once files are provided:
1. Copy files to `gigcredit_app/assets/models/`
2. Set runtime contract required mode:
   - update `offline_ml/data/runtime_model_contract.json`
   - set `runtime_strategy.runtime_model_artifacts_required` to `true`
3. Run:
   - `python -m offline_ml.src.package_runtime_models_for_app`
   - `python -m offline_ml.src.check_production_readiness`
   - `python -m offline_ml.src.build_handoff_evidence_bundle`

Acceptance:
- `runtime_model_handoff_report.json` status = PASS
- `artifact_manifest.json` includes runtime model entries with SHA256
- startup health capability flags report availability in strict mode

## Blocker 2: Deployed backend + QA production evidence pending

Required external inputs:
- Final deployed backend base URL
- Production/staging env credentials and headers
- QA device-run evidence pack (screens/logs) for E2E and report flow

What to do once URL/access is provided:
1. Set app backend URL env:
   - `GIGCREDIT_BACKEND_BASE_URL=<deployed_url>`
2. Run deployed contract smoke + auth/rate-limit checks.
3. Run physical-device flow and capture:
   - OCR/authenticity/face smoke
   - report generation output from deployed backend

Acceptance:
- Checklist rows E1, E3, F5, F6 marked PASS with attached evidence.

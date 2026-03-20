# 25) Dev A Integration Release Notes (for Dev B)

Last Updated: 2026-03-20  
Release Tag: `dev-a-handoff-2026-03-20`

## 1) What changed vs previous artifact set

- Rebuilt/packaged scorer artifacts and constants via production handoff flow.
- Generated deterministic handoff evidence pack for Dev B validation:
  - `offline_ml/data/scoring_release_metadata.json`
  - `offline_ml/data/golden_inference_pack.json`
  - `offline_ml/data/shap_golden_examples.json`
  - `offline_ml/data/feature_contract_freeze.json`
  - `offline_ml/data/scoring_tolerance_policy.json`
  - `offline_ml/data/report_payload_contract.json`
- Regenerated SHAP lookup from offline pipeline:
  - `offline_ml/data/shap_lookup.json`

## 2) Known limitations

- Runtime authenticity/face model binaries are deferred in current mode:
  - `offline_ml/data/runtime_model_contract.json` has `runtime_model_artifacts_required=false`.
- Flutter analyze/test workaround applied and verified:
  - Added `dependency_overrides: objective_c: 6.0.0` in `gigcredit_app/pubspec.yaml`
  - Use no-space mirror path for checks: `D:\GigCreditProdReady\gigcredit_app`
- N-1 rollback artifact bundle is not available in current repository snapshot.

## 3) Rollback instructions

Primary rollback approach:
1. Checkout previous stable git tag/commit.
2. Restore previous artifact files under:
   - `gigcredit_app/lib/scoring/generated/`
   - `gigcredit_app/assets/constants/`
3. Re-run artifact validation:
   - `python -m offline_ml.src.validate_export`
4. Rebuild handoff evidence:
   - `python -m offline_ml.src.build_handoff_evidence_bundle`

Current N-1 status tracking file:
- `offline_ml/data/rollback_bundle_manifest_n_minus_1.json`

Current N-1 bundle output:
- `offline_ml/data/rollback_bundle_n_minus_1/` (built from git ref `HEAD~1`)

## 4) Compatibility matrix

| Component | Version / Mode | Notes |
|---|---|---|
| App scoring artifacts | 1.0.0 | From `offline_ml/data/scoring_release_metadata.json` |
| Meta input contract | 44 fixed | `offline_ml/data/meta_coefficients.json` |
| Feature contract | 95 fixed | `offline_ml/data/feature_contract_freeze.json` |
| SHAP contract | schema `1.0` | `offline_ml/data/shap_lookup.json` |
| Runtime model mode | Deferred | `runtime_model_artifacts_required=false` |
| Backend report contract | Frozen in doc | `offline_ml/data/report_payload_contract.json` |

## 5) Dev B immediate integration actions

1. Pull latest main and verify gate artifacts.
2. Validate scoring determinism using `offline_ml/data/golden_inference_pack.json`.
3. Validate SHAP runtime parity using `offline_ml/data/shap_golden_examples.json`.
4. Follow checklist in `planning/24_DEV_A_TO_DEV_B_PRODUCTION_HANDOFF_SIGNOFF_CHECKLIST.md`.

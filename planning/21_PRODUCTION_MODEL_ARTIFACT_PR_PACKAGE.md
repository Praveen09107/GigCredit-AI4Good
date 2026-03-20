# 21) Production Model Artifact Handoff PR Package

Use this file as the PR body template for artifact handoff.

PR title:

Production Model Artifact Handoff - Runtime Ready

## PR Body (copy/paste)

```markdown
## Summary
Final runtime-ready model artifact handoff for strict production mode integration.

## Artifact Files
- gigcredit_app/assets/models/efficientnet_lite0.tflite
- gigcredit_app/assets/models/mobilefacenet.tflite
- [add OCR runtime files only if OCR strategy != ML Kit]

## Runtime Contract
- offline_ml/data/runtime_model_contract.json
- Confirmed strategy:
  - ocr_runtime: mlkit_text_recognition (or fill actual final)

## Manifest Update
- gigcredit_app/assets/constants/artifact_manifest.json
- Updated runtime_models entries with:
  - model_name
  - semantic_version
  - sha256
  - input_shape
  - input_dtype
  - output_schema
  - preprocessing_contract
  - postprocessing_thresholds
  - runtime_compatibility

## Checksums
| Artifact | SHA256 |
|---|---|
| efficientnet_lite0.tflite | <fill> |
| mobilefacenet.tflite | <fill> |
| <ocr file if applicable> | <fill> |

## Export Environment
- Python version: <fill>
- ML framework versions: <fill>
- Export pipeline/version: <fill>
- Quantization settings: <fill>
- Calibration dataset policy: <fill>

## Gate Evidence
- real_ready_evaluation_report: offline_ml/data/real_ready_evaluation_report.json
- runtime_model_handoff_report: offline_ml/data/runtime_model_handoff_report.json
- production_handoff_bundle: offline_ml/data/production_handoff_bundle.json

## Runtime Loader Mapping
- planning/20_RUNTIME_LOADER_MAPPING_ANDROID_IOS.md

## Required Checklist
- [ ] Artifacts committed under gigcredit_app/assets/models
- [ ] Manifest runtime_models updated in gigcredit_app/assets/constants/artifact_manifest.json
- [ ] SHA256 values documented and match files
- [ ] Android/iOS loader mapping verified
- [ ] Strict startup health reports runtime capabilities available
- [ ] No heuristic fallback in strict mode
- [ ] On-device smoke evidence attached (OCR/authenticity/face-match)
- [ ] Dev B revalidation results attached post-pull
```

## Command sequence to generate PR evidence

1) Run runtime packaging:

- `python -m offline_ml.src.package_runtime_models_for_app`

2) Run strict gate:

- `python -m offline_ml.src.check_production_readiness`

3) Build evidence bundle:

- `python -m offline_ml.src.build_handoff_evidence_bundle`

4) Optional one-command workflow:

- `powershell -ExecutionPolicy Bypass -File offline_ml/scripts/run_production_handoff.ps1 -SkipTraining`

## Current blocker note (when binaries not present)

If `gigcredit_app/assets/models/` does not yet contain required `.tflite` files, do not open this PR as runtime-ready.

# 19) ML Owner Production Artifact Runbook (Runtime-Ready Handoff to Dev B)

Audience: ML owner (you), Dev B, release owner  
Objective: Deliver final runtime-ready model artifacts so strict production mode passes without fallback.

---

## 1) Scope and release gate

This runbook is the **production** path (no shortcuts).
A handoff is complete only when all are true:

1. Real runtime binaries are committed under `gigcredit_app/assets/models/`.
2. `gigcredit_app/assets/constants/artifact_manifest.json` is updated with full metadata + checksums.
3. Strict startup health reports required model/runtime availability.
4. No heuristic fallback is used in strict mode.
5. On-device smoke passes for OCR, authenticity, and face-match.

---

## 2) Runtime contract freeze (must do first)

### 2.1 Required artifact names

- `gigcredit_app/assets/models/efficientnet_lite0.tflite`
- `gigcredit_app/assets/models/mobilefacenet.tflite`
- OCR artifacts:
  - If ML Kit OCR: ensure native dependency/runtime path is finalized.
  - If Paddle OCR: commit complete deployable OCR runtime files and document exact loader mapping.

### 2.2 Contract fields to freeze per artifact

- `model_name`
- `semantic_version`
- `sha256`
- `input_shape`
- `input_dtype`
- `output_schema`
- `preprocessing_contract`
- `postprocessing_thresholds`
- `runtime_compatibility` (`android`, `ios`)

### 2.3 Cross-check runtime expectations

- Android runtime checks and model asset names:  
  `gigcredit_app/android/app/src/main/kotlin/com/gigcredit/app/MainActivity.kt`
- Strict startup gate logic:  
  `gigcredit_app/lib/state/startup_self_check_provider.dart`

---

## 3) Production ML build pipeline (repo commands)

Run from repo root.

```powershell
# 0) Activate Python env (if needed)
.\.venv\Scripts\Activate.ps1

# 1) Train/finalize pillar models
python -m offline_ml.src.train_final

# 2) Train/finalize meta learner
python -m offline_ml.src.train_meta_learner

# 3) Evaluate production readiness
python -m offline_ml.src.evaluate_real_ready

# 4) Validate exported logic parity (python-level export validation)
python -m offline_ml.src.validate_export

# 5) Export scorer Dart artifacts
python -m offline_ml.src.export_to_dart

# 6) Package scorer/constants into app + generate manifest
python -m offline_ml.src.package_artifacts_for_app
```

One-command orchestration (recommended once contract is filled):

```powershell
powershell -ExecutionPolicy Bypass -File offline_ml/scripts/run_production_handoff.ps1
```

### 3.1 Required reports after this stage

- `offline_ml/data/training_report.json`
- `offline_ml/data/meta_training_report.json`
- `offline_ml/data/real_ready_evaluation_report.json`
- `offline_ml/data/validation_report.json`

### 3.2 Gate from evaluation report

In `offline_ml/data/real_ready_evaluation_report.json`:

- `production_gate.pass` must be `true`
- `stress_test.gate.pass` must be `true` for full production signoff

If stress gate fails, fix data/model robustness first and rerun this section.

---

## 4) Runtime binary export (external to current repo scripts)

Important: this repo currently contains training/export scripts for scorer + constants, but no built-in script that emits final `.tflite` authenticity/face binaries or Paddle runtime package.

You must run your model-framework export pipeline and produce:

- `efficientnet_lite0.tflite`
- `mobilefacenet.tflite`
- OCR runtime assets (if Paddle OCR is final)

Then copy outputs into:

- `gigcredit_app/assets/models/`

Also capture:

- export framework/tool versions
- export command(s)
- quantization settings
- representative calibration dataset policy

---

## 5) Manifest update and checksums

Update `gigcredit_app/assets/constants/artifact_manifest.json` with runtime model entries and required contract fields.

Compute checksums:

```powershell
Get-FileHash gigcredit_app/assets/models/efficientnet_lite0.tflite -Algorithm SHA256
Get-FileHash gigcredit_app/assets/models/mobilefacenet.tflite -Algorithm SHA256
# Add Get-FileHash commands for each OCR runtime artifact if Paddle OCR is final
```

Paste these hashes into manifest and PR checksum table.

---

## 6) Runtime readiness validation (strict mode)

### 6.1 Strict gate checks

Must confirm on device/runtime:

- OCR runtime availability = true
- TFLite runtime availability = true
- Authenticity model availability = true
- Face model availability = true

### 6.2 No-fallback verification

In strict production mode, any missing runtime/model capability must fail startup gate (not silently fallback).

### 6.3 On-device smoke evidence required

Attach evidence for:

- OCR path
- Authenticity path
- Face-match path

For each path include:

- input sample id
- output summary
- latency snapshot
- pass/fail

---

## 7) PR creation (copy-paste template)

PR title:

`Production Model Artifact Handoff - Runtime Ready`

PR description template:

```markdown
## Summary
Deliver final production runtime model artifacts for Dev B integration and strict-mode signoff.

## Artifacts Added
- gigcredit_app/assets/models/efficientnet_lite0.tflite
- gigcredit_app/assets/models/mobilefacenet.tflite
- [list OCR runtime files if Paddle OCR is final]

## Manifest Updated
- gigcredit_app/assets/constants/artifact_manifest.json
- Added fields per artifact:
  - model_name
  - semantic_version
  - sha256
  - input_shape/input_dtype
  - output_schema
  - preprocessing_contract
  - postprocessing_thresholds
  - runtime_compatibility (android/ios)

## Checksum Table
| Artifact | SHA256 |
|---|---|
| efficientnet_lite0.tflite | <fill> |
| mobilefacenet.tflite | <fill> |
| <ocr file> | <fill> |

## Export Environment
- Framework/tool versions: <fill>
- Export commands: <fill>
- Quantization settings: <fill>
- Calibration dataset policy: <fill>

## Validation Evidence
- Strict startup health: <attach logs/screenshots>
- No heuristic fallback in strict mode: <attach logs>
- On-device smoke:
  - OCR: <evidence>
  - Authenticity: <evidence>
  - Face-match: <evidence>

## Checklist
- [ ] Artifacts committed under gigcredit_app/assets/models
- [ ] Manifest updated in gigcredit_app/assets/constants/artifact_manifest.json
- [ ] SHA256 values documented and match committed files
- [ ] Native loader mapping documented for Android and iOS
- [ ] Strict mode runtime health reports model availability
- [ ] No heuristic fallback triggered in strict production mode
- [ ] On-device smoke evidence attached (OCR/authenticity/face-match)
- [ ] Dev B revalidation results attached after pull
```

---

## 8) Handoff instruction to Dev B (copy-paste)

```text
Please pull latest main and validate runtime integration against this artifact PR.

Required checks:
1) strict startup health passes with model/runtime availability
2) no heuristic fallback in strict mode
3) OCR/authenticity/face-match on-device smoke passes

Please attach revalidation report with logs/screenshots and any blockers.
```

---

## 9) Final DoD (cannot close without all)

- Runtime binaries in `gigcredit_app/assets/models/`
- Manifest complete and checksum-verified
- Strict mode passes with no fallback
- Dev B confirms integration pull + smoke pass
- Release owner signs off on attached evidence

Evidence bundle output to attach in PR:

- `offline_ml/data/production_handoff_bundle.json`

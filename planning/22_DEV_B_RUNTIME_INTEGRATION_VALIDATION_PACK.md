# 22) Dev B Runtime Integration Validation Pack

Purpose: post-pull validation checklist for Dev B after artifact handoff PR is merged.

## 1) Pull latest

- `git fetch origin`
- `git checkout main`
- `git pull --ff-only origin main`

## 2) Validate runtime files and manifest

- Confirm files exist:
  - `gigcredit_app/assets/models/efficientnet_lite0.tflite`
  - `gigcredit_app/assets/models/mobilefacenet.tflite`
- Confirm manifest contains `runtime_models` block:
  - `gigcredit_app/assets/constants/artifact_manifest.json`

## 3) Validate ML gate artifacts

- `python -m offline_ml.src.check_production_readiness`
- Expect PASS

## 4) Validate app startup strict gate behavior

Required capabilities at runtime health:
- `ocrRuntimeAvailable = true`
- `tfliteRuntimeAvailable = true`
- `authenticityModelAvailable = true`
- `faceModelAvailable = true`

## 5) Validate no-fallback and smoke flows

Attach evidence for:
- OCR flow
- Authenticity flow
- Face-match flow

Per flow attach:
- input sample id
- output summary
- latency
- pass/fail
- logs/screenshots

## 6) Dev B report template

```markdown
## Dev B Post-Pull Runtime Validation

### Pull State
- branch: main
- commit: <sha>

### Runtime Artifacts
- efficientnet_lite0.tflite: present/absent
- mobilefacenet.tflite: present/absent

### Gate Status
- production_readiness_check: PASS/FAIL

### Runtime Health
- ocrRuntimeAvailable: true/false
- tfliteRuntimeAvailable: true/false
- authenticityModelAvailable: true/false
- faceModelAvailable: true/false

### Smoke Results
- OCR: PASS/FAIL
- Authenticity: PASS/FAIL
- Face-match: PASS/FAIL

### Blockers (if any)
- <list>
```

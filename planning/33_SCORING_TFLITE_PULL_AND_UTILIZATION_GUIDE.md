# 33) Scoring TFLite Pull and Utilization Guide

Last Updated: 2026-03-20  
Audience: Dev A, Dev B, QA, Release

## 1) What this update delivers

This update introduces a real scoring `.tflite` export path and parity validation flow.

Included in repo:
- `offline_ml/src/export_scoring_to_tflite.py`
- `offline_ml/src/validate_scoring_tflite_parity.py`
- `gigcredit_app/assets/models/scoring_model_v1.tflite`
- config/readme/planning updates tied to this workflow

## 2) Safe pull instructions (all contributors)

From repo root:

```powershell
git fetch origin
git checkout main
git pull --ff-only origin main
```

Verify the new files exist:

```powershell
Test-Path gigcredit_app/assets/models/scoring_model_v1.tflite
Test-Path offline_ml/src/export_scoring_to_tflite.py
Test-Path offline_ml/src/validate_scoring_tflite_parity.py
```

Expected output: all `True`.

## 3) Environment setup for export/parity

### Option A: existing project venv (if stable)
Use:
- `d:/Program Files/GigCredit/.venv/Scripts/python.exe`

### Option B: dedicated D-drive export venv (recommended for low C: space)
Use:
- `D:/tf-export-venv/Scripts/python.exe`

Set temp/cache to D drive before heavy installs/runs:

```powershell
$env:PIP_CACHE_DIR="D:\pip-cache"
$env:TEMP="D:\pip-tmp"
$env:TMP="D:\pip-tmp"
```

## 4) Run scoring TFLite export

```powershell
& "D:/tf-export-venv/Scripts/python.exe" -m offline_ml.src.export_scoring_to_tflite
```

Primary output:
- `gigcredit_app/assets/models/scoring_model_v1.tflite`

Generated runtime contract/report (local data path):
- `offline_ml/data/scoring_tflite_contract.json`
- `offline_ml/data/scoring_tflite_export_report.json`

## 5) Run parity validation

```powershell
& "D:/tf-export-venv/Scripts/python.exe" -m offline_ml.src.validate_scoring_tflite_parity
```

Expected output file:
- `offline_ml/data/scoring_tflite_parity_report.json`

PASS condition:
- script exits successfully
- parity report `status` is `PASS`

## 6) How Dev B should utilize this effectively

1. Pull latest `main` with fast-forward only.
2. Verify `scoring_model_v1.tflite` exists in app assets.
3. Integrate model loading path in app runtime (if moving scoring path to TFLite runtime).
4. Use parity report and golden pack to confirm runtime outputs match expected tolerances.
5. Attach integration evidence in:
   - `planning/24_DEV_A_TO_DEV_B_PRODUCTION_HANDOFF_SIGNOFF_CHECKLIST.md`

## 7) Practical notes

- Current repo has `offline_ml/data/` ignored in git. Data reports under that folder are generated locally and should be attached in evidence workflows rather than expected from pull.
- If TensorFlow install fails due C drive pressure, use D-drive venv/temp/cache strategy above.
- Do not force-push; always rebase/ff-only on `main`.

## 8) Troubleshooting quick map

- `ModuleNotFoundError: tensorflow`:
  - install `tensorflow-cpu==2.16.1` in chosen venv.
- TFLite file missing after export:
  - rerun export script and check write permissions in `gigcredit_app/assets/models/`.
- Parity fails:
  - inspect `offline_ml/data/scoring_tflite_parity_report.json` max diff fields.

## 9) Release checklist snippet

Before marking integration complete:
- [ ] Pull succeeded on `main`
- [ ] TFLite file present in app assets
- [ ] Export command succeeds
- [ ] Parity command succeeds
- [ ] Evidence attached to signoff checklist

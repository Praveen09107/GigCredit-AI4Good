# 23) TODO Completion Blocker and Final Steps

## Why TODO cannot be fully closed yet

External runtime model binaries are not present in workspace.

Required files:
- `gigcredit_app/assets/models/efficientnet_lite0.tflite`
- `gigcredit_app/assets/models/mobilefacenet.tflite`

Search verification in workspace currently returns no model binaries (`.tflite/.onnx/.pth/.pt/.mlmodel`).

## Immediate completion steps (once binaries are dropped)

1. Place binaries in:
   - `gigcredit_app/assets/models/`

2. Run finalization workflow:

```powershell
powershell -ExecutionPolicy Bypass -File offline_ml/scripts/finalize_artifact_handoff.ps1
```

3. Confirm outputs exist:
- `offline_ml/data/runtime_model_handoff_report.json`
- `offline_ml/data/production_handoff_bundle.json`
- `gigcredit_app/assets/constants/artifact_manifest.json` contains `runtime_models`

4. Create PR using template:
- `planning/21_PRODUCTION_MODEL_ARTIFACT_PR_PACKAGE.md`

## TODO mapping to completion

- Export mobile runtime artifacts -> complete after step 1
- Generate manifest and checksums -> complete after step 2
- Create artifact handoff PR -> complete after step 4

## Additional note on real-data dataset item

Current dataset path used by pipeline is synthetic:
- `offline_ml/data/synthetic_profiles.csv`

If release policy requires real-data-only training set closure, add the approved real dataset and run:

```powershell
python -m offline_ml.src.train_final
python -m offline_ml.src.train_meta_learner
python -m offline_ml.src.evaluate_real_ready
```

Then rerun finalization workflow.

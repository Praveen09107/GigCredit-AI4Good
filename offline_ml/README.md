# GigCredit Offline ML

Offline ML pipeline for GigCredit: data generation, XGBoost/RandomForest
training, TreeSHAP extraction, Logistic Regression meta-learner, and m2cgen
export to Dart.

## Real-data-ready evaluation harness

Run holdout evaluation with calibration and threshold tuning:

```bash
python -m offline_ml.src.evaluate_real_ready
```

Optional arguments:
- `--dataset <path>`: evaluate an external real dataset (same schema expected)
- `--label-threshold <float>`: explicit binary target threshold
- `--label-quantile <float>`: derive threshold from quantile (default `0.60`)
- `--val-size <float>` and `--test-size <float>`: holdout split sizes
- `--threshold-objective {youden_j,f1,balanced_accuracy}`
- production gate thresholds:
	- `--min-roc-auc` (default `0.75`)
	- `--min-pr-auc` (default `0.60`)
	- `--max-brier` (default `0.20`)
	- `--min-recall` (default `0.65`)
	- `--min-balanced-accuracy` (default `0.70`)
- synthetic stress-test options:
	- `--skip-stress-tests` to disable stress checks
	- `--stress-max-roc-auc-drop` (default `0.03`)
	- `--stress-max-pr-auc-drop` (default `0.04`)
	- `--stress-max-brier-increase` (default `0.02`)
	- `--stress-min-recall-floor` (default `0.70`)

Output report:
- `offline_ml/data/real_ready_evaluation_report.json`

The report includes:
- train/val/test split summary,
- meta-model CV selection info,
- calibration method selection by validation Brier score,
- tuned decision threshold,
- production gate decision (`GO` / `NO_GO`) with per-check pass/fail,
- stress-test gate decision (`GO` / `NO_GO`) and per-scenario failures,
- validation and test metrics (ROC-AUC, PR-AUC, Brier, log-loss, precision, recall, F1, specificity, balanced accuracy).

## Artifact handoff packaging

Copy model artifacts into app runtime paths and generate checksums:

```bash
python -m offline_ml.src.package_artifacts_for_app
```

Generated targets:
- `gigcredit_app/lib/scoring/generated/*.dart`
- `gigcredit_app/assets/constants/*.json`
- `gigcredit_app/assets/constants/artifact_manifest.json`

## Runtime model artifact packaging (production handoff)

Validate runtime model files and write runtime metadata/checksums into app manifest:

```bash
# 1) copy template and fill real metadata values
copy offline_ml/data/runtime_model_contract.template.json offline_ml/data/runtime_model_contract.json

# 2) package runtime model entries into manifest
python -m offline_ml.src.package_runtime_models_for_app
```

Defaults:
- required runtime files: `efficientnet_lite0.tflite`, `mobilefacenet.tflite`
- model directory: `gigcredit_app/assets/models`
- manifest target: `gigcredit_app/assets/constants/artifact_manifest.json`
- report output: `offline_ml/data/runtime_model_handoff_report.json`

For additional required artifacts (for example Paddle OCR runtime files), repeat `--require-artifact`:

```bash
python -m offline_ml.src.package_runtime_models_for_app \
	--require-artifact efficientnet_lite0.tflite \
	--require-artifact mobilefacenet.tflite \
	--require-artifact ppocr_det.onnx \
	--require-artifact ppocr_rec.onnx
```

## Strict production readiness gate

Fail fast unless all of these are green:
- model evaluation production gate = PASS
- stress gate = PASS
- runtime model handoff report = PASS
- required runtime models exist in app manifest runtime block

```bash
python -m offline_ml.src.check_production_readiness
```

## One-command production handoff workflow

Run full handoff orchestration (train/evaluate/package/gate/evidence):

```powershell
powershell -ExecutionPolicy Bypass -File offline_ml/scripts/run_production_handoff.ps1
```

First run behavior:
- if `offline_ml/data/runtime_model_contract.json` is missing, script copies template and stops
- fill real metadata values, then rerun script

Evidence bundle output:
- `offline_ml/data/production_handoff_bundle.json`

## Scoring model TFLite export (Dev A)

Export the main scoring meta-learner to a deployable `.tflite` artifact:

```bash
python -m offline_ml.src.export_scoring_to_tflite
```

Default outputs:
- `gigcredit_app/assets/models/scoring_model_v1.tflite`
- `offline_ml/data/scoring_tflite_contract.json`
- `offline_ml/data/scoring_tflite_export_report.json`

Validate TFLite parity against the reference scorer and golden pack:

```bash
python -m offline_ml.src.validate_scoring_tflite_parity
```

Parity output:
- `offline_ml/data/scoring_tflite_parity_report.json`

Note:
- TFLite export requires TensorFlow in a supported Python runtime environment.
- If TensorFlow is unavailable, the exporter fails fast with guidance.

This is the skeleton structure; implement logic following
`planning/1_SCORING_ENGINE_SPEC_FREEZE.md` and
`planning/4_IMPLEMENTATION_PLAN_20_PHASES.md`.


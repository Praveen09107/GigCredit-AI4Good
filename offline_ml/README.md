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

This is the skeleton structure; implement logic following
`planning/1_SCORING_ENGINE_SPEC_FREEZE.md` and
`planning/4_IMPLEMENTATION_PLAN_20_PHASES.md`.


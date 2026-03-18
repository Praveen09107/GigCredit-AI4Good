# Dev A Offline ML Implementation Spec (Detailed)

Owner: Dev A  
Scope: `offline_ml/` + ML artifact handoff  
Stage: Pre-implementation review draft

---

## 1) Objective

Produce deterministic, on-device compatible scoring artifacts from offline training pipeline with strict reproducibility and parity checks.

---

## 2) Pipeline outputs (must produce)

### 2.1 Scorer Dart files
- `p1_scorer.dart`
- `p2_scorer.dart`
- `p3_scorer.dart`
- `p4_scorer.dart`
- `p6_scorer.dart`

### 2.2 JSON assets
- `meta_coefficients.json`
- `shap_lookup.json`
- `state_income_anchors.json`
- `feature_means.json`

Compatibility note:
- Primary handoff artifacts remain the four JSON files above (canonical in planning freeze docs).
- Optional compatibility output `scoring_constants.dart` may be generated as a mirror bundle for teams using the revised-spec packaging style, but it does not replace canonical JSON artifacts unless a formal freeze change is approved.

---

## 3) Script contract

Expected scripts and responsibilities:

- `src/data_generator.py`: generate synthetic profiles and labels
- `src/tune_models.py`: hyperparameter tuning
- `src/train_final.py`: train frozen model set
- `src/extract_shap.py`: generate binned SHAP lookup
- `src/train_meta_learner.py`: train LR final layer (44 inputs)
- `src/export_to_dart.py`: m2cgen export for ML pillars
- `src/validate_export.py`: parity checks Python vs Dart

Each script must support:
- deterministic seed,
- clear CLI logging,
- non-zero exit on failure.

Naming rule:
- Current repository script names are canonical for implementation in this phase:
	- `tune_models.py`, `train_final.py`, `extract_shap.py`, `train_meta_learner.py`, `export_to_dart.py`, `validate_export.py`
- Renaming to alternate script names is optional refactor work and must not block implementation.

---

## 4) Frozen model assignments

- P1: XGBoost
- P2: XGBoost
- P3: XGBoost
- P4: XGBoost
- P5: scorecard (no model export)
- P6: RandomForest
- P7: scorecard
- P8: scorecard

Final score layer:
- Logistic regression over 44 inputs.

---

## 5) m2cgen export constraints (strict)

- use exact tree method for XGBoost export compatibility,
- keep model complexity bounded (`n_estimators <= 150`, `max_depth <= 4`),
- set recursion limit before export (`sys.setrecursionlimit(50000)`),
- sanitize generated function names and class wrappers for Dart compile safety.

Mandatory assertion before each model export:
- if XGBoost model `tree_method != "exact"`: fail pipeline immediately.

---

## 6) Data generation requirements

Synthetic dataset requirements:
- target size: 15,000 profiles,
- realistic stratification by work type,
- no NaN in training tables,
- include metadata summary output.

Persist:
- dataset CSV/parquet,
- schema manifest,
- generation config (seed, distributions).

---

## 7) Feature/label integrity checks

Before training:
- verify feature count = 95,
- verify expected feature slicing compatibility:
	- P1: idx `0..12` (13)
	- P2: idx `13..27` (15)
	- P3: idx `28..36` (9)
	- P4: idx `37..48` (12)
	- P5: idx `49..66` (18, scorecard only)
	- P6: idx `67..77` (11)
	- P7: idx `78..87` (10, scorecard only)
	- P8: idx `88..94` (7, scorecard only)
- verify label ranges,
- assert no duplicate feature columns.
- assert all feature values are within [0.0, 1.0] after preprocessing.

Fail fast if mismatched.

---

## 8) Meta-learner training contract

Input vector for LR:
- 8 adjusted pillar scores,
- 4 work-type one-hots,
- 32 interaction terms (8 pillars × 4 work types).

Total LR input length is **44** (frozen architecture).

Ordered layout (must be identical in Python and Dart):
- `[0..7]`   = adjusted pillar scores `P1..P8`
- `[8..11]`  = work-type one-hot `[platform, vendor, tradesperson, freelancer]`
- `[12..43]` = interactions in nested order:
	- for pillar in `P1..P8` (outer loop)
	- for work type in `[platform, vendor, tradesperson, freelancer]` (inner loop)

Output artifact:
- coefficient array length 44,
- scalar intercept,
- metadata with training timestamp and metrics.

P2 modeling rule (explicit):
- P2 label is frozen as continuous payment-discipline score in this implementation cycle.
- P2 uses XGBoost regressor objective and `predict()` output in [0,1].
- P2 classifier/AUC path is out-of-scope unless a formal freeze-change is approved.
- P1/P3/P4/P6 remain RMSE-oriented in the current default pipeline.

---

## 9) Explainability artifact contract

`shap_lookup.json` must contain, per ML pillar:
- feature name/id,
- ordered percentile bin edges,
- SHAP contribution per bin,
- schema version.

Runtime behavior requirement:
- lookup only, no on-device SHAP recomputation.

---

## 10) Parity and validation tests

Run parity for N known vectors (recommend >= 100):
- Python model outputs vs exported Dart outputs.

Pass criteria:
- max absolute difference <= 0.005 per model output,
- no catastrophic mismatch for any model.

Hard rule:
- if any vector exceeds tolerance, pipeline halts and artifacts are not handed off.

Store report:
- include failed vectors if any,
- include summary metrics per model.

---

## 11) Artifact packaging and transfer

Create one artifact manifest file including:
- file name,
- checksum,
- generation timestamp,
- source script version hash.

Delivery rules:
- copy artifacts into Flutter expected paths,
- verify app asset loading before handoff complete.

---

## 12) Day-1 ML implementation order

1. data generation dry run (small N)
2. full data generation (target N=15000)
3. training skeleton execution (fast tuning profile)
4. SHAP extraction scaffold
5. meta-learner scaffold (assert coefficient length = 44)
6. export scaffold (with tree_method + recursion assertions)
7. parity scaffold (strict tolerance)
8. artifact path checks

Note: full quality tuning can continue Day-2, but file contracts must be stable Day-1.

---

## 13) Acceptance criteria (offline ML)

- `data_generator.py` exits 0 and generated dataset has expected shape + zero NaN,
- `train_final.py` exits 0 and all 5 model artifacts exist,
- all XGBoost models used for export have `tree_method="exact"`,
- `extract_shap.py` exits 0 and SHAP lookup artifact is generated,
- `train_meta_learner.py` exits 0 and LR coefficient length is exactly 44,
- `export_to_dart.py` exits 0 and all 5 scorer Dart files are generated,
- `validate_export.py` exits 0 and parity tolerance criteria pass,
- all required JSON artifacts are present (`meta_coefficients.json`, `shap_lookup.json`, `state_income_anchors.json`, `feature_means.json`),
- artifacts are copied to expected Flutter paths and load successfully.

---

## 14) Risks and safeguards

High risks:
- export recursion/size failures,
- feature index mismatch,
- inconsistent artifact names.

Safeguards:
- pre-export assertions,
- fixed naming constants shared with app,
- fail-fast validation script before handoff.

---

## 15) Best-AUC baseline snapshot (2026-03-18)

Latest optimized local run summary:
- dataset profiles: 250,000 synthetic rows,
- meta input length: 44 (unchanged),
- label quantile used: 0.40,
- label threshold used: 0.5276450512,
- best logistic C: 0.0625,
- best class weight: none,
- best solver: lbfgs,
- CV AUC mean: 0.980855,
- train AUC: 0.980881,
- export parity status: PASS.

Associated artifacts/reports:
- `offline_ml/data/meta_training_report.json`
- `offline_ml/data/training_report.json`
- `offline_ml/data/validation_report.json`

Notes:
- this is the strongest synthetic-data AUC baseline in current repository state,
- score quality on real production data still requires external validation,
- keep this configuration as temporary benchmark baseline until real-data tuning pass.

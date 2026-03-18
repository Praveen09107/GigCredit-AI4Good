# GigCredit — Scoring Engine Specification (FROZEN)

This document is the **single source of truth** for how GigCredit computes scores on-device, including **dynamic scoring** behavior.

It intentionally resolves contradictions across older specs (weighted sum vs meta-learner, 5 vs 20 meta inputs, parallel isolates, etc.).

## 1) Non-negotiable constraints
- **On-device scoring only**: feature engineering + scoring + explainability run on device.
- **Privacy-first**: no raw bank statements / OCR text sent to backend.
- **Deterministic output**: same inputs must produce the same score across devices (within strict tolerance).
- **MVP model updates**: **no OTA model updates**; model updates ship via app update only.

## 2) Pillars (P1–P8) and computation type
Pillars and their computation method:

- **P1 Income Stability**: ML model (XGBoost, exported to Dart via m2cgen) → output in **[0,1]**
- **P2 Payment Discipline**: ML model (XGBoost, exported to Dart via m2cgen) → output in **[0,1]**
- **P3 Debt Management**: ML model (XGBoost, exported to Dart via m2cgen) → output in **[0,1]**
- **P4 Savings Behaviour**: ML model (XGBoost, exported to Dart via m2cgen) → output in **[0,1]**
- **P5 Work & Identity**: Dart scorecard (rule-based) → output in **[0,1]**
- **P6 Financial Resilience**: ML model (RandomForest, exported to Dart via m2cgen) → output in **[0,1]**
- **P7 Social Accountability**: Dart scorecard (rule-based) → output in **[0,1]**
- **P8 Tax Compliance**: Dart scorecard (rule-based) → output in **[0,1]**

## 3) Feature vector (95 features)
- Canonical extraction fields and processing rules are defined in:
  - `specification files/Input_fields_final (1).txt`
- Output of feature engineering is exactly:
  - `feature_vector[95]` with each value clamped to **[0,1]**
- Feature slicing for ML pillars (must match training/export):
  - **P1**: `features[0:13]` (13)
  - **P2**: `features[13:28]` (15)
  - **P3**: `features[28:37]` (9)
  - **P4**: `features[37:49]` (12)
  - **P6**: `features[67:78]` (11)

## 4) Minimum scoring gate (“refuse to score”)
Before any scoring:
- Step-1 completed
- Step-2 **identity verified**
- Step-3 **bank statement processed** with **>= 30 transactions**

If minimum gate fails:
- Do **not** compute a score.
- UI message: “Insufficient data for credit assessment. Please complete Steps 1–3.”

## 5) m2cgen model deployment (MVP choice)
### 5.1 Artifacts shipped inside the app
Scoring ML models are shipped as **pure Dart code** committed to the app source:
- `lib/scoring/p1_scorer.dart` (m2cgen XGBoost)
- `lib/scoring/p2_scorer.dart` (m2cgen XGBoost)
- `lib/scoring/p3_scorer.dart` (m2cgen XGBoost)
- `lib/scoring/p4_scorer.dart` (m2cgen XGBoost)
- `lib/scoring/p6_scorer.dart` (m2cgen RandomForest)

Support artifacts:
- `assets/constants/meta_coefficients.json` (LR coefficients + intercept)
- `assets/constants/shap_lookup.json` (binned SHAP lookup tables)
- `assets/constants/feature_means.json` (population means; optional if used in reporting)

### 5.2 m2cgen correctness constraints (MANDATORY)
For m2cgen safety and determinism:
- XGBoost must use `tree_method='exact'` (do not use `hist`)
- Keep ensembles bounded: `n_estimators <= 150`, `max_depth <= 4`
- Before export: `sys.setrecursionlimit(50000)`
- Ensure feature engineering never outputs NaN/Inf (explicit numeric fallbacks + sanitization)

### 5.3 Runtime characteristics
- No model loading, no native runtimes required for scoring.
- Sequential scoring is sufficient (no isolates required).

## 6) Final score computation (AUTHORITATIVE)
### 6.1 Meta-learner (Logistic Regression) is the ONLY final-score method
Weighted-sum final scoring is deprecated and MUST NOT be used.

Meta-learner input vector (20 values):
- 8 pillar scores: `[P1..P8]`
- 4 work-type one-hot: `[is_platform, is_vendor, is_tradesperson, is_freelancer]`
- 8 interaction terms: `[P1*is_platform, P1*is_vendor, P1*is_trades, P1*is_freelancer, P2*is_platform, P2*is_vendor, P2*is_trades, P2*is_freelancer]`

Computation:
- `logit = dot(x, coefficients) + intercept`
- `probability = sigmoid(logit)` in **[0,1]**
- `gigcredit_score = round(300 + probability * 600)` in **[300,900]**

Risk band:
- 300–450 High Risk
- 451–650 Medium Risk
- 651–900 Low Risk

## 7) Confidence handling
- Pillar confidence is computed from step completion + verification status.
- If any pillar has confidence `< 0.30`, its display should be “Not enough data” and its meta-learner input uses **0.50** for that pillar.
- Any NaN/Inf or out-of-range scores are sanitized (clamp to [0,1], NaN → 0.50 with warning).

## 8) Explainability (AUTHORITATIVE)
### 8.1 What we ship
We ship **binned SHAP lookup tables** per ML pillar model:
- For each feature, we store percentile bin edges and mean SHAP value per bin.

### 8.2 Runtime explainability
- For each feature value, locate its bin and read the SHAP contribution estimate.
- Aggregate to:
  - Top positive drivers
  - Top negative drivers
- Important: explainability is **advisory**, and MUST NOT change the score.

## 9) “Dynamic score” behavior (AUTHORITATIVE)
Dynamic score means **both**:

### 9.1 During onboarding (provisional updates)
- After each step completion (especially after Step-3), recompute and show a provisional score.
- If minimum gate not met, show “insufficient data” instead of a number.

### 9.2 Over time (repeat scoring)
- Store score history locally (date, score, grade, risk band, pillar scores).
- Enforce **30-day cooldown** between assessments for stability.

## 10) Authoritative override note
Some older specs propose TFLite-encrypted scoring assets. For MVP, this project is explicitly frozen on **pure-Dart scoring via m2cgen**. Any document that contradicts this must be treated as **non-authoritative** for implementation.


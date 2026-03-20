# 27) Scoring Determinism, Golden Inference Pack, and Tolerance Policy

Last Updated: 2026-03-20

## 1) Golden inference pack

Artifact:
- `offline_ml/data/golden_inference_pack.json`

Contains:
- 30 deterministic samples
- full 95-dim feature vectors
- pillar outputs (`p1..p8`)
- meta input vector (44 dims)
- expected probability
- expected score
- expected risk band

Use case:
- Dev B can replay this pack through app/runtime scoring implementation and verify deterministic parity.

## 2) Meta deterministic contract

Primary sources:
- `offline_ml/data/meta_coefficients.json`
- `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`

Frozen rules:
- input length = 44
- ordering = 8 pillars + 4 work-type one-hot + 32 interactions
- inference = standardized logistic regression with provided means/stds/coefficients/intercept

## 3) Tolerance policy

Artifact:
- `offline_ml/data/scoring_tolerance_policy.json`

Frozen policy values:
- pillar probability abs tolerance: 0.005
- score tolerance: 1 point
- risk cutoffs:
  - high <= 450
  - medium <= 650
  - low >= 651

## 4) Validation checklist

1. Recompute all 30 golden samples.
2. Verify probability deviation <= tolerance.
3. Verify score difference <= 1.
4. Verify risk band exact match.

If any check fails: block production closure until contract parity is restored.

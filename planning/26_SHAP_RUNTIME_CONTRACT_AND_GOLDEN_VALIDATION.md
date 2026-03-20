# 26) SHAP Runtime Contract and Golden Validation

Last Updated: 2026-03-20

## 1) Runtime contract (frozen)

Source artifact:
- `offline_ml/data/shap_lookup.json`

Contract fields:
- `schema_version`: string
- `pillars`: object keyed by pillar id (`p1`, `p2`, `p3`, `p4`, `p6`)
- Per feature key (`f_00...`):
  - `edges`: percentile bin edges (length `N+1`)
  - `shap`: mean SHAP contribution per bin (length `N`)

Runtime lookup rule:
1. Select pillar and feature key.
2. Choose bin where value is in `[edge_i, edge_{i+1})` (last bin inclusive on upper bound).
3. Read contribution from `shap[i]`.

Guardrails:
- SHAP is explanation-only.
- SHAP must not alter final score computation path.

## 2) Golden validation pack

Golden examples artifact:
- `offline_ml/data/shap_golden_examples.json`

This pack includes 40 examples (>=20 required) with:
- `pillar`
- `feature_key`
- `sample_value`
- `selected_bin`
- `bin_low` / `bin_high`
- `expected_contribution`

## 3) Validation procedure (Dev A + Dev B)

1. Load `shap_lookup.json` in runtime or validation harness.
2. Replay each example in `shap_golden_examples.json`.
3. Assert selected bin index and contribution match expected values.
4. Validate top positive/negative factor ordering on a shared sample set.

## 4) Production signoff criterion

SHAP closure is PASS only when:
- runtime lookup parity passes on all golden examples,
- top factor consistency check passes,
- and explanation-only behavior is confirmed in integration flow.

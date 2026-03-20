# 28) Feature Contract Freeze (95) and Preprocessing Rules

Last Updated: 2026-03-20

## 1) Canonical feature contract

Artifact:
- `offline_ml/data/feature_contract_freeze.json`

Frozen shape:
- feature count = 95
- canonical keys = `f_00` ... `f_94`

Frozen ML slices:
- P1: `0..12`
- P2: `13..27`
- P3: `28..36`
- P4: `37..48`
- P6: `67..77`

## 2) Preprocessing rules (training -> app)

Applied contract:
- input type: numeric float
- missing/invalid (`NaN`, `Inf`): map to `0.5`
- lower clamp: `<0` -> `0.0`
- upper clamp: `>1` -> `1.0`
- short vectors: pad with `0.5`
- long vectors: truncate beyond 95

App implementation reference:
- `gigcredit_app/lib/scoring/feature_sanitizer.dart`

## 3) Signoff requirement

Dev B integration is PASS for this item only when:
- feature vector construction in app matches this contract,
- and generated scorer inputs use exact frozen slices.

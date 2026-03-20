# GigCredit Spec Problems - Executive Summary

Date: 2026-03-18

## Top 5 Blocking Problems
1. Final score method conflict (weighted sum vs LR meta-learner).
2. Model deployment conflict (TFLite runtime vs m2cgen pure-Dart runtime).
3. Workflow conflict (8 user steps vs Step-9 confusion).
4. Auth conflict (MVP auth and production auth mixed).
5. No global spec precedence policy.

## Why This Matters
These conflicts can produce different scoring outputs, broken mobile/backend contracts, inconsistent UX flow, and failed integration during hackathon delivery.

## Freeze Decisions Needed Immediately
1. Final score: LR meta-learner only.
2. Runtime: m2cgen pure-Dart for scoring MVP.
3. Step flow: 8 user-visible steps + internal automated EMI analysis.
4. Auth profile: MVP mode explicitly separated from production mode.
5. Explainability: precomputed SHAP lookup only at runtime.

## Files Added
- planning/7_SPECIFICATION_PROBLEMS_LOG.md
- planning/8_SPEC_PROBLEMS_EXEC_SUMMARY.md

## Next Suggested Move
Create one final unified master spec that supersedes all conflicting legacy sections and includes mandatory acceptance tests.

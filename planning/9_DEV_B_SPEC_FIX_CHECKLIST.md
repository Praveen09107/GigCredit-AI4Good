# Dev B Spec Fix Checklist

Date: 2026-03-18
Owner: Developer B
Scope: Fixes from spec contradictions that impact Dev B implementation

## Must-Fix Before Coding Freeze

### 1) Final score formula and range
- Status: Fixed in plan docs.
- Required implementation:
  - Use LR meta-learner only for final score.
  - Use frozen formula: `score = round(300 + sigmoid(logit) * 600)`.
  - Never use weighted-sum final score.
- Primary references:
  - planning/1_SCORING_ENGINE_SPEC_FREEZE.md
  - planning/6_DEV_B_EXECUTION_PLAN.md

### 2) Step model semantics
- Status: Fixed in plan docs.
- Required implementation:
  - Keep 9 user-visible onboarding steps.
  - Run EMI analysis after Step-3 parsing and surface it as Step-9 stage.
- Primary references:
  - planning/3_END_TO_END_WORKFLOW_FREEZE.md
  - planning/6_DEV_B_EXECUTION_PLAN.md

### 3) Backend endpoint contract usage
- Status: Fixed in plan docs.
- Required implementation:
  - Use `POST /gov/pan/verify` and `POST /gov/aadhaar/verify` in KYC flow.
  - Keep endpoint names centralized in one client constants file.
- Primary references:
  - planning/1_GIGCREDIT_FULL_IMPLEMENTATION_PLAN.md
  - planning/6_DEV_B_EXECUTION_PLAN.md

### 4) Runtime explainability behavior
- Status: Fixed in plan docs.
- Required implementation:
  - Use precomputed SHAP lookup tables only.
  - No on-device SHAP recomputation.
- Primary references:
  - planning/1_SCORING_ENGINE_SPEC_FREEZE.md
  - planning/6_DEV_B_EXECUTION_PLAN.md

### 5) Scorer artifact integration path
- Status: Fixed in plan docs.
- Required implementation:
  - Integrate scorer files from `lib/scoring/p1_scorer.dart ... p6_scorer.dart`.
  - Validate imports and naming consistency early.
- Primary references:
  - planning/1_SCORING_ENGINE_SPEC_FREEZE.md
  - planning/6_DEV_B_EXECUTION_PLAN.md

## Dev B Validation Gates
1. Golden feature-vector test passes with fixed 95-length vector.
2. Golden score test passes with deterministic 300-900 output.
3. Step progress test confirms 9 visible steps in UI.
4. Report screen test confirms SHAP insights render from lookup data.

## Additional User Locks
- Theme reference source: `theme/original-a426c342fc461673a08eb422baac4bba.webp` (tokens only, no template layout copy).
- Multilingual scope: report only, not the entire app UI in this phase.

## Notes
- No push/commit should be done without explicit user permission.
- Any conflict with older legacy specs should be resolved in favor of frozen planning docs.

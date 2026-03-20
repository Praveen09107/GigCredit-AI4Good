# GigCredit Specification Problems Log

Date: 2026-03-18
Scope: Full cross-review of planning and specification documents

## Critical Problems

### 1) Final score logic is contradictory across specs
- Problem: Some documents define final score using weighted sum, while revised/frozen docs define Logistic Regression meta-learner as the only final method.
- Why this is critical: Different implementations will produce different credit scores for same user input.
- Conflicting sources:
  - specification files/Feature engineering (1).txt
  - specification files/MASTER PROMPT — MODEL OUTPUT TO EXPLAINABLE MULTILINGUAL CREDIT REPORT PIPELINE.txt
  - specification files/REVISED — SCORING ENGINE ARCHITECTURE (SUPERSEDES ML WORKFLOW + PHASE-2 + PHASE-3 SCORING SECTIONS).txt
  - planning/1_SCORING_ENGINE_SPEC_FREEZE.md
- Required fix: Freeze one method globally (recommended: LR meta-learner only) and mark all weighted-sum final-score sections as deprecated.

### 2) Model runtime/deployment path is contradictory
- Problem: Legacy docs describe ONNX/TF/TFLite scoring runtime, while revised scoring docs use m2cgen pure-Dart scoring runtime.
- Why this is critical: Team can build incompatible model artifacts and mobile runtime.
- Conflicting sources:
  - specification files/PHASE-2 — MACHINE LEARNING DEVELOPMENT, TRAINING PIPELINE, SHAP GENERATION, AND MOBILE DEPLOYMENT.txt
  - specification files/MASTER IMPLEMENTATION PROMPT — GIGCREDIT FULL SYSTEM (ON-DEVICE + BACKEND + ML + REPORT).txt
  - specification files/REVISED — SCORING ENGINE ARCHITECTURE (SUPERSEDES ML WORKFLOW + PHASE-2 + PHASE-3 SCORING SECTIONS).txt
  - planning/1_SCORING_ENGINE_SPEC_FREEZE.md
- Required fix: Freeze one scoring runtime globally (recommended: m2cgen pure Dart for MVP) and remove conflicting conversion/runtime instructions.

### 3) Step model ambiguity (8 steps vs Step-9 interpretation)
- Problem: Some docs define 8 user steps, while others present Step-9 as if it is user-facing.
- Why this is critical: Breaks UX, progress indicators, analytics, and test case design.
- Conflicting sources:
  - specification files/GIGCREDIT — USER INPUT COLLECTION SPECIFICATION.txt
  - specification files/MASTER UI_UX DESIGN PROMPT — GIGCREDIT MOBILE APPLICATION.txt
  - specification files/Untitled document.txt
  - planning/3_END_TO_END_WORKFLOW_FREEZE.md
- Required fix: Freeze as 8 user-visible steps + 1 internal automated EMI-analysis step.

### 4) No single global precedence policy across specs
- Problem: Multiple files claim master/final authority, but no file-level and section-level precedence map exists.
- Why this is critical: Engineers will pick different source documents and reintroduce contradictions.
- Affected areas: scoring, runtime stack, auth, explainability, and onboarding flow.
- Required fix: Publish one explicit precedence matrix and supersession map.

## High-Severity Problems

### 5) Authentication strategy is mixed (prototype and production patterns overlap)
- Problem: API key/device fingerprint/OTP guidance and JWT-like guidance both appear without clean environment split.
- Why this is high severity: Backend contracts and mobile client auth flow become unstable.
- Conflicting sources:
  - specification files/COMPREHENSIVE FIXES AND ADDITIONS — ALL IDENTIFIED ISSUES AND RESOLUTIONS.txt
  - specification files/MASTER BACKEND SYSTEM SPECIFICATION — GIGCREDIT VERIFICATION, API, AND REPORT GENERATION ARCHITECTURE.txt
  - specification files/PHASE-4 — BACKEND SERVER ARCHITECTURE, VERIFICATION APIS, DATABASE DESIGN, AND LLM REPORT ENGINE.txt
  - planning/2_BACKEND_HARDENING_SPEC.md
- Required fix: Define explicit auth profiles:
  - MVP Hackathon: API key + device ID + signed request + OTP login
  - Production Future: JWT/OAuth + device attestation

### 6) Explainability spec wording is inconsistent
- Problem: Some docs say no runtime SHAP, while others define runtime SHAP lookup from precomputed bins.
- Why this is high severity: Leads to over-engineered or under-delivered explainability implementation.
- Conflicting sources:
  - specification files/MASTER IMPLEMENTATION PROMPT — GIGCREDIT FULL SYSTEM (ON-DEVICE + BACKEND + ML + REPORT).txt
  - specification files/MASTER PROMPT — MODEL OUTPUT TO EXPLAINABLE MULTILINGUAL CREDIT REPORT PIPELINE.txt
  - specification files/REVISED — SCORING ENGINE ARCHITECTURE (SUPERSEDES ML WORKFLOW + PHASE-2 + PHASE-3 SCORING SECTIONS).txt
  - planning/1_SCORING_ENGINE_SPEC_FREEZE.md
- Required fix: Freeze wording to: no on-device SHAP recomputation, only precomputed lookup inference.

### 7) Training dataset scale mismatch
- Problem: Some docs specify 5000 synthetic profiles; revised docs specify 15000.
- Why this is high severity: Alters model stability, tuning, and benchmark expectations.
- Conflicting sources:
  - specification files/ML workflow (1).txt
  - specification files/REVISED — SCORING ENGINE ARCHITECTURE (SUPERSEDES ML WORKFLOW + PHASE-2 + PHASE-3 SCORING SECTIONS).txt
- Required fix: Freeze one count (recommended: 15000 for current plan) and remove legacy numbers.

## Medium-Severity Problems

### 8) Error taxonomy not fully aligned with revised runtime
- Problem: Older assumptions tied to TFLite interpreter errors still exist, while revised scoring runtime is pure Dart.
- Why this matters: Incorrect error handling and monitoring logic in app/backend.
- Required fix: Update failure catalog per current runtime path.

### 9) Field dictionary to feature-engineering mapping is not enforced by contract tests
- Problem: Input field tags and feature formulas exist, but there is no mandatory machine-checked validation linking extracted fields to 95 features.
- Why this matters: Silent drift during implementation and model mismatch risk.
- Required fix: Add schema contract tests and golden feature-vector checks.

### 10) Some files show formatting/encoding quality issues
- Problem: Certain text exports contain inconsistent symbols/formatting, creating parsing and copy errors.
- Why this matters: Small but costly implementation misunderstandings.
- Required fix: Normalize encoding and regenerate clean text versions.

## Recommended Immediate Actions (Implementation Freeze)
1. Publish a single Spec Freeze document with authority order.
2. Publish a supersession table: old section to canonical replacement.
3. Freeze final score method, runtime path, step model, auth mode, and SHAP behavior.
4. Add mandatory acceptance tests:
   - Golden score test
   - Golden feature-vector test
   - Contract test for field extraction to feature mapping
   - End-to-end step-state test
5. Lock these in planning docs and treat conflicting legacy sections as archived.

## Canonical Freeze References To Use Now
- planning/1_SCORING_ENGINE_SPEC_FREEZE.md
- planning/3_END_TO_END_WORKFLOW_FREEZE.md
- planning/2_BACKEND_HARDENING_SPEC.md
- specification files/REVISED — SCORING ENGINE ARCHITECTURE (SUPERSEDES ML WORKFLOW + PHASE-2 + PHASE-3 SCORING SECTIONS).txt
- specification files/COMPREHENSIVE FIXES AND ADDITIONS — ALL IDENTIFIED ISSUES AND RESOLUTIONS.txt

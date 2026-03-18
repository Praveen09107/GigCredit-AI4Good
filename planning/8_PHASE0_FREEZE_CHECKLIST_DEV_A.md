# Phase-0 Freeze Checklist (Dev A Sign-Off)

Owner: **Dev A (Backend + Offline ML + AI Integration)**  
Date: 2026-03-18  
Status: **Must be completed before implementation sprint begins**

---

## 1) Canonical Spec Alignment

- [ ] I confirm the canonical priority order is understood and accepted:
  1. `planning/7_MASTER_IMPLEMENTATION_BLUEPRINT_PRODUCTION_GRADE.md`
  2. `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`
  3. `planning/3_END_TO_END_WORKFLOW_FREEZE.md`
  4. `planning/2_BACKEND_HARDENING_SPEC.md`
  5. `specification files/REVISED — SCORING ENGINE ARCHITECTURE (SUPERSEDES ML WORKFLOW + PHASE-2 + PHASE-3 SCORING SECTIONS).txt`
- [ ] I confirm outdated references will not drive implementation (`ML workflow (1).txt` and legacy conflicting scoring sections).

Acceptance gate: no unresolved source-of-truth conflict remains.

---

## 2) Scoring Contract Freeze Validation (Cross-Team Critical)

- [ ] Final-score method frozen to LR meta-learner on 44 inputs.
- [ ] No weighted-sum final-score path exists in implementation plan.
- [ ] Feature slicing is frozen as:
  - P1 [0:13], P2 [13:28], P3 [28:37], P4 [37:49], P5 [49:67], P6 [67:78], P7 [78:88], P8 [88:95]
- [ ] Minimum scoring gate frozen as: Step 1 complete + Step 2 verified + Step 3 bank parsed with >= 30 transactions.

Acceptance gate: both Dev A and Dev B confirm same scoring contract.

---

## 3) Dev A Artifact Production Freeze (Mandatory)

I will generate and hand off all required artifacts to Dev B:

- [ ] `p1_scorer.dart`
- [ ] `p2_scorer.dart`
- [ ] `p3_scorer.dart`
- [ ] `p4_scorer.dart`
- [ ] `p6_scorer.dart`
- [ ] `shap_lookup.json`
- [ ] `meta_coefficients.json`
- [ ] `state_income_anchors.json`
- [ ] `feature_means.json`

Acceptance gate:
- [ ] 9/9 artifacts exist in expected Flutter paths
- [ ] Artifacts parse/load successfully
- [ ] Dart/Python parity checks pass for scorer outputs

---

## 4) Offline ML Pipeline Freeze (Dev A)

- [ ] Synthetic dataset target size frozen (15,000 profiles).
- [ ] Model assignments frozen (XGBoost P1–P4, RandomForest P6, scorecards P5/P7/P8).
- [ ] m2cgen export constraints frozen and applied:
  - [ ] `tree_method = exact`
  - [ ] `n_estimators <= 150`
  - [ ] `max_depth <= 4`
  - [ ] `sys.setrecursionlimit(50000)` before export
- [ ] Export validation script compares Python vs Dart outputs with strict tolerance.

Acceptance gate: no export recursion/runtime defects in produced scorer files.

---

## 5) Backend API Readiness Freeze (Dev A)

- [ ] Endpoint set frozen and implemented:
  - [ ] `/gov/pan/verify`
  - [ ] `/gov/aadhaar/verify`
  - [ ] `/bank/ifsc/verify`
  - [ ] `/bank/account/verify`
  - [ ] `/gov/vehicle/rc/verify`
  - [ ] `/gov/insurance/verify`
  - [ ] `/gov/income-tax/itr/verify`
  - [ ] `/gov/eshram/verify`
  - [ ] `/bank/loan/check`
  - [ ] `/report/generate`
  - [ ] `/report/store` (optional-but-defined)
- [ ] Backend role freeze accepted: no scoring computation in backend.
- [ ] Auth hardening freeze accepted: API key + HMAC + timestamp replay window + rate limiting.

Acceptance gate: endpoint contracts stable and published before UI integration lock.

---

## 6) Interface Stub Freeze (Unblock Dev B Early)

- [ ] `lib/services/api_client_interface.dart` published with all required method signatures.
- [ ] `lib/services/mock_api_client.dart` published with parseable mock responses.
- [ ] `lib/ai/ai_interfaces.dart` published.
- [ ] `lib/ai/mock_document_processor.dart` published.

Acceptance gate: Dev B can build Steps 2–8 without waiting for live backend/AI.

---

## 7) Security and Privacy Freeze

- [ ] Trust boundary accepted and documented (on-device scoring, backend verification/reporting).
- [ ] Sensitive raw document handling policy agreed for MVP and endpoint payloads.
- [ ] No hardcoded secrets policy in repo enforced.
- [ ] Logging policy avoids sensitive data leakage.

Acceptance gate: security decisions are explicit enough to avoid ad-hoc behavior.

---

## 8) Go / No-Go Decision

- [ ] **GO**: all above sections signed off and no P0 ambiguity remains.
- [ ] **NO-GO**: at least one P0 unresolved; implementation sprint paused until fixed.

---

## 9) Sign-Off

Dev A name: ____________________  
Date/time: _____________________  

Dev B acknowledgement: ____________________  
Date/time: _____________________

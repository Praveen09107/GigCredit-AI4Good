# Dev A Handoff Signoff Checklist (Production Closure)

Last Updated: 2026-03-20
Owner: Release Lead
Scope: Final Dev A deliverables required for production-grade closure

## How to use
- Mark each item as PASS, FAIL, or BLOCKED.
- Attach evidence links for every PASS item.
- Do not mark overall signoff as PASS unless all Critical items are PASS.

## Status legend
- PASS: Requirement delivered and verified.
- FAIL: Requirement missing or incorrect.
- BLOCKED: Awaiting external dependency (for example, environment or access).

## A. Critical Artifacts (Must Pass)

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| A1 | Final scorer artifacts delivered and version-tagged | Dev A | PENDING |  |  |
| A2 | Meta coefficients delivered with frozen 44-input ordering proof | Dev A | PENDING |  |  |
| A3 | Final SHAP lookup delivered in production schema | Dev A | PENDING |  |  |
| A4 | Feature index map (95 features) delivered and signed off | Dev A | PENDING |  |  |
| A5 | Artifact checksums/signatures delivered | Dev A | PENDING |  |  |
| A6 | Rollback artifact bundle delivered (N-1 stable) | Dev A | PENDING |  |  |

## B. Explainability (SHAP) Closure

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| B1 | SHAP generation pipeline output validated from offline ML | Dev A | PENDING |  |  |
| B2 | SHAP runtime contract document provided (pillars, feature keys, edges, shap arrays) | Dev A | PENDING |  |  |
| B3 | Golden SHAP examples provided (value -> bin -> contribution) | Dev A | PENDING |  |  |
| B4 | Top positive/negative factor consistency validated against golden set | Dev A + Dev B | PENDING |  |  |
| B5 | Confirm SHAP is explanation-only and does not alter final score path | Dev A + Dev B | PENDING |  |  |

## C. Scoring Determinism and Calibration

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| C1 | Golden inference pack provided (feature vectors and expected outputs) | Dev A | PENDING |  |  |
| C2 | Probability and score tolerance bounds defined | Dev A | PENDING |  |  |
| C3 | Risk band cutoffs confirmed and frozen | Dev A + Product | PENDING |  |  |
| C4 | Confidence and fallback policy validated against freeze spec | Dev A + Dev B | PENDING |  |  |

## D. Runtime and Platform Readiness

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| D1 | Real model binaries present in gigcredit_app/assets/models | Dev A | PENDING |  |  |
| D2 | Android dependency closure complete for full build context | Dev A | PENDING |  |  |
| D3 | iOS runtime parity verified for capability checks | Dev A | PENDING |  |  |
| D4 | Startup self-check gate validates required runtime prerequisites | Dev A + Dev B | PENDING |  |  |

## E. Backend and Deployment Handoff

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| E1 | Final backend base URL and environment handoff completed | Dev A + Release | PENDING |  |  |
| E2 | Verify and report endpoints production contract signed off | Dev A + QA | PENDING |  |  |
| E3 | Auth and rate-limit behavior validated in deployed environment | Dev A + QA | PENDING |  |  |
| E4 | Report payload schema and multilingual response contract frozen | Dev A + QA | PENDING |  |  |

## F. Test Evidence Bundle (Mandatory)

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| F1 | backend contract smoke suite pass evidence | Dev A | PASS | planning/7_PRODUCTION_EVIDENCE_PACK.md | backend.tests.test_contract_smoke green (33 tests) |
| F2 | offline ML artifact smoke suite pass evidence | Dev A | PASS | planning/7_PRODUCTION_EVIDENCE_PACK.md | offline_ml.tests.test_artifact_handoff_smoke green (2 tests) |
| F3 | flutter analyze pass evidence | Dev B | PASS | planning/7_PRODUCTION_EVIDENCE_PACK.md | Analyze completed with warnings/info only, no errors |
| F4 | flutter full test suite pass evidence | Dev B | PASS | planning/7_PRODUCTION_EVIDENCE_PACK.md | flutter test green (88 tests) |
| F5 | physical-device E2E run evidence | QA | PENDING | planning/evidence/phase10_12/phase10_device_matrix.md | Fill during device validation run |
| F6 | report generation E2E evidence (with deployed backend) | QA | PENDING | planning/evidence/phase10_12/phase10_trace_log.md | Attach trace IDs and report snapshots |

## G. Release Signoff Gates

| Gate | Condition | Status | Signoff By | Date |
|---|---|---|---|---|
| G1 Integration Ready | All A and B items PASS | PENDING |  |  |
| G2 Pre-Production Ready | A, B, C, D items PASS | PENDING |  |  |
| G3 Production Candidate Ready | A through F items PASS | PENDING |  |  |
| G4 Final Release Signoff | All gates PASS with evidence attached | PENDING |  |  |

## H. Open Risks and Blockers
- Add active blocker list here with owner and ETA.

## I. Final Outcome
- Current outcome: NOT SIGNED OFF
- Required to close: Complete all pending Critical items and all release gates.

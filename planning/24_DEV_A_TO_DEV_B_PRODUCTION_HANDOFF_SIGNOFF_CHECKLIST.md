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
| A1 | Final scorer artifacts delivered and version-tagged | Dev A | PASS | `offline_ml/data/scoring_release_metadata.json`, `gigcredit_app/lib/scoring/generated/` | Version + release tag generated |
| A2 | Meta coefficients delivered with frozen 44-input ordering proof | Dev A | PASS | `offline_ml/data/meta_coefficients.json`, `planning/27_SCORING_DETERMINISM_GOLDEN_INFERENCE_AND_TOLERANCE.md` | 44-input ordering documented |
| A3 | Final SHAP lookup delivered in production schema | Dev A | PASS | `offline_ml/data/shap_lookup.json` | Regenerated on 2026-03-20 |
| A4 | Feature index map (95 features) delivered and signed off | Dev A | PASS | `offline_ml/data/feature_contract_freeze.json`, `planning/28_FEATURE_CONTRACT_FREEZE_95_AND_PREPROCESSING.md` | Canonical map `f_00..f_94` |
| A5 | Artifact checksums/signatures delivered | Dev A | PASS | `offline_ml/data/scoring_release_metadata.json`, `gigcredit_app/assets/constants/artifact_manifest.json` | SHA256 present per artifact |
| A6 | Rollback artifact bundle delivered (N-1 stable) | Dev A | PASS | `offline_ml/data/rollback_bundle_manifest_n_minus_1.json`, `offline_ml/data/rollback_bundle_n_minus_1/` | Built from git ref `HEAD~1` |

## B. Explainability (SHAP) Closure

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| B1 | SHAP generation pipeline output validated from offline ML | Dev A | PASS | `offline_ml/data/shap_lookup.json`, command log (`python -m offline_ml.src.extract_shap`) | SHAP file regenerated successfully |
| B2 | SHAP runtime contract document provided (pillars, feature keys, edges, shap arrays) | Dev A | PASS | `planning/26_SHAP_RUNTIME_CONTRACT_AND_GOLDEN_VALIDATION.md` | Contract fields and lookup rule documented |
| B3 | Golden SHAP examples provided (value -> bin -> contribution) | Dev A | PASS | `offline_ml/data/shap_golden_examples.json` | 40 examples delivered (>=20 required) |
| B4 | Top positive/negative factor consistency validated against golden set | Dev A + Dev B | BLOCKED | `planning/26_SHAP_RUNTIME_CONTRACT_AND_GOLDEN_VALIDATION.md` | Requires joint runtime replay by Dev B |
| B5 | Confirm SHAP is explanation-only and does not alter final score path | Dev A + Dev B | PASS | `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`, `planning/26_SHAP_RUNTIME_CONTRACT_AND_GOLDEN_VALIDATION.md` | Contract explicitly marks SHAP explanation-only |

## C. Scoring Determinism and Calibration

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| C1 | Golden inference pack provided (feature vectors and expected outputs) | Dev A | PASS | `offline_ml/data/golden_inference_pack.json` | 30 deterministic samples delivered |
| C2 | Probability and score tolerance bounds defined | Dev A | PASS | `offline_ml/data/scoring_tolerance_policy.json` | Probability and score tolerance documented |
| C3 | Risk band cutoffs confirmed and frozen | Dev A + Product | PASS | `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`, `offline_ml/data/scoring_tolerance_policy.json` | 300-450 / 451-650 / 651-900 |
| C4 | Confidence and fallback policy validated against freeze spec | Dev A + Dev B | BLOCKED | `gigcredit_app/lib/scoring/scoring_engine.dart`, `planning/1_SCORING_ENGINE_SPEC_FREEZE.md` | Joint validation pending in integrated runtime flow |

## D. Runtime and Platform Readiness

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| D1 | Real model binaries present in gigcredit_app/assets/models | Dev A | FAIL | `gigcredit_app/assets/models/` | `.tflite` binaries intentionally deferred in current mode |
| D2 | Android dependency closure complete for full build context | Dev A | BLOCKED | `planning/20_RUNTIME_LOADER_MAPPING_ANDROID_IOS.md` | Requires full Android packaging/build environment validation |
| D3 | iOS runtime parity verified for capability checks | Dev A | BLOCKED | `planning/20_RUNTIME_LOADER_MAPPING_ANDROID_IOS.md` | Requires device/runtime parity validation evidence |
| D4 | Startup self-check gate validates required runtime prerequisites | Dev A + Dev B | PASS | `gigcredit_app/lib/state/startup_self_check_provider.dart`, `gigcredit_app/test/startup_self_check_provider_test.dart` | Gate logic implemented and covered by tests |

## E. Backend and Deployment Handoff

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| E1 | Final backend base URL and environment handoff completed | Dev A + Release | FAIL | `gigcredit_app/lib/config/app_mode.dart` | Deployed production URL handoff not finalized in this repo |
| E2 | Verify and report endpoints production contract signed off | Dev A + QA | PASS | `backend/app/routers/verify.py`, `backend/app/routers/report.py`, `backend/tests/test_contract_smoke.py` | Contract implemented and smoke-tested |
| E3 | Auth and rate-limit behavior validated in deployed environment | Dev A + QA | BLOCKED | `backend/app/auth.py`, `backend/app/services/rate_limiter.py` | Deployed-environment validation evidence pending |
| E4 | Report payload schema and multilingual response contract frozen | Dev A + QA | PASS | `offline_ml/data/report_payload_contract.json`, `backend/app/models/api.py`, `backend/app/services/llm_service.py` | Request/response + fallback documented |

## F. Test Evidence Bundle (Mandatory)

| ID | Requirement | Owner | Status | Evidence | Notes |
|---|---|---|---|---|---|
| F1 | backend contract smoke suite pass evidence | Dev A | PASS | command: `python -m unittest backend.tests.test_contract_smoke -v` | 7/7 tests PASS |
| F2 | offline ML artifact smoke suite pass evidence | Dev A | PASS | command: `python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v` | 2/2 tests PASS |
| F3 | flutter analyze pass evidence | Dev B | PASS | command: `flutter analyze` (mirror path `D:\GigCreditProdReady\gigcredit_app`) | No issues found |
| F4 | flutter full test suite pass evidence | Dev B | PASS | command: `flutter test` (mirror path `D:\GigCreditProdReady\gigcredit_app`) | All tests passed |
| F5 | physical-device E2E run evidence | QA | BLOCKED | not available in current workspace | Requires device lab / QA run |
| F6 | report generation E2E evidence (with deployed backend) | QA | BLOCKED | not available in current workspace | Requires deployed backend + QA evidence |

## G. Release Signoff Gates

| Gate | Condition | Status | Signoff By | Date |
|---|---|---|---|---|
| G1 Integration Ready | All A and B items PASS | PENDING |  |  |
| G2 Pre-Production Ready | A, B, C, D items PASS | PENDING |  |  |
| G3 Production Candidate Ready | A through F items PASS | PENDING |  |  |
| G4 Final Release Signoff | All gates PASS with evidence attached | PENDING |  |  |

## H. Open Risks and Blockers
- Runtime model binaries (`.tflite`) not delivered yet for strict runtime-ready mode. Owner: Dev A. ETA: TBD.
- Runtime model binaries still missing (`efficientnet_lite0.tflite`, `mobilefacenet.tflite`). Owner: ML/runtime artifact owner. ETA: TBD.
- Flutter checks pass in no-space mirror path (`D:\GigCreditProdReady\gigcredit_app`); keep same setup for repeatable CI/local runs.
- Deployed backend URL and deployed-environment auth/rate-limit validation not finalized. Owner: Release + QA. ETA: TBD.

## I. Final Outcome
- Current outcome: NOT SIGNED OFF
- Required to close: Complete all pending Critical items and all release gates.

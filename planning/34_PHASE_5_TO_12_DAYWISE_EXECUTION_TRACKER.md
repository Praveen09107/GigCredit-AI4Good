# Phase 5 to 12 Day-wise Execution Tracker

Last Updated: 2026-03-20
Owners: Dev A, Dev B, QA, Release
Scope: Execution plan from scoring integration to release signoff

## Status Snapshot

| Phase | Title | Owner(s) | Status | Exit Criteria Status |
|---|---|---|---|---|
| 5 | Feature Engineering and Scoring Integration | Dev B + Dev A | COMPLETE | PASS (local evidence) |
| 6 | SHAP Runtime Integration | Dev B + Dev A | COMPLETE | PASS (local evidence) |
| 7 | Backend Verification API Productionization | Dev A + Dev B | COMPLETE | PASS (contract/auth smoke) |
| 8 | Database and Persistence Layer | Dev A + Release | COMPLETE | PASS (retention + persistence tests + policy doc) |
| 9 | LLM Report Service | Dev A + Dev B | COMPLETE | PASS (schema and immutability) |
| 10 | Frontend End-to-End UX Flow | Dev B + QA | IN PROGRESS | External device evidence pending |
| 11 | Production Readiness Gates | Dev B + Dev A + QA | COMPLETE | PASS (all local gates green; only external evidence pending) |
| 12 | Deployment and Release Signoff | Release + QA + Dev A | NOT STARTED | Waiting G1 to G4 progression |

## Day-wise Plan (Recommended)

### Day 1 (Dev B)
- Confirm Phase 5 and 6 evidence bundle.
- Freeze score determinism proof artifacts and SHAP golden references.
- Commands:
  - python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v
  - flutter test test/scoring_contract_guardrail_test.dart test/meta_learner_contract_test.dart test/shap_lookup_rendering_test.dart

### Day 2 (Dev A + Dev B)
- Close Phase 7 verification productionization checks.
- Validate verify.py endpoint contract, auth abuse, replay, and rate-limit protections.
- Commands:
  - python -m unittest backend.tests.test_contract_smoke -v

### Day 3 (Dev A)
- Phase 8 persistence hardening implementation.
- Add TTL and retention policy for verification/report/audit logs.
- Document migration and backup policy.
- Commands:
  - python -m unittest backend.tests.test_contract_smoke -v

### Day 4 (Dev A + Dev B)
- Confirm Phase 9 report service closure.
- Revalidate multilingual response schema and immutable numeric fields.
- Commands:
  - python -m unittest backend.tests.test_contract_smoke -v

### Day 5 (Dev B + QA)
- Execute Phase 10 full UX flow on supported physical devices.
- Capture OCR low-confidence, verification timeout, and report retry error-state proof.
- Evidence:
  - screen capture and trace ids
  - generated report snapshots (en, hi, ta)

### Day 6 (Dev B + Dev A + QA)
- Execute Phase 11 readiness gates.
- Commands:
  - python -m unittest backend.tests.test_contract_smoke -v
  - python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v
  - flutter analyze
  - flutter test
  - ./run_full_verify.ps1
- Validate artifact manifest integrity:
  - gigcredit_app/assets/constants/artifact_manifest.json

### Day 7 (Release + QA + Dev A)
- Execute Phase 12 staging soak, canary, and signoff.
- Complete planning/27_DEV_A_HANDOFF_SIGNOFF_CHECKLIST.md.
- Verify rollback bundle and release tag.

## Command Checklist by Phase

### Phase 5
- flutter test test/scoring_contract_guardrail_test.dart
- flutter test test/meta_learner_contract_test.dart

### Phase 6
- flutter test test/shap_lookup_rendering_test.dart

### Phase 7
- python -m unittest backend.tests.test_contract_smoke -v

### Phase 8
- python -m unittest backend.tests.test_contract_smoke -v
- Optional index/retention verification script run

### Phase 9
- python -m unittest backend.tests.test_contract_smoke -v

### Phase 10
- Physical-device flow execution (manual QA evidence)

### Phase 11
- ./run_full_verify.ps1

### Phase 12
- Final release tag + rollback verification + signoff checklist completion

## Current Blockers

- External-only QA evidence still pending:
  - physical-device E2E
  - deployed backend report E2E
- Release execution still pending:
  - staging soak and canary
  - release tag + rollback verification
- Runtime binary closure remains environment-dependent for final release signoff.

## External Execution Pack

- Runbook: planning/35_PHASE10_12_RELEASE_EXECUTION_RUNBOOK.md
- Evidence templates:
  - planning/evidence/phase10_12/phase10_device_matrix.md
  - planning/evidence/phase10_12/phase10_trace_log.md
  - planning/evidence/phase10_12/phase12_soak_report.md
  - planning/evidence/phase10_12/phase12_canary_report.md
  - planning/evidence/phase10_12/phase12_release_signoff.md

## Gate Mapping

- G1 Integration Ready: Phases 5 to 7 complete with evidence.
- G2 Pre-Production Ready: Phase 8 and 9 complete with retention and migration policy evidence.
- G3 Production Candidate Ready: Phase 10 and 11 complete including physical-device proof.
- G4 Final Release Signoff: Phase 12 complete and planning/27_DEV_A_HANDOFF_SIGNOFF_CHECKLIST.md marked PASS.

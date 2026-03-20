# Production Phase Execution TODO (44-Input Contract)

Last Updated: 2026-03-20
Scope: End-to-end production closure from on-device OCR to backend report generation.

## Phase 1 - Contract Freeze and Guardrails
- [x] Freeze 44-input meta contract across docs and runtime.
- [x] Lock feature slices and pillar naming consistency.
- [x] Add unit tests that fail on contract drift.
- [ ] Evidence:
	- `offline_ml/data/meta_coefficients.json`
	- `gigcredit_app/lib/scoring/scoring_engine.dart`
	- `gigcredit_app/test/scoring_contract_guardrail_test.dart`

## Phase 2 - On-Device OCR + Validation Hardening
- [x] Ensure OCR extraction paths and confidence thresholds are enforced.
- [x] Validate mandatory field and cross-document consistency checks.
- [x] Add regression tests for OCR-noise variants.

## Phase 3 - Verification Orchestration (Device + Backend)
- [x] Keep signed verification request path mandatory.
- [x] Enforce timeout/retry/error taxonomy for verify endpoints.
- [x] Add integration tests for success, timeout, and invalid-auth paths.

## Phase 4 - Scoring + SHAP Runtime Stability
- [x] Ensure score path uses frozen 44-input meta learner.
- [x] Ensure SHAP remains explanation-only.
- [x] Validate top-factor extraction against shipped lookup schema.

## Phase 5 - Backend Report Pipeline
- [x] Keep score and pillar values immutable in report request/response handling.
- [x] Validate multilingual response schema and fallback behavior.
- [x] Add contract tests for `/report/generate` envelope and fields.

## Phase 6 - DB + Deployment Readiness
- [x] Validate DB connectivity, indexing, and health telemetry.
- [x] Validate deployed URL wiring and auth/rate-limit behavior.
- [ ] Capture QA E2E evidence for physical-device and report generation.
	- Checklist: `planning/33_PHASE6_EXTERNAL_QA_EVIDENCE_CHECKLIST.md`

## Phase 7 - Backend Verification API Productionization
- [x] Finalize verification endpoints in verify.py.
- [x] Enforce auth, HMAC signature, replay window, and rate limiting in auth.py.
- [x] Add strict envelope response and error taxonomy.
- [x] Exit criteria: contract smoke and auth abuse tests pass.

## Phase 8 - Database and Persistence Layer
- [x] Harden DB connection, indexes, TTL/log retention.
- [x] Persist verification events, report requests, and audit traces.
- [x] Add migration and backup policy.
- [x] Exit criteria: health endpoint stable with db true; persistence and retrieval tests pass.

## Phase 9 - LLM Report Service
- [x] Build report generation path in llm_service.py.
- [x] Allow LLM to generate narrative and suggestions only.
- [x] Protect immutable score and pillar fields.
- [x] Add multilingual templates and fallback.
- [x] Exit criteria: schema validation pass; no mutation of computed numeric fields.

## Phase 10 - Frontend End-to-End UX Flow
- [ ] Complete user journey: document capture, verification progress, scoring state, report display/export.
- [ ] Add robust error states: OCR low confidence, verification API timeout, report generation retry.
- [ ] Exit criteria: successful full flow on supported devices.
	- Runbook: planning/35_PHASE10_12_RELEASE_EXECUTION_RUNBOOK.md

## Phase 11 - Production Readiness Gates
- [x] Run mandatory checks: backend smoke, offline artifact smoke, flutter analyze, full flutter test.
- [x] Startup strict gate checks.
- [x] Verify runtime binaries and manifest integrity in artifact_manifest.json.
- [x] Exit criteria: all gates green, blocker list reduced to external-only items.

## Phase 12 - Deployment and Release Signoff
- [ ] Configure production backend URL and keys.
- [ ] Execute staging soak and canary release.
- [ ] Run QA physical-device E2E and report E2E.
- [ ] Complete final signoff checklist in planning/27_DEV_A_HANDOFF_SIGNOFF_CHECKLIST.md.
- [ ] Exit criteria: G1 to G4 gates pass; release tagged and rollback bundle verified.
	- Runbook: planning/35_PHASE10_12_RELEASE_EXECUTION_RUNBOOK.md

## Mandatory Test Gates (Run after each completed phase)
- `python -m unittest backend.tests.test_contract_smoke -v`
- `python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v`
- `flutter analyze`
- `flutter test`

## Current Active Phase
- Phase 10

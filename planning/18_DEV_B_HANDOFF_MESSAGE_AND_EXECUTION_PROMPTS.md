# Dev B Handoff Message and Detailed Execution Prompts

Last Updated: 2026-03-19  
Owner: Dev A handoff package  
Purpose: Ready-to-send handoff content + detailed prompts/checklists for high-confidence Dev B integration.

---

## 1) Ready-to-send handoff message (Slack/Email)

Subject: Dev A integration-ready handoff (contracts, artifacts, runtime gate, test baselines)

Hi Dev B,

Dev A implementation is now integration-ready on `main`.

### What is ready now

1. Backend verify/report contract stack with auth hardening and compatibility aliases.
2. Offline ML scorer + constants artifact handoff in app-consumable paths.
3. On-device runtime integration surfaces (OCR/authenticity/face contracts + capability gating).
4. Production-readiness startup gate (blocks app when strict mode is enabled and required capabilities are missing).
5. Test baselines passing for backend, offline ML artifacts, and Flutter app tests.

### Primary docs to read first

1. `planning/17_DEV_A_FINAL_CROSSCHECK_AND_INTEGRATION_GUIDE.md`
2. `planning/16_DEV_A_REQUIRED_IMPLEMENTATION_FROM_WORKFLOW_AND_DEV_B_PLAN (1).md`
3. `planning/15_DEV_B_IMPLEMENTATION_PERCENTAGE_AND_DEV_A_BLOCKERS (1).md`
4. `gigcredit_app/lib/ai/NATIVE_BRIDGE_CONTRACT.md`

### Immediate integration instructions

1. Pull latest `main`.
2. Run baseline checks:
   - `python -m unittest backend.tests.test_contract_smoke -v`
   - `python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v`
   - `flutter analyze`
   - `flutter test test`
3. Integrate step flows to consume real Dev A runtime/scorer outputs (remove residual stubs in production paths).
4. Keep generated scorer artifacts immutable (no manual edits).
5. Use production gate modes properly:
   - integration mode: `GIGCREDIT_REQUIRE_PRODUCTION_READINESS=false`
   - release/UAT mode: `GIGCREDIT_REQUIRE_PRODUCTION_READINESS=true`

### Known external blockers (not code-gap)

1. Real model files must be present under `gigcredit_app/assets/models/`.
2. Android packaging/dependency closure in full Android project context must be finalized.
3. Physical-device E2E + deployed-backend signoff still required for final production declaration.

Please proceed with integration. If you need schema/contract changes, update contract docs first and then implement both producer and consumer paths in one PR.

Thanks.

---

## 2) Detailed “integration execution prompt” (for Dev B or AI assistant)

Use this prompt as-is for a structured integration run.

PROMPT START

You are integrating Dev A-delivered runtime/scoring/backend contract changes into Dev B flow on GigCredit.

### Objectives

1. Integrate Dev A work into all relevant Dev B steps without regressions.
2. Preserve generated artifact integrity and avoid ownership boundary conflicts.
3. Verify strict production-mode behavior and normal integration-mode behavior.

### Read these files first

- `planning/17_DEV_A_FINAL_CROSSCHECK_AND_INTEGRATION_GUIDE.md`
- `planning/16_DEV_A_REQUIRED_IMPLEMENTATION_FROM_WORKFLOW_AND_DEV_B_PLAN (1).md`
- `planning/15_DEV_B_IMPLEMENTATION_PERCENTAGE_AND_DEV_A_BLOCKERS (1).md`
- `gigcredit_app/lib/ai/NATIVE_BRIDGE_CONTRACT.md`
- `gigcredit_app/lib/ai/ai_native_bridge.dart`
- `gigcredit_app/lib/ai/native_document_processor.dart`
- `gigcredit_app/lib/state/startup_self_check_provider.dart`
- `gigcredit_app/lib/ui/startup_self_check_gate.dart`

### Hard constraints

1. Do not manually edit generated scorer files under:
   - `gigcredit_app/lib/scoring/generated/`
2. Do not manually edit:
   - `gigcredit_app/assets/constants/artifact_manifest.json`
3. If schema/contract needs change, update docs + producer + consumer in one atomic change.
4. Keep fallback behavior for integration mode and strict blocking behavior for production mode.

### Baseline checks (must pass before edits)

- `python -m unittest backend.tests.test_contract_smoke -v`
- `python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v`
- `flutter analyze`
- `flutter test test`

### Integration tasks

1. Wire step-level flow to use real Dev A runtime/provider outputs.
2. Ensure confidence/metadata from runtime/scoring outputs are consumed where UX/report logic needs them.
3. Ensure route usage supports current backend compatibility (`/verify/*` and existing canonical paths).
4. Validate startup gate behavior:
   - strict mode off -> flow should proceed
   - strict mode on + missing prerequisites -> flow must block
5. Validate end-to-end step progression with no mock-only production path remaining.

### Validation after integration

1. Re-run full baseline checks.
2. Perform a manual app walkthrough in integration mode.
3. Perform a strict-mode startup gate validation walkthrough.
4. Produce a short integration report: changed files, risks, unresolved blockers.

### Output format for release closure

Provide:

1. What was integrated (file-by-file).
2. What remains blocked externally.
3. Exact commands run and pass/fail results.
4. Next actions for Dev A / Dev B / QA.

PROMPT END

---

## 3) Detailed “production readiness closure prompt” (Dev A + Dev B + QA)

PROMPT START

You are conducting final production-readiness closure for GigCredit after Dev A and Dev B integration.

### Required completion gates

1. Real model assets present in app package paths:
   - `gigcredit_app/assets/models/efficientnet_lite0.tflite`
   - `gigcredit_app/assets/models/mobilefacenet.tflite`
2. Android runtime/dependency packaging closure verified in real Android project context.
3. Backend deployed URL configured and reachable.
4. Startup self-check gate passes in strict mode.
5. Physical-device E2E run passes from entry to final report generation.

### Strict mode execution requirements

Set and verify:

- `GIGCREDIT_REQUIRE_PRODUCTION_READINESS=true`
- `GIGCREDIT_BACKEND_BASE_URL=<deployed_backend_url>`

Confirm app behavior:

1. If any required capability missing -> startup gate blocks and explains why.
2. If all capabilities available -> app proceeds to normal flow.

### Test and validation commands

1. Backend smoke:
   - `python -m unittest backend.tests.test_contract_smoke -v`
2. Artifact smoke:
   - `python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v`
3. App analysis and tests:
   - `flutter analyze`
   - `flutter test test`
4. Device runbook:
   - execute complete user journey
   - capture logs/screenshots for each stage

### Acceptance criteria

1. No failing automated checks.
2. Strict-mode startup gate semantics verified.
3. Final score generation path verified with current scorer artifacts.
4. Report generation path verified against deployed backend.
5. Evidence captured in planning docs for signoff.

### Output format

Provide a release gate table:

- Gate name
- Owner
- Evidence
- Status (PASS/FAIL)
- Blocker (if FAIL)
- ETA and next action

PROMPT END

---

## 4) Dev B implementation checklist after pulling repo (actionable)

## 4.1 Must-do integration checklist

1. Pull latest `main` and sync branch.
2. Run all baseline checks before editing.
3. Integrate runtime contract usage into each relevant step flow.
4. Verify startup gate in both integration and strict production mode.
5. Remove residual step-level mock-only dependencies from production paths.
6. Re-run full tests and document outcomes.

## 4.2 Conflict-avoidance checklist

1. Never hand-edit generated scorer files.
2. Never hand-edit artifact manifest.
3. Don’t bypass startup gate semantics in strict mode.
4. Don’t introduce parallel contracts; evolve existing contract docs instead.
5. Use one PR for each coherent contract-and-consumer change.

## 4.3 Delivery checklist for Dev B PR

1. Include list of integrated Dev A surfaces.
2. Include test logs (backend + offline ML + flutter analyze + flutter test).
3. Include strict-mode startup behavior evidence.
4. Include remaining external blockers (if any).

---

## 5) Remaining work map (after push + pull)

## 5.1 Remaining Dev A / platform tasks

1. Provide final model binaries in `gigcredit_app/assets/models/`.
2. Validate Android dependency/runtime closure in full build context.
3. Confirm deployment URL and release config handoff.

## 5.2 Remaining Dev B tasks

1. Complete full-step integration to real runtime outputs.
2. Ensure confidence/metadata are consumed in final scoring/report flow.
3. Complete full UX regression after integration.

## 5.3 Remaining joint QA/UAT tasks

1. Physical-device E2E in production-like environment.
2. Final report generation validation against deployed backend.
3. Signoff record update in planning docs.

---

## 6) Quick copy-paste command block

### Backend + ML checks

- `python -m unittest backend.tests.test_contract_smoke -v`
- `python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v`

### Flutter checks

- `flutter analyze`
- `flutter test test`

### Windows path workaround (if needed)

1. `subst X: "d:\Program Files\GigCredit"`
2. `cd X:\gigcredit_app`
3. Run Flutter commands from there.

---

## 7) Final status statement you can share

Dev A is complete for integration handoff, and Dev B can integrate immediately using the provided contracts, artifacts, and startup policy behavior. Final production-grade real-world prototype signoff remains dependent on model asset provisioning, platform packaging closure, and physical-device/deployed-environment E2E evidence.

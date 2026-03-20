# Phase 10 and 12 Release Execution Runbook

Last Updated: 2026-03-20
Owners: QA, Release, Dev A, Dev B
Scope: External execution closure for Phase 10 and Phase 12

## Objective
Close remaining external-only gates with reproducible evidence capture and signoff-ready artifacts.

## Preconditions
- Deployed backend URL is reachable from physical devices.
- API key and signed-request headers are configured in runtime environment.
- Strict mode enabled on app and backend.
- Runtime model binaries are present in app package.

## Phase 10: Frontend End-to-End UX Flow

### Test Matrix
1. Device set
- Low-end Android
- Mid-tier Android
- Primary release target Android

2. Mandatory flow coverage
- Document capture
- Verification progress
- Scoring completion
- Report display and export

3. Mandatory error-state coverage
- OCR low confidence
- Verification API timeout
- Report generation retry

### Evidence to collect
- Screen recording for full successful flow.
- Screen recording for each error-state path.
- Trace IDs for backend interactions used in the flow.
- Saved report output snapshot.

### Output files
- planning/evidence/phase10_12/phase10_device_matrix.md
- planning/evidence/phase10_12/phase10_trace_log.md
- planning/evidence/phase10_12/phase10_issues.md

## Phase 12: Deployment and Release Signoff

### Staging soak
- Duration: minimum 2 hours.
- Monitor: health endpoint stability, response envelope consistency, error-rate anomalies.

### Canary release
- Deploy to limited cohort.
- Validate auth/rate-limit behavior in live environment.
- Validate report generation and storage path stability.

### Release signoff artifacts
- Build/tag identifier.
- Rollback bundle identifier and restore verification note.
- Final gate checklist updates in planning/27_DEV_A_HANDOFF_SIGNOFF_CHECKLIST.md.

### Output files
- planning/evidence/phase10_12/phase12_soak_report.md
- planning/evidence/phase10_12/phase12_canary_report.md
- planning/evidence/phase10_12/phase12_release_signoff.md

## Completion Conditions

Phase 10 complete when:
- successful full flow captured on supported devices
- all required error-state evidence captured

Phase 12 complete when:
- soak and canary reports approved
- rollback verification documented
- G1 to G4 marked PASS in planning/27_DEV_A_HANDOFF_SIGNOFF_CHECKLIST.md

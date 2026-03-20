# Phase 6 External QA Evidence Checklist

Date: 2026-03-20
Owner: Release QA / Device validation
Status: Pending external execution

## Goal
Collect production sign-off evidence that cannot be generated from local CI-only execution.

## Preconditions
- Deployed backend URL is reachable from physical test device.
- Valid API key and signing path enabled on mobile build.
- Strict mode enabled in app and backend.
- Native model files present on device build.

## Required Evidence Set

1. Device and build metadata
- Device model, Android version, app build/version.
- Build flags showing strict mode enabled.

2. Health and auth evidence
- Backend `/health` response captured with `ok`, `db`, `indexes_ready`.
- One signed verification success trace and one auth failure trace.
- One rate-limit rejection trace (429) from device-driven sequence.

3. End-to-end workflow evidence
- Full user flow capture from onboarding to report generation.
- Report generation success envelope with `trace_id`.
- Stored-report confirmation (`/report/store`) if used in release flow.

4. Multilingual report evidence
- At least one generated report each for English, Hindi, Tamil paths.
- Snapshot of summary + suggestions payload fields for each language.

5. Immutability proof
- Request payload score/pillars and returned score/pillars match exactly.
- No server-side mutation in final report response.

## Recommended Capture Commands

- Backend smoke baseline:
  - `python -m unittest backend.tests.test_contract_smoke -v`
- Full local regression baseline:
  - `./run_full_verify.ps1`

## Sign-off Criteria
- All local gates are green.
- All required external evidence artifacts are attached.
- Release reviewer confirms trace IDs and payload integrity checks.

## Evidence Artifacts Directory (recommended)
- `planning/evidence/phase6/`
  - `device_metadata.txt`
  - `health_response.json`
  - `verify_success_trace.json`
  - `verify_auth_failure_trace.json`
  - `rate_limit_trace.json`
  - `report_en.json`
  - `report_hi.json`
  - `report_ta.json`
  - `e2e_recording_link.txt`

# GigCredit Production Execution TODO Tracker (2026-03-19)

Legend:
- DONE: completed and validated in this workspace
- IN_PROGRESS: partially complete, additional work required
- BLOCKED_EXTERNAL: requires external assets/deployment/device execution

## Core Runtime and AI

- [DONE] Activate native AI bridge in launched Android package path.
- [DONE] Compile and build Android with native AI channel and TFLite hooks.
- [DONE] Enforce production-mode OCR strict path (no silent fallback decode in strict mode).
- [DONE] Replace Step-2 upload-only face pass with native face matching attempt.
- [DONE] Disallow mock/heuristic AI modes when production readiness is enabled.
- [BLOCKED_EXTERNAL] Add production model binaries:
  - `gigcredit_app/assets/models/efficientnet_lite0.tflite`
  - `gigcredit_app/assets/models/mobilefacenet.tflite`

## Scoring and Explainability

- [DONE] 95-feature engineering + sanitization pipeline validated by tests.
- [DONE] Meta learner + generated scorer integration validated by tests.
- [DONE] Explicit scorecard modules wired for P5/P7/P8 (`scorecard_p5.dart`, `scorecard_p7.dart`, `scorecard_p8.dart`).
- [DONE] SHAP lookup loading and rendering validated by tests.
- [IN_PROGRESS] Final production calibration/UAT with real model artifacts and judge demo data.

## Backend and Database

- [DONE] Verification/report API contracts validated in backend smoke tests.
- [DONE] Added `/verify/gst` and typed utility route compatibility.
- [DONE] Verification/report API logging persistence to Mongo implemented.
- [DONE] Verification lookups aligned to production collection contract names with legacy fallbacks:
  - `pan_records`
  - `aadhaar_records`
  - `bank_records`
  - `scheme_records`
- [BLOCKED_EXTERNAL] Populate and verify production Mongo datasets for all required verification records.

## Security and Startup Gates

- [DONE] Strict startup gate blocks when backend/native capabilities are missing.
- [DONE] Integration mode still allows non-production flow.
- [DONE] Production report scoring now enforces all workflow steps as verified before scoring/report generation.
- [DONE] Backend strict mode disables fallback LLM report templates when Gemini key/runtime is unavailable.
- [IN_PROGRESS] Final security review evidence pack (secrets policy, device hardening, API key ops).

## End-to-End Delivery

- [DONE] Automated 9-step progression/state tests passing.
- [DONE] Backend contract smoke tests passing.
- [DONE] Debug APK build passing.
- [BLOCKED_EXTERNAL] Physical-device E2E proof (camera/OCR/face + Step1->Step9->Report).
- [BLOCKED_EXTERNAL] Deployed backend URL + production env secret wiring.

## Verification Commands (latest run)

- `python -m unittest backend.tests.test_contract_smoke -v` -> PASS
- `flutter test test/startup_self_check_provider_test.dart test/startup_self_check_gate_test.dart test/feature_pipeline_test.dart test/scoring_engine_test.dart test/scorecard_modules_test.dart` -> PASS
- `flutter build apk --debug` -> PASS

## Exit Criteria for Production-Ready

1. Model binaries present and validated on real device runtime.
2. Production backend deployed and reachable from app strict mode.
3. Physical-device full flow evidence captured and archived.
4. Mongo production collections populated and returning expected verification hits.
5. Final judge/demo script dry-run completed without fallback paths.

# GigCredit Production Evidence Pack

Date: 2026-03-20
Owner: Dev B implementation pass

## Scope Completed

- Enforced strict runtime hard-fail behavior in native AI wrappers.
- Replaced p5/p7/p8 scorecards with trained offline ML models and generated Dart scorers.
- Expanded cross-domain verification validation graph (name/IFSC/income consistency + API cross-checks).
- Ran backend and Flutter regression tests, including strict-mode subset.
- Stabilized report export test path (font/runtime + test harness updates) and validated strict batch.
- Added release-readiness tooling for model placeholder mode + fast Dev A artifact swap.

## Key Artifacts Generated

- Offline models:
  - `offline_ml/models/p1.pkl`
  - `offline_ml/models/p2.pkl`
  - `offline_ml/models/p3.pkl`
  - `offline_ml/models/p4.pkl`
  - `offline_ml/models/p5.pkl`
  - `offline_ml/models/p6.pkl`
  - `offline_ml/models/p7.pkl`
  - `offline_ml/models/p8.pkl`
- Exported Dart scorers (packaged to app):
  - `gigcredit_app/lib/scoring/generated/p1_scorer.dart` ... `p8_scorer.dart`
- Constants and manifest:
  - `gigcredit_app/assets/constants/meta_coefficients.json`
  - `gigcredit_app/assets/constants/shap_lookup.json`
  - `gigcredit_app/assets/constants/state_income_anchors.json`
  - `gigcredit_app/assets/constants/feature_means.json`
  - `gigcredit_app/assets/constants/artifact_manifest.json`
- Validation report:
  - `offline_ml/data/validation_report.json` => `PASS`

## Commands and Results

1. Offline ML generation/export/validation/package
- `python -m offline_ml.src.data_generator --profiles 12000` => PASS
- `python -m offline_ml.src.train_final` => PASS
- `python -m offline_ml.src.export_to_dart` => PASS
- `python -m offline_ml.src.train_meta_learner` => PASS
- `python -m offline_ml.src.extract_shap` => PASS
- `python -m offline_ml.src.validate_export` => PASS
- `python -m offline_ml.src.package_artifacts_for_app` => PASS

2. Backend smoke
- `python -m unittest tests.test_contract_smoke -v` => PASS (9 tests)

3. Flutter tests
- Core changed flows:
  - `flutter test test/scoring_engine_test.dart test/verification_validation_engine_test.dart test/startup_self_check_provider_test.dart` => PASS
- Broad suite (excluding flaky script):
  - `flutter test <all tests except generate_report_script.dart>` => PASS (37 tests)
- Strict-mode subset:
  - `flutter test test/startup_self_check_provider_test.dart test/scoring_engine_test.dart --dart-define=GIGCREDIT_REQUIRE_PRODUCTION_READINESS=true` => PASS (6 tests)
- Strict-mode production batch:
  - `flutter test test/startup_self_check_gate_test.dart test/integration_9_step_progression_test.dart test/step3_to_step9_linkage_test.dart test/scoring_engine_test.dart test/verification_validation_engine_test.dart test/generate_report_script.dart --dart-define=GIGCREDIT_REQUIRE_PRODUCTION_READINESS=true` => PASS (11 tests)

4. Static analysis
- `flutter analyze` => no errors; info-level lint findings remain.

5. Release readiness tooling
- `dart run tool/check_release_readiness.dart --allow-placeholder-models` => PASS
- Script path: `gigcredit_app/tool/check_release_readiness.dart`

## Known Limitation

- Native model artifacts from Dev A are pending handoff (placeholder mode active).
- Until `assets/models/efficientnet_lite0.tflite` and `assets/models/mobilefacenet.tflite` are supplied, strict startup gate will correctly block true production startup on device.

## Ready-for-Review Summary

- p5/p7/p8 are now trained/exported/packaged and used by runtime scoring engine.
- Cross-domain validation graph has been expanded and tested.
- Strict-mode automated proof batch passes, including report generation script.
- Remaining gate is Dev A native model drop + final on-device strict evidence capture.

## Phase 6 Addendum (2026-03-20)

### Backend readiness hardening evidence

- Startup index assurance added for critical Mongo collections.
- Health telemetry expanded to include `indexes_ready` alongside `ok` and `db`.
- Signed-auth negative-path checks extended:
  - invalid signature -> 401
  - forced rate-limit -> 429
- Deployment wiring assertion added:
  - `MONGO_URI` must not contain placeholders and must not target localhost.

### Commands and results

1. Backend contract smoke
- `python -m unittest backend.tests.test_contract_smoke -v` => PASS (31 tests)

2. Offline ML artifact handoff smoke
- `python -m unittest offline_ml.tests.test_artifact_handoff_smoke -v` => PASS (2 tests)

3. Flutter static analysis
- `flutter analyze` => PASS with warnings/info only (no errors)

4. Flutter full suite
- `flutter test` => PASS (88 tests)

5. Full verification battery
- `./run_full_verify.ps1` => PASS

### Remaining external evidence (not capturable from this workspace)

- Physical Android device run under strict mode with backend-connected flow.
- E2E proof from user input through final generated report on deployed backend URL.
- Attached artifacts required for sign-off:
  - device screen recording/screenshots,
  - backend request/response trace IDs,
  - generated report snapshot for each supported language path.

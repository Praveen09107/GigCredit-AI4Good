# Dev A Required Implementation (From Full Workflow + Dev B Plan)
Last Updated: 2026-03-19
Scope: Exact Dev A deliverables needed to close full system

## Source Plans
- planning/5_DEV_A_EXECUTION_PLAN.md
- planning/14_DEV_A_INTEGRATION_GUIDE.md
- planning/6_DEV_B_EXECUTION_PLAN.md
- planning/3_END_TO_END_WORKFLOW_FREEZE.md
- planning/1_SCORING_ENGINE_SPEC_FREEZE.md

## P0 - Mandatory Deliverables to Unblock Completion

### 1) Backend APIs (Production-Ready)
Implement and deploy fully functional endpoints:
- POST /verify/pan
- POST /verify/aadhaar
- POST /verify/bank/ifsc
- POST /verify/bank/account
- POST /verify/vehicle/rc
- POST /verify/insurance
- POST /verify/income-tax/itr
- POST /verify/eshram
- POST /verify/loan
- POST /report/generate

Must include:
- Real request validation
- Real response schema consistency
- Error handling and fallback behavior
- Authentication and rate limiting (API key + HMAC path from hardening spec)

### 2) Offline ML Artifact Handoff
Deliver these artifacts in app-consumable format:
- p1_scorer.dart
- p2_scorer.dart
- p3_scorer.dart
- p4_scorer.dart
- p5_scorer.dart
- p6_scorer.dart
- assets/constants/meta_coefficients.json
- assets/constants/shap_lookup.json (final version)

Must satisfy frozen scoring rules:
- Final score path is LR meta-learner
- Score mapping is round(300 + sigmoid(logit) * 600)
- No weighted-sum fallback as final scoring mode

### 3) AI Runtime Implementations
Implement concrete classes for:
- OcrEngine
- AuthenticityDetector
- FaceVerifier
- DocumentProcessor (orchestration)

Then wire via DI so Dev B step screens can call real implementations.

## P1 - Integration Tasks in App Layer
(Dev A-owned as per integration guide)

1. Set deployed backend base URL in backend_client.dart.
2. Place scorer Dart files in expected scoring location.
3. Place meta_coefficients.json in assets/constants.
4. Ensure pubspec asset entries include constants files.
5. Load real coefficients in dev_a_handoff_adapter.dart path.
6. Load final SHAP bins in shap_lookup_service.dart path.
7. Add/create DI wiring file for AI implementations.
8. Replace step-level stubs with real AI/provider calls.

## P2 - Validation and Acceptance
Before declaring Dev A complete:

1. Run flutter analyze with zero errors.
2. Run flutter test and keep current suite green.
3. Execute physical-device end-to-end flow:
- Login/OTP
- KYC
- Bank parsing
- EMI stage
- Scoring
- Explainability
- Final PDF report
4. Validate score reproducibility against provided artifacts.
5. Validate report/generate backend output schema and language behavior.

## Step-wise Dev A Mapping to Workflow

- Entry and auth: backend auth headers + secure API checks
- Step 2: PAN/Aadhaar verification services
- Step 3: bank verify endpoints + bank compatibility support
- Steps 4 to 8: verification endpoints + OCR authenticity interfaces
- Step 9: loan verification endpoint behavior
- Final report: report/generate explanation service
- Scoring core: p1..p6 scorers + meta coefficients + SHAP asset

## Final Closure Condition
Dev A is considered fully complete only when:
1. All backend verify/report endpoints are implemented and live.
2. All ML scorer and coefficient artifacts are delivered and integrated.
3. AI interface implementations are wired and used in runtime.
4. End-to-end mobile run produces final score and PDF report without mock/stub fallbacks.

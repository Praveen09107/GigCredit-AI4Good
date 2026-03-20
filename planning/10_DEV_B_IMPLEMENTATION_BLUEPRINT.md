# Dev B Implementation Blueprint (Pre-Implementation Freeze)

Date: 2026-03-18
Owner: Developer B
Status: Pre-implementation plan (detailed)

## 1) Purpose of this document
This document defines exactly what Dev B will implement before coding starts, aligned with frozen planning documents and resolved contradictions.

This blueprint is the execution contract for:
- Workflow implementation
- On-device pipeline implementation
- UI and state behavior
- Scoring and explainability integration
- Testing and quality gates

## 2) Authoritative references (in priority order)
1. planning/1_SCORING_ENGINE_SPEC_FREEZE.md
2. planning/3_END_TO_END_WORKFLOW_FREEZE.md
3. planning/2_BACKEND_HARDENING_SPEC.md
4. planning/6_DEV_B_EXECUTION_PLAN.md
5. planning/9_DEV_B_SPEC_FIX_CHECKLIST.md

If any older spec conflicts with the above, these references win.

## 3) Scope boundaries for Dev B

### Dev B owns
- Flutter app architecture and routing
- UI screens and reusable widgets
- Step flow orchestration (9 visible steps)
- Session persistence and recovery
- Bank parsing, transaction tagging, EMI analysis trigger
- Feature engineering (95 features)
- Scoring orchestration with LR final score logic
- SHAP lookup-based insights rendering
- Report UI and PDF generation
- Unit/integration/widget tests for app-side logic

### Dev B does not own
- Backend API implementation and deployment
- ML training, tuning, export pipeline
- Native AI engine internals (OCR model runtime, face model runtime, fraud model runtime)

## 4) Frozen architecture decisions Dev B will implement

### 4.1 On-device vs backend split
On-device:
- Workflow state machine
- OCR result consumption
- Field validation and cross-check orchestration
- Bank parsing, feature engineering, scoring, insights, PDF

Backend:
- Verification APIs
- LLM explanation generation
- Optional report storage

### 4.2 Scoring method freeze
- Final score is LR meta-learner only
- Final score formula: round(300 + sigmoid(logit) * 600)
- Final score range: 300 to 900
- Weighted-sum final score is not allowed

### 4.3 Explainability freeze
- Runtime explainability is lookup-only from precomputed SHAP bins
- No real-time SHAP computation on device

### 4.4 Step model freeze
- 9 user-visible steps in UI
- Step-9 represents EMI/loan behavior stage in the user flow
- Step-9 is populated from Step-3 bank analysis outputs and shown to the user as a visible stage

## 5) UI implementation strategy

### 5.1 Theme usage rule
- Use only the selected app theme values (colors, typography, spacing tokens)
- Do not copy external template layout structure
- Keep one consistent app-wide visual system
- Theme uniformity is mandatory across all screens, steps, popups, loaders, report, and PDF styling.
- No mixed button/card styles between screens; shared components must consume the same theme tokens.

### 5.2 Home screen media rule
- Home screen must include 4 photos from the home page photo folder
- Use these exact files from `home page photos/`:
  - `WhatsApp Image 2026-03-15 at 10.16.06 PM.jpeg`
  - `WhatsApp Image 2026-03-15 at 5.38.15 PM.jpeg`
  - `WhatsApp Image 2026-03-15 at 5.38.17 PM.jpeg`
  - `WhatsApp Image 2026-03-15 at 7.53.24 PM.jpeg`
- Cards represent:
  1) Identity Verification
  2) Bank Analysis
  3) AI Fraud Detection
  4) Credit Scoring

### 5.3 UX behavior rules
- Every network/processing action shows clear loading state
- Continue buttons disabled until valid input
- Step status states: Not Started, In Progress, Verified
- Error UI includes actionable retry path

### 5.4 Theme source lock
- Use theme values from `theme/original-a426c342fc461673a08eb422baac4bba.webp` as visual reference tokens only.
- Do not copy that template's layout/structure; apply GigCredit's own screen structure.

### 5.5 Multilingual scope lock
- Multilingual support is report-only in this phase.
- Rest of app UI remains single language for now.

### 5.6 Validation architecture lock (applies to every step)
Each step must implement all 4 layers in order:
1. Individual Validation (on device)
2. Cross Internal Validation (within same step)
3. Cross Step Validation (against verified global profile)
4. Server Verification (when step has API-backed identifiers)

No step is marked verified unless all applicable layers pass.

## 6) Workflow implementation plan (end-to-end)

### 6.1 Entry and auth flow
1. Login screen with mobile input and OTP flow hooks
2. Auth success routes to Home
3. Home includes hero, 4 cards, Get Started CTA
4. Get Started popup routes to:
   - Continue to Step-1
   - Input Guidelines screen

### 6.2 Input Guidelines
- Show pre-verification guidance cards
- Include step intent, required/optional markers, and usage notes
- CTA to proceed into verification flow

### 6.3 Step orchestration (9 visible steps)
1. Step-1 Basic Profile
2. Step-2 KYC (Aadhaar, PAN, selfie)
3. Step-3 Bank Verification and statement processing
4. Step-4 Utility Bills
5. Step-5 Work Proof (dynamic by work type)
6. Step-6 Government Schemes
7. Step-7 Insurance
8. Step-8 ITR/GST
9. Step-9 EMI and Loan Behavior Stage (user-visible, data derived from bank analysis)

Post-Step-3:
- Trigger EMI auto-analysis and write output to profile state.
- Feed analyzed output into Step-9 visible stage.

Step-specific lock from latest validation spec:
- Step-4 mandatory utilities: Electricity, Gas/LPG, Mobile.
- Step-4 optional utilities: Rent, WiFi/Broadband, OTT.
- Step-4 EB rule: do not validate EB customer name against Step-1 (landlord name may appear).
- Step-4 Gas rule: allow offline/cash payment without strict bank-match rejection.
- Step-5 all inputs optional; if provided, verification/validation must run before use.
- Step-7 all insurance inputs optional except vehicle insurance is required when Step-1 has vehicle ownership = Yes.
- Step-8 optional input; if provided, perform full validation and verification pipeline.

### 6.4 Completion flow
- Verification complete screen
- Language selection
- Report loading
- Final report screen
- PDF download/share

## 7) Data and state architecture

### 7.1 Core state objects
- VerifiedProfileState
- StepFlowState
- ScoreState
- SessionSnapshot

### 7.2 Persistence policy
Persist after each verified step:
- encrypted verified_profile payload
- step progress metadata

Session restore rules:
- Resume if valid and not expired
- Reset to Step-1 if expired

### 7.3 Offline behavior
When offline for verification calls:
- Mark step as pending verification
- Keep captured data locally
- Retry verification when network returns

## 8) On-device processing pipeline (Dev B side)

### 8.1 Document processing consumption pipeline
Dev B orchestrates around Dev A interfaces:
1. Capture/select input
2. Pass to document processor interface
3. Receive extracted fields and status
4. Run app-side validations and cross-checks
5. Store only verified fields for scoring path

Input-format gate (mandatory before API calls):
- PAN, Aadhaar, IFSC, vehicle number, scheme IDs, policy numbers, and ITR acknowledgement must pass on-device format validation first.
- If format invalid, block API call and show field-level error.

OCR reliability gate (mandatory):
- Apply OCR confidence threshold.
- If confidence is below threshold (recommended 0.85), request re-upload.
- Apply field-level sanity checks (numeric/date/range constraints) before accepting OCR values.

### 8.2 Bank analysis pipeline
1. Parse statement text into transaction objects
2. Tag transaction categories
3. Detect recurring EMI patterns
4. Compute debt-to-income signals
5. Update profile with derived obligations

Parser constraint from fix spec:
- Prototype stage supports bank-specific parsing modules for SBI, HDFC, ICICI.
- If unsupported format is detected, show explicit unsupported-bank-statement message.

### 8.3 Feature engineering pipeline
1. Build 95-length feature vector
2. Apply sanitization (NaN/Inf fallback and clamps)
3. Validate vector length and bounds
4. Log warnings for fallback substitutions

### 8.4 Scoring pipeline
1. Slice features by pillar mapping
2. Run ML pillar scorer functions from provided Dart scorers
3. Run scorecard pillars (P5/P7/P8)
4. Apply confidence handling rules
5. Compute final LR score in 300-900 range
6. Assign grade and risk band

ITR consistency tolerance lock (Step-8):
- Compare bank-derived monthly income vs ITR monthly expected income using tolerance band.
- Use ±40% tolerance for anomaly flagging.
- Out-of-band result sets consistency flag; it must not hard-reject otherwise valid ITR upload.

### 8.5 Explainability pipeline
1. Load precomputed SHAP lookup constants
2. Map feature values to bins
3. Derive top positive and negative drivers
4. Render concise user-facing insights

### 8.6 Report pipeline
1. Generate backend explanation request payload
2. Receive explanation and suggestions
3. Render final report sections
4. Generate and export PDF

## 9) Integration dependencies from Dev A
Dev B can progress with mocks first, then integrate real artifacts.

Required from Dev A:
- API contract and base URL
- Auth headers format for request signing
- Stable AI interfaces
- Scorer files:
  - lib/scoring/p1_scorer.dart
  - lib/scoring/p2_scorer.dart
  - lib/scoring/p3_scorer.dart
  - lib/scoring/p4_scorer.dart
  - lib/scoring/p6_scorer.dart
- Constants:
  - assets/constants/meta_coefficients.json
  - assets/constants/shap_lookup.json

## 10) Testing plan and quality gates

### 10.1 Unit tests
- Feature vector determinism and length checks
- Scoring formula and bounds checks
- Confidence rule behavior

### 10.2 Integration tests
- End-to-end step navigation and state updates
- Step-3 triggers internal EMI analysis
- Offline and retry behavior

### 10.3 Widget tests
- Home screen card rendering with 4 images
- Step progress UI consistency
- Final report rendering and PDF trigger

### 10.4 Golden checks (must pass)
1. Golden feature-vector test
2. Golden score test
3. 9-step visibility test
4. SHAP lookup rendering test
5. Theme uniformity visual regression checks across key screens

## 11) Delivery sequence (implementation order)
1. App shell, router, providers, base theme wiring
2. Home, popup, guidelines, common widgets
3. Step framework + reusable form and upload components
4. Step-1 to Step-3 core flow
5. Bank parser + tagging + EMI internal step
6. Step-4 to Step-8 screens and state wiring
7. Feature engineering + sanitizer
8. Scoring engine + meta-learner + explainability
9. Report loading, final report, PDF
10. Test suite completion and regression pass

## 12) Risks and mitigations

Risk 1: Dev A handoff delay
- Mitigation: mock-first development and dependency inversion

Risk 2: Endpoint schema mismatch
- Mitigation: typed request/response adapters and contract fixtures

Risk 3: Device variance (camera/OCR/performance)
- Mitigation: emulator + at least one physical Android validation pass

Risk 4: Feature drift
- Mitigation: golden vector/score tests and strict index checks

Risk 5: Legacy spec confusion
- Mitigation: follow frozen references only and ignore superseded scoring/runtime text

## 13) Non-goals for this phase
- Backend code changes
- ML retraining pipeline changes
- Production security hardening beyond frozen MVP profile

## 14) Execution note
No push/commit should happen without explicit user permission.

# Dev B Full TODO (Execution Board)

Date: 2026-03-18
Owner: Dev B
Status: In progress

## A) Foundation
- [x] Create app folder structure for Dev B modules (`ui`, `core`, `state`, `models`, `scoring`)
- [x] Apply uniform theme system across app (single token source)
- [x] Wire app shell + route map for 9 visible steps
- [x] Add reusable widgets baseline (primary button, section card, status chip)
- [x] Add app-level loading and error patterns

## B) Entry Flow
- [x] Login screen with phone input + OTP hooks (mock-first)
- [x] Home screen with 4 fixed photo cards
- [x] Get Started popup with two actions
- [x] Input Guidelines screen

## C) Step Orchestration (9 visible)
- [x] Step state machine (`Not Started`, `In Progress`, `Verified`)
- [x] Progress indicator for 9 visible steps
- [x] Step navigation guards (cannot skip required progression)
- [x] Visible Step-9 stage mapped to EMI/loan behavior

## D) Step-1 Basic Profile
- [x] Build Step-1 form fields and UI
- [x] Individual validation rules (name, age, mobile, address, work type, has vehicle)
- [x] Cross-internal validation (address relationship)
- [x] Identity normalization before persistence
- [x] Save verified Step-1 profile to global state

## E) Step-2 Identity (KYC)
- [x] Identifier format validation before API calls
- [x] Aadhaar/PAN verification flow wiring (mock-first)
- [x] Upload unlock only after identifier verify success
- [x] OCR result validation + cross checks
- [x] Face verification integration hooks
- [x] Cross-step validation with Step-1

## F) Step-3 Bank Verification
- [x] IFSC + account verify flow (mock-first)
- [x] Bank statement upload flow
- [x] Bank parser module (SBI/HDFC/ICICI prototype support)
- [x] Unsupported bank layout fallback message
- [x] Statement period and identity consistency validation
- [x] Transaction extraction + typed transaction model

## G) Step-4 Utilities
- [x] Implement mandatory: Electricity, Gas/LPG, Mobile
- [x] Implement optional: Rent, WiFi/Broadband, OTT
- [x] EB rule: no strict Step-1 name match
- [x] Gas rule: allow cash/offline without hard rejection
- [x] Utility-level individual + cross-internal + global validation

## H) Step-5 Work Proof (Dynamic)
- [x] Dynamic UI by work type
- [x] Optional-input behavior (validate only if user provides)
- [x] Vehicle-number-centric validation for platform worker
- [x] Cross-step consistency updates

## I) Step-6 Government Schemes
- [x] Optional scheme modules UI
- [x] Per-scheme OCR + verification hooks
- [x] Global scheme state update

## J) Step-7 Insurance
- [x] Health/Life optional flow
- [x] Vehicle insurance conditional required if `has_vehicle == true`
- [x] OCR + verification hooks + consistency checks

## K) Step-8 ITR/GST
- [x] Optional upload flow
- [x] OCR field validation
- [x] PAN/name cross-step consistency
- [x] Income consistency tolerance check (±40%)

## L) Step-9 EMI/Loan Behavior (Visible Stage)
- [x] Derive EMI candidates from Step-3 transactions
- [x] Recurring interval validation (monthly pattern)
- [x] Optional loan verification API hook
- [x] Compute debt-to-income and risk band inputs
- [x] Persist EMI obligation profile in global state

## M) On-Device Scoring Pipeline
- [x] Build 95-feature engineering scaffold
- [x] Feature sanitization (NaN/Inf fallback and clamping)
- [ ] Integrate scorer files from Dev A handoff (blocked: waiting for Dev A artifact drop)
- [ ] Run scorecards (P5/P7/P8) (blocked: awaiting finalized Dev A scorer definitions)
- [ ] Apply confidence handling (blocked: depends on Dev A scorer output/confidence metadata)
- [ ] Final LR score computation (300-900) (blocked: requires Dev A LR coefficients handoff)

## N) Explainability + Report
- [x] SHAP lookup constants loader
- [x] Top positive/negative driver extraction
- [x] Language selection (report-only scope)
- [x] Report loading state and final report screen
- [x] PDF generation + share/export

## O) Persistence + Offline
- [x] Secure local persistence
- [x] Session recovery with expiry handling
- [x] Pending verification queue for offline mode
- [x] Retry and reconciliation when online returns

## P) Testing and Quality Gates
- [x] Unit tests for Step-1 validators and normalization
- [x] Unit tests for feature vector constraints
- [x] Unit tests for score formula and bounds
- [x] Integration test for 9-step progression
- [x] Integration test for Step-3 to Step-9 linkage
- [x] Golden feature-vector test
- [x] Golden score test
- [x] SHAP lookup rendering test
- [x] Theme uniformity visual check across key screens

## Q) Final Implementation Rules
- [x] Follow frozen docs when conflicts exist
- [x] Implement one module at a time and verify before moving on
- [x] No push/commit without explicit user permission

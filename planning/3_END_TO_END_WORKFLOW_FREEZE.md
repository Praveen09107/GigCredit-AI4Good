# GigCredit — End-to-End Workflow (FROZEN)

This document is the single, contradiction-free execution workflow for GigCredit.

It resolves the “8 vs 9 steps” confusion by defining:
- **8 user-facing onboarding steps**
- **1 automated internal step**: EMI auto-analysis (runs after Step-3 bank parsing)

## 0) High-level architecture
Environments:
- **Mobile app (Flutter/Dart)**: UI, OCR, validation, feature engineering, scoring, explainability, PDF generation, local persistence.
- **Backend (FastAPI + MongoDB)**: simulated verification APIs + Gemini report generation + optional score report storage.

Core rule:
- **Only verified/validated structured fields** contribute to scoring.

## 1) States and persistence (session recovery)
Step state machine:
- `NOT_STARTED → IN_PROGRESS → OCR_COMPLETE → PENDING_VERIFICATION → VERIFIED | REJECTED`

Persistence:
- After each step reaches **VERIFIED**, persist:
  - `verified_profile.enc` (encrypted)
  - `step_progress.json` (non-sensitive)
  - any derived structured files needed for subsequent steps (e.g., `bank_transactions.csv` encrypted)

Session expiry:
- Session data expires after **24 hours** (delete and restart Step-1).

## 2) Offline behavior
Offline tiers:
- **Tier 1 (offline safe)**: OCR, local validation, feature engineering, scoring, PDF generation.
- **Tier 2 (requires API)**: Aadhaar/PAN verification, bank account penny-drop simulation, RC/insurance/eShram/ITR verification, etc.

If offline during Tier-2:
- Allow document capture + OCR extraction.
- Mark step `PENDING_VERIFICATION`.
- Allow **provisional scoring** only if the **minimum scoring gate** is satisfied (see Section 7).
- Auto-retry pending verifications when connectivity returns.

## 3) App launch (Step-0 internal)
On app launch:
- Run security checks (root/debugger/hook/integrity).
- Initialize Keystore key material.
- Prepare scoring runtime (load scoring constants; m2cgen scorers are compiled Dart code, no model loading required).

If security checks fail:
- Block sensitive execution (scoring and verification) and show an error.

## 4) Step-1 (User) — Basic Profile
User enters:
- name, age, mobile, address(es), work type, vehicle ownership, etc.

On-device validation:
- format checks, normalization (uppercase/trim for identity matching).

Output:
- initialize `verified_profile.identity` + work configuration used to branch Step-5.

## 5) Step-2 (User) — Identity Verification (Aadhaar + PAN + Selfie)
Flow:
- User enters Aadhaar + PAN numbers → format validate → backend verify (if online).
- Enable document upload only after number verification succeeds.
- Run document pipeline per upload:
  - AI fraud detection (EfficientNet-Lite0)
  - preprocessing
  - OCR (PaddleOCR)
  - field extraction
  - cross-validation: OCR vs API response
  - face verification (MobileFaceNet)

Face verification outcomes:
- `>= 0.75`: pass
- `0.60–0.75`: auto-retry (max 2). If still unclear: accept with reduced confidence.
- `< 0.60`: reject Step-2

Output:
- `verified_profile.identity` verified fields (only verified values stored)

## 6) Step-3 (User) — Bank Account + Bank Statement
Flow:
- User verifies IFSC and bank account via backend (if online).
- Upload bank statement PDF/image:
  - Handle password-protected PDFs (prompt user; max 3 attempts)
  - If digital PDF: text extraction
  - If scanned PDF: PDF → images → OCR
  - Parse transactions → build `bank_transactions.csv`
  - Validate statement period: ≥ 6 months and ends within 30 days
  - Validate identity consistency (account holder name vs Step-1/2)

Output:
- `bank_transactions.csv` (encrypted at rest)
- `verified_profile.bank` fields

### Step-9 (Internal, automated) — EMI auto-analysis
Immediately after `bank_transactions.csv` is generated:
- Detect recurring EMI patterns
- Compute EMI burden and debt-to-income signals
- Update `verified_profile.emi_obligations`

This step is NOT shown in the progress bar.

## 7) Minimum scoring gate + provisional scoring
Minimum gate (must have all):
- Step-1 verified
- Step-2 verified
- Step-3 verified with ≥ 30 transactions

If gate passes:
- Compute provisional score after Step-3 and update after each later step completion.

If gate fails:
- Do not show a numeric score; show “Insufficient data… complete Steps 1–3.”

## 8) Step-4 (User) — Utility Bills
User uploads 6 months of:
- electricity, LPG/gas, mobile (mandatory)
- optional: WiFi/OTT
- rent module is allowed per spec (agreement/receipts)

Validation:
- OCR extraction, internal consistency across months, bank matching (where applicable)
- LPG cash handling: do not penalize; cash bills excluded from bank-match denominator

Output:
- `verified_profile.utilities`

## 9) Step-5 (User) — Work Proof (dynamic by work type)
Branch by `work_type`:
- platform worker: RC + vehicle insurance + platform screenshots; do not require owner-name match (vehicle may be family-owned).
- vendor: SVANidhi / FSSAI / no-due certificates
- tradesperson: Skill certificate / trade license
- freelancer: Upwork/Fiverr profile + transaction history

Output:
- `verified_profile.work`

## 10) Step-6 (User) — Government Schemes (optional)
eShram, PM-SYM, PMJJBY, PMMY, PPF etc.
Output:
- `verified_profile.gov_schemes`

## 11) Step-7 (User) — Insurance (optional; vehicle insurance conditional)
Vehicle insurance required only if vehicle ownership indicated; health/life optional.
Output:
- `verified_profile.insurance`

## 12) Step-8 (User) — Tax / ITR (optional)
ITR verification (and optional Udyam/GST where provided).
Output:
- `verified_profile.tax`

## 13) Final scoring + report
After onboarding completion or at any time after minimum gate:
- Feature engineering → `feature_vector[95]`
- Pillar scoring:
  - ML pillars via scoring models
  - Scorecard pillars via deterministic rules
- Confidence adjustments + sanitization
- Final score via LR meta-learner
- Explainability: binned SHAP lookup + top factors

Report generation:
- Call backend `/report/generate` with: score, pillars, factors, language
- Backend returns multilingual explanation + suggestions (LLM must not change score)

## 14) PDF generation + sharing
- Generate PDF on-device (Dart `pdf` package).
- Allow share/download via system share sheet.

## 15) Cleanup
After report generation:
- Delete raw document images, OCR temp files, intermediate vectors, `bank_transactions.csv` if not needed for history.
- Keep:
  - score history records
  - minimal encrypted session data (until expiry)


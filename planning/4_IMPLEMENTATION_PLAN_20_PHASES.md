<!-- markdownlint-disable -->

# GigCredit — 20-Phase Implementation Execution Plan (Implementation-Ready)

**Timeline**: 48 hours (2 days)  
**Team**: 2 developers working in parallel  
**Scoring**: XGBoost/RF + m2cgen pure-Dart  
**OCR**: Native PaddleOCR

This document is designed so **an AI coding agent can implement directly**.
It includes goals, tasks, file paths, function names, pseudocode, and acceptance checks.

Authoritative frozen references in this repo:

- `planning/3_END_TO_END_WORKFLOW_FREEZE.md`
- `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`
- `planning/2_BACKEND_HARDENING_SPEC.md`
- `specification files/Input_fields_final (1).txt`
- `specification files/COMPREHENSIVE FIXES AND ADDITIONS — ALL IDENTIFIED ISSUES AND RESOLUTIONS.txt`

---

## Global rules (apply to all phases)
- **No merge conflicts**: follow directory ownership in `planning/2_GIGCREDIT_TEAM_WORK_SPLIT.md`.
- **No scoring on backend**: backend = verification + LLM only.
- **Verified-only rule**: only verified structured fields enter scoring.
- **Dynamic score**:
  - provisional score recomputed after each step completion (after Step-3 gate)
  - score history + 30-day cooldown
- **MVP scope**: simulation DBs, Render deployment, no OTA model updates.

---

## Phase 0 — Repo & toolchain bootstrap (Hour 0–1)
**Goal**: create 3 codebases and lock tool versions so both agents run reproducibly.

### Tasks
- **Mobile**: create Flutter app `gigcredit_app/`
- **Backend**: create FastAPI `backend/`
- **Offline ML**: create `offline_ml/`
- **Planning artifacts**: keep this `planning/` folder as source of truth.

### Acceptance
- `flutter doctor` ok
- backend starts locally
- offline_ml imports work

---

## Phase 1 — Shared contracts & schemas (Hour 0–2, parallel unblocker)
**Goal**: define the *interfaces* that prevent cross-team blocking.

### Mobile: data models + enums
**Files**
- `gigcredit_app/lib/models/document_type.dart`
- `gigcredit_app/lib/models/step_status.dart`
- `gigcredit_app/lib/models/verified_profile.dart`

**Key enums (must exist)**
- `DocumentType` (AADHAAR_FRONT, AADHAAR_BACK, PAN, BANK_STATEMENT, EB_BILL, LPG_BILL, MOBILE_BILL, WIFI_BILL, RC, INSURANCE, ITR, ... )
- `StepId` (STEP1_PROFILE ... STEP8_TAX)
- `StepStatus` (NOT_STARTED, IN_PROGRESS, OCR_COMPLETE, PENDING_VERIFICATION, VERIFIED, REJECTED)

**VerifiedProfile structure (minimum)**
```pseudo
class VerifiedProfile {
  identity: { name, dob, aadhaar_last4, pan, face_match_score, ... }
  bank: { ifsc, account_holder, account_number_masked, statement_period, ... }
  utilities: { electricity: [...], lpg: [...], mobile: [...], wifi?: [...], rent?: ... }
  work: { work_type, platform?: {...}, vendor?: {...}, trades?: {...}, freelancer?: {...} }
  schemes: { eshram?: {...}, pmsym?: {...}, ppf?: {...}, ... }
  insurance: { health?: {...}, vehicle?: {...}, life?: {...} }
  tax: { itr?: {...}, gst?: {...}, udyam?: {...} }
  emi_obligations: { active_emi_count, total_monthly_emi, debt_to_income_ratio, ... }
  verification_state: map<StepId, StepStatus>
}
```

### Backend: request/response envelopes
**File**
- `backend/schemas.py`

**Standard response**
```pseudo
class ApiResponse:
  status: "FOUND" | "NOT_FOUND" | "INVALID" | "ERROR"
  data: dict | null
  error: str | null
```

### Acceptance
- Mobile models compile
- Backend can return `ApiResponse` from a dummy endpoint

---

## Phase 2 — Backend skeleton + auth + deploy (Hour 1–6)
**Goal**: running Render backend early so mobile can integrate quickly.

### Files
- `backend/main.py`
- `backend/database.py`
- `backend/auth.py`
- `backend/routers/verify.py`
- `backend/routers/report.py`
- `backend/seed_db.py`

### Auth (API key + HMAC)
**Pseudocode**
```pseudo
middleware(request):
  apiKey = header["X-API-Key"]
  deviceId = header["X-Device-ID"]
  ts = header["X-Timestamp"]
  sig = header["X-Signature"]

  if apiKey != ENV.API_KEY: 401
  if abs(now_ms - ts) > 5min: 401

  bodyHash = sha256(rawBodyBytes)
  expected = hmac_sha256(apiKey, deviceId + ts + bodyHash)
  if !constant_time_equal(sig, expected): 401

  rate_limit(deviceId, endpoint)
```

### Acceptance
- `/docs` works locally and on Render
- Invalid signature rejected
- 9 verify endpoints return FOUND/NOT_FOUND correctly (seed data)

---

## Phase 3 — Backend verification endpoints (Hour 2–10)
**Goal**: cover the simulation APIs needed by Steps 2–8.

### Endpoints (minimum set)
- `POST /gov/pan/verify`
- `POST /gov/aadhaar/verify`
- `POST /bank/ifsc/verify`
- `POST /bank/account/verify`
- `POST /gov/vehicle/rc/verify`
- `POST /gov/insurance/verify`
- `POST /gov/income-tax/itr/verify`
- `POST /gov/eshram/verify`
- `POST /bank/loan/check`

### Acceptance
- each endpoint < 200ms on Render (sim DB)
- correct NOT_FOUND behavior

---

## Phase 4 — Backend LLM report generation (Hour 6–12)
**Goal**: deterministic JSON report from Gemini; never changes score.

### Endpoint
- `POST /report/generate`

### Prompt rules (must enforce)
- output language = requested
- output JSON only:
  - `{ "explanation": "...", "suggestions": ["..."] }`
- do not modify score/pillars

### Acceptance
- always returns parseable JSON (fallback on parse failure)

---

## Phase 5 — Mobile app skeleton (routing/state) (Hour 0–6)
**Goal**: running app shell with step wizard and persisted state.

### Files
- `gigcredit_app/lib/main.dart`
- `gigcredit_app/lib/app_router.dart`
- `gigcredit_app/lib/state/verified_profile_provider.dart`
- `gigcredit_app/lib/state/step_flow_controller.dart`

### Step flow controller pseudocode
```pseudo
onStepComplete(stepId, newVerifiedFields):
  merge into VerifiedProfile (verified-only)
  set step status VERIFIED
  persist session snapshot
  if stepId >= Step3 and minGatePasses: recompute provisional score
```

### Acceptance
- navigate across 8 steps
- resume after kill/relaunch at last step

---

## Phase 6 — Mobile secure persistence + session recovery (Hour 4–10)
**Goal**: encrypted `verified_profile` + resume with expiry.

### Files
- `gigcredit_app/lib/core/secure_storage.dart`
- `gigcredit_app/lib/core/session_manager.dart`

### Pseudocode
```pseudo
saveSession(profile, stepProgress):
  bytes = json(profile)
  enc = aes_gcm_encrypt(keyFromKeystore, bytes)
  write file verified_profile.enc
  write step_progress.json (no secrets)

loadSession():
  if expired: delete and return null
  dec = aes_gcm_decrypt(key, read verified_profile.enc)
  return profile
```

### Acceptance
- crash recovery works
- expiry deletes session

---

## Phase 7 — Native PaddleOCR integration (Hour 6–18)
**Goal**: real on-device OCR for images + scanned PDFs.

### Files
- `gigcredit_app/lib/ai/ocr_engine.dart`
- `gigcredit_app/android/` native bridge (Kotlin) + Paddle OCR assets

### Interface (must remain stable)
```pseudo
class OCREngine:
  initialize()
  extractText(imageBytes) -> String
  extractFields(rawText, DocumentType) -> Map<String,String>
```

### Acceptance
- OCR returns text for PAN/Aadhaar sample

---

## Phase 8 — Fraud detection (EfficientNet-Lite0) (Hour 6–14)
**Goal**: reject AI-generated/edited documents.

### Files
- `gigcredit_app/lib/ai/authenticity_detector.dart`

### Acceptance
- returns REAL vs AI/EDITED for test images

---

## Phase 9 — Face verification (MobileFaceNet) (Hour 6–14)
**Goal**: selfie ↔ Aadhaar/PAN photo match with retry rules.

### Files
- `gigcredit_app/lib/ai/face_verifier.dart`

### Acceptance
- PASS/RETRY/REJECT thresholds enforced

---

## Phase 10 — Document pipeline orchestrator (Hour 10–18)
**Goal**: single orchestrator used by every step for upload → fraud → OCR → parse.

### Files
- `gigcredit_app/lib/ai/document_processor.dart`
- `gigcredit_app/lib/ai/field_extractors.dart`

### Pseudocode
```pseudo
process(doc):
  pages = pdf_to_images_if_needed(doc)
  for page in pages:
    if authenticity != REAL: reject
    raw = ocr.extractText(page)
  mergedRaw = concat(raw)
  fields = ocr.extractFields(mergedRaw, docType)
  return { rawText: mergedRaw, fields }
```

### Acceptance
- works for PAN + bank statement

---

## Phase 11 — Step-2 KYC (Hour 10–20)
**Goal**: Aadhaar+PAN verification, OCR cross-check, face match.

### Files
- `gigcredit_app/lib/steps/step2_kyc_service.dart`
- `gigcredit_app/lib/services/backend_client.dart`

### Acceptance
- cannot proceed unless verified

---

## Phase 12 — Step-3 Bank parsing + EMI auto-analysis (Hour 14–26)
**Goal**: parse bank statements into structured CSV + detect EMIs.

### Files
- `gigcredit_app/lib/core/bank_parser.dart`
- `gigcredit_app/lib/core/emi_detector.dart`
- `gigcredit_app/lib/core/transaction_tagger.dart`

### Acceptance
- produces `bank_transactions.csv`
- EMI auto-analysis updates profile

---

## Phase 13 — Feature engineering (95 features) (Hour 18–32)
**Goal**: deterministic vector `[95]` aligned to spec.

### Files
- `gigcredit_app/lib/scoring/feature_engineer.dart`
- `gigcredit_app/lib/scoring/feature_sanitizer.dart`

### Acceptance
- exact length 95
- no NaN/Inf

---

## Phase 14 — Offline ML training (XGBoost/RF) (Hour 0–12)
**Goal**: produce m2cgen scorers + SHAP lookup + meta coefficients.

### Files
- `offline_ml/data_generator.py`
- `offline_ml/tune_models.py`
- `offline_ml/train_final.py`
- `offline_ml/extract_shap.py`
- `offline_ml/train_meta_learner.py`
- `offline_ml/export_to_dart.py`
- `offline_ml/validate_export.py`

### m2cgen rules (MANDATORY)
- `tree_method='exact'`
- `max_depth<=4`, `n_estimators<=150`
- `sys.setrecursionlimit(50000)`

### Acceptance
- python vs dart max diff < 1e-5

---

## Phase 15 — On-device pillar scoring + meta-learner (Hour 20–34)
**Goal**: compute pillars + LR final score (only method).

### Files
- `gigcredit_app/lib/scoring/p1_scorer.dart` ... `p6_scorer.dart` (generated)
- `gigcredit_app/lib/scoring/meta_learner.dart`
- `gigcredit_app/lib/scoring/score_engine.dart`

### Score engine pseudocode
```pseudo
features = engineer(profile)
features = sanitize(features)
p1 = score_p1(features[0:13])
...
p6 = score_p6(features[67:78])
p5/p7/p8 = scorecards(...)
final = lr_meta_learner(pillars, work_type)
return ScoreReport(...)
```

### Acceptance
- scoring < 200ms

---

## Phase 16 — Explainability (binned TreeSHAP lookup) (Hour 22–36)
**Goal**: top +/- factors per user.

### Files
- `gigcredit_app/lib/scoring/shap_engine.dart`

### Acceptance
- returns top 3 positive + top 3 negative factors

---

## Phase 17 — Report UI + dynamic score (Hour 10–36)
**Goal**: polished step UX + provisional score updates + final report.

### Files
- `gigcredit_app/lib/ui/...`

### Acceptance
- progress bar = 8 steps
- provisional score appears after Step-3

---

## Phase 18 — PDF generation + sharing (Hour 30–42)
**Goal**: on-device PDF matches spec.

### Files
- `gigcredit_app/lib/report/pdf_report_generator.dart`

### Acceptance
- PDF opens and shares

---

## Phase 19 — Cleanup + telemetry (Hour 34–46)
**Goal**: delete sensitive temps; structured logging.

### Acceptance
- no raw images left after completion

---

## Phase 20 — Golden tests + regression gate (Hour 36–48)
**Goal**: stability and demo confidence.

### Tests
- golden feature vector
- golden score output
- mocked backend flows

### Acceptance
- tests pass consistently


# ================================================================================
# GIGCREDIT — 2-DEVELOPER TEAM WORK SPLIT (FINAL)
# Timeline: 48 Hours  |  Strategy: Zero-Blocker Parallel Execution
# ================================================================================

---

## CORE PRINCIPLE: NO MERGE CONFLICTS

The codebase is split by DIRECTORY OWNERSHIP. Each developer owns specific
folders and the other developer NEVER edits files in those folders.

```
DEVELOPER A owns:
  offline_ml/                    (entire folder)
  backend/                       (entire folder)
  gigcredit_app/lib/ai/          (AI models, OCR, face verification)
  gigcredit_app/lib/services/    (API client to reach backend)

DEVELOPER B owns:
  gigcredit_app/lib/ui/          (all screens and widgets)
  gigcredit_app/lib/core/        (feature engineering, bank parser, confidence)
  gigcredit_app/lib/scoring/     (scoring engine, meta-learner, SHAP, scorecards)
  gigcredit_app/lib/models/      (data models, state classes)
  gigcredit_app/lib/main.dart    (app entry, routing)
  gigcredit_app/test/            (tests)
```

**RULE:** If Developer B needs an AI function (e.g., OCR), they call it
through a clean interface that Developer A defines EARLY. Developer A
publishes the interface stub on Hour 2 so Developer B is never blocked.

**EXECUTION PLAN REFERENCE:** For the most detailed phase-by-phase runbook, use:
- `planning/1_GIGCREDIT_FULL_IMPLEMENTATION_PLAN.md`

---

## DEVELOPER A — BACKEND, ML & NATIVE AI ENGINEER

### HOUR 0–1: Setup (Phase 0)
| Task | Details |
|------|---------|
| 0.2 | Create `backend/` folder. Install FastAPI, motor, google-generativeai. Create `.env`. |
| 0.3 | Create `offline_ml/` folder. Install xgboost, scikit-learn, optuna, shap, m2cgen, numpy, pandas. |
| 0.1 (partial) | Create Flutter project skeleton. Add AI-related dependencies to `pubspec.yaml`. |

### HOUR 1–8: Offline ML Pipeline (Phase 1)
| Task | Details |
|------|---------|
| 1.1 | Write `offline_ml/data_generator.py`. Generate 15,000 synthetic profiles. |
| 1.2 | Write `offline_ml/tune_models.py`. Run Optuna tuning (100 trials × 5 models). |
| 1.3 | Write `offline_ml/train_final.py`. Train final models, save `.pkl` files. |
| 1.4 | Write `offline_ml/extract_shap.py`. Compute binned SHAP lookup tables. |
| 1.5 | Write `offline_ml/train_meta_learner.py`. Train LR meta-learner, export coefficients. |
| 1.6 | Write `offline_ml/export_to_dart.py`. Convert models to `.dart` via m2cgen. |
| 1.7 | Write `offline_ml/validate_export.py`. Validate Python vs Dart outputs. |
| **1.8** | **HANDOFF POINT →** Copy `p1_scorer.dart` through `p6_scorer.dart`, plus `shap_lookup.json` and `meta_coefficients.json` to the Flutter project. **After this, tell Developer B: "Scoring files are ready."** |

**HANDOFF CHECKLIST (Dev A → Dev B)**
- `gigcredit_app/lib/scoring/p1_scorer.dart` … `p6_scorer.dart` exist and compile
- `gigcredit_app/assets/constants/shap_lookup.json` exists
- `gigcredit_app/assets/constants/meta_coefficients.json` exists
- `gigcredit_app/assets/constants/state_income_anchors.json` exists
- `gigcredit_app/assets/constants/feature_means.json` exists
- `gigcredit_app/lib/services/api_client_interface.dart` published (Hour 2)
- `gigcredit_app/lib/services/mock_api_client.dart` published (Hour 2)
- `gigcredit_app/lib/ai/ai_interfaces.dart` published (Hour 2)
- `gigcredit_app/lib/ai/mock_document_processor.dart` published (Hour 2)
- `offline_ml/validate_export.py` passed with `max_diff < 1e-5`

### HOUR 1–10: Backend Server (Phase 2) — IN PARALLEL WITH ML
| Task | Details |
|------|---------|
| 2.1 | Write `backend/database.py`. MongoDB connection via motor. |
| 2.2 | Write `backend/models.py`. All Pydantic schemas. |
| 2.3 | Write `backend/seed_db.py`. Insert 10 fake records per collection. |
| 2.4 | Write `backend/auth.py`. API key validation middleware. |
| 2.5 | Write `backend/routers/verify.py`. All 9 verification endpoints. |
| 2.6 | Write `backend/routers/report.py`. Gemini LLM report generation endpoint. |
| 2.7 | Score report storage endpoint. |
| **2.8** | **Deploy backend to Render.** Share the URL with Developer B. **HANDOFF POINT →** Tell Developer B: "Backend is live at https://xxx.onrender.com". |

### HOUR 8–20: On-Device AI Integration (Phase 4)
| Task | Details |
|------|---------|
| 4.1 | Write `lib/ai/authenticity_detector.dart`. Load EfficientNet-Lite0.tflite. Implement `detectAuthenticity()`. |
| 4.2 | Write `lib/ai/face_verifier.dart`. Load MobileFaceNet.tflite. Implement `verifyFace()`. |
| 4.3 | Write `lib/ai/ocr_engine.dart`. Integrate PaddleOCR Lite natively. Implement `extractText()`. |
| 4.4 | Write `lib/ai/document_processor.dart`. Orchestrate: authenticity → OCR → field extraction. |
| **EARLY** | **CRITICAL HANDOFF →** On Hour 2, publish clean abstract class stubs so Developer B can code against them immediately: |

```dart
// File: lib/ai/ai_interfaces.dart (publish this EARLY on Hour 2)
abstract class IAuthenticityDetector {
  Future<AuthResult> detectAuthenticity(Uint8List imageBytes);
}

abstract class IFaceVerifier {
  Future<FaceMatchResult> verifyFace(Uint8List aadhaarPhoto, Uint8List selfie);
}

abstract class IOCREngine {
  Future<String> extractText(Uint8List imageBytes);
  Future<Map<String, String>> extractFields(String rawText, DocumentType type);
}

abstract class IDocumentProcessor {
  Future<ProcessedDocument> processDocument(Uint8List imageBytes, DocumentType type);
}
```

Developer B imports these interfaces and codes against them. Developer A
later provides the real implementations. Until then, Developer B uses
mock implementations that return hardcoded sample data.

**Also published at Hour 2 (see Task 0.4 in implementation plan):**
- `lib/services/api_client_interface.dart` — `IApiClient` with all 11 endpoint methods
- `lib/services/mock_api_client.dart` — Returns `{"status": "ACTIVE", ...}` for all endpoints

### HOUR 36–48: Integration & Testing (Phase 7)
| Task | Details |
|------|---------|
| 7.2 | Run full end-to-end test on emulator with Developer B. |
| 7.4 | Implement secure cleanup logic in `lib/ai/` files. |

---

## DEVELOPER B — FRONTEND, FEATURE LOGIC & SCORING ENGINEER

### HOUR 0–1: Setup (Phase 0)
| Task | Details |
|------|---------|
| 0.1 (partial) | Add UI/state dependencies to `pubspec.yaml` (riverpod, go_router, etc.). |

### HOUR 1–12: Flutter App Shell & 8-Step Wizard (Phase 3)
| Task | Details |
|------|---------|
| 3.1 | Write `lib/main.dart`. Firebase init, Riverpod, GoRouter with all routes. |
| 3.2 | Write `lib/ui/screens/login_screen.dart`. Phone OTP auth via Firebase. |
| 3.3 | Write `lib/ui/screens/home_screen.dart`. Hero section, 4 feature cards, Get Started button. |
| 3.4 | Write `lib/core/providers/verified_profile_provider.dart`. Global state with all fields. |
| 3.5 | Write `lib/ui/screens/steps/step1_profile.dart`. 12 inputs including work type selector. |
| 3.6 | Write `lib/ui/screens/steps/step2_identity.dart`. Aadhaar, PAN, selfie uploads. Uses AI interfaces (mock initially). |
| 3.7 | Write `lib/ui/screens/steps/step3_bank.dart`. Bank details + PDF upload. |
| 3.8 | Write `lib/ui/screens/steps/step4_utilities.dart`. 18 mandatory bill uploads. |
| 3.9 | Write `lib/ui/screens/steps/step5_work_proof.dart`. 4 dynamic layouts based on workType. |
| 3.10 | Write `lib/ui/screens/steps/step6_schemes.dart`. 5 expandable scheme cards. |
| 3.11 | Write `lib/ui/screens/steps/step7_insurance.dart`. 3 insurance cards with dynamic mandatory logic. |
| 3.12 | Write `lib/ui/screens/steps/step8_itr_gst.dart`. ITR + GST optional uploads. |

### HOUR 12–24: Feature Engineering & Bank Parsing (Phase 5)
| Task | Details |
|------|---------|
| 5.1 | Write `lib/core/bank_parser.dart`. PDF → structured BankTransaction list. |
| 5.2 | Write `lib/core/transaction_tagger.dart`. 4-layer tagging engine with Indian bank keywords. |
| 5.3 | Write `lib/core/feature_engineering.dart`. THE BIG ONE — compute all 95 features with exact index mapping. |
| 5.4 | Write `lib/core/confidence_engine.dart`. 8 confidence values based on data completeness. |

### HOUR 24–36: Scoring Engine & Report (Phase 6)
*Note: Developer B can start this AFTER Developer A delivers the m2cgen `.dart` scorer files + JSON constants (Handoff 1.8).*
| Task | Details |
|------|---------|
| 6.1 | Write `lib/scoring/scoring_engine.dart`. The 18-step orchestrator. |
| 6.2 | Write `lib/scoring/meta_learner.dart`. LR dot product + sigmoid. |
| 6.3 | Write `lib/scoring/shap_engine.dart`. Binned SHAP lookup. |
| Write | `lib/scoring/scorecard_p5.dart`, `scorecard_p7.dart`, `scorecard_p8.dart`. Weighted sum scorecards. |
| Write | `lib/scoring/feature_sanitizer.dart`, `lib/scoring/pillar_validator.dart`. Guards. |
| 6.4 | Write `lib/ui/screens/language_select_screen.dart`. |
| 6.5 | Write `lib/ui/screens/report_loading_screen.dart`. Call backend `/report/generate`. |
| 6.6 | Write `lib/ui/screens/final_report_screen.dart`. Score gauge, 8 pillar bars, LLM text. |
| 6.7 | Write `lib/core/pdf_generator.dart`. 3-page PDF with `pdf` package. |
| 6.8 | POST score report to backend for storage. |

### HOUR 36–48: Testing & Polish (Phase 7)
| Task | Details |
|------|---------|
| 7.1 | Write `test/golden_profile_test.dart`. Assert deterministic score output. |
| 7.3 | Implement session recovery via FlutterSecureStorage. |
| 7.5 | UI polish: animations, gradients, consistent styling. |

---

## HANDOFF TIMELINE SUMMARY

```
Hour  0 ─── Both start setup (Phase 0)
Hour  2 ─── Dev A publishes AI interface stubs → Dev B can code against them
Hour  8 ─── Dev A finishes ML pipeline, hands over m2cgen `.dart` scorers + constants → Dev B can start scoring engine
Hour 10 ─── Dev A finishes backend, deploys to Render → Dev B can make API calls
Hour 12 ─── Dev B finishes 8-step wizard UI
Hour 20 ─── Dev A finishes all Flutter AI integrations (OCR, FaceNet, EfficientNet)
Hour 24 ─── Dev B finishes Feature Engineering → can start scoring
Hour 36 ─── Both start integration testing together
Hour 48 ─── Ship!
```

---

## WHAT IF TIMELINE IS TIGHT?

**Priority cut order (cut from bottom first):**
1. ❌ Cut Task 7.5 UI polish (keep functional but basic)
2. ❌ Cut Task 6.7 PDF generation (show report on screen only)
3. ❌ Cut Task 3.10/3.11/3.12 (Steps 6-8 — make them placeholder screens)
4. ❌ Cut Task 4.1 EfficientNet fraud detection (accept all documents)
5. ⚠️ NEVER cut: Tasks 1.1-1.8 (ML pipeline), Tasks 5.3 (Feature Engineering), Tasks 6.1-6.2 (Scoring Engine)

The scoring engine + feature engineering is the CORE IP. Everything else is supporting infrastructure.

# ================================================================================
# GIGCREDIT — PROJECT CONTEXT FOR AI AGENTS
# ================================================================================
# PURPOSE: This file gives ANY AI coding agent full context about the GigCredit
# project so it can implement tasks from the implementation plan without needing
# access to the original 20 specification files or the chat conversation history.
# ================================================================================

---

## WHAT IS GIGCREDIT?
GigCredit is a **privacy-first mobile application** (Flutter/Dart) that generates
an alternative credit score (300-900, matching CIBIL scale) for India's 15M+
gig economy workers who lack traditional credit histories.

## CORE ARCHITECTURE RULE
**ALL credit scoring computation happens ON THE USER'S DEVICE.**
The backend server is used ONLY for:
1. Government document verification (simulated via MongoDB lookups)
2. LLM report generation (Gemini API for multilingual explanations)
3. Storing the final score report

The backend NEVER receives raw financial data, documents, or OCR text.

## TECHNOLOGY STACK
| Layer | Technology |
|-------|-----------|
| Mobile App | Flutter 3.x / Dart |
| State Management | Riverpod |
| Navigation | GoRouter |
| Auth | Firebase Phone OTP |
| On-Device OCR | PaddleOCR Lite (native) |
| Face Verification | MobileFaceNet (TFLite) |
| Fraud Detection | EfficientNet-Lite0 (TFLite) |
| ML Scoring | m2cgen-generated pure Dart code (NO TFLite for scoring) |
| Backend | FastAPI (Python) |
| Database | MongoDB Atlas |
| LLM | Google Gemini API |
| PDF Generation | `pdf` Dart package (on-device) |

## THE 8 SCORING PILLARS
Note: pillar weights are **reference feature-importance priors** only. Final score is produced by LR meta-learner, not weighted-sum aggregation.

| Pillar | Type | Algorithm | Features | Weight |
|--------|------|-----------|----------|--------|
| P1 Income Stability | ML | XGBoost (m2cgen Dart) | 13 | 0.25 |
| P2 Payment Discipline | ML | XGBoost (m2cgen Dart) | 15 | 0.20 |
| P3 Debt Management | ML | XGBoost (m2cgen Dart) | 9 | 0.15 |
| P4 Savings Behaviour | ML | XGBoost (m2cgen Dart) | 12 | 0.15 |
| P5 Work & Identity | Scorecard | Dart weighted sum | 18 | 0.10 |
| P6 Financial Resilience | ML | RandomForest (m2cgen Dart) | 11 | 0.07 |
| P7 Social Accountability | Scorecard | Dart weighted sum | 10 | 0.05 |
| P8 Tax Compliance | Scorecard | Dart weighted sum | 7 | 0.03 |
| **Total** | | | **95** | **1.00** |

## HOW THE SCORE IS COMPUTED
1. User completes 8 verification steps (identity, bank, utilities, work proof, schemes, insurance, ITR, GST)
2. On-device feature engineering computes 95 normalized [0,1] features
3. Features are sanitized (NaN → 0.50, clamped to [0,1])
4. 5 ML models run as pure Dart arithmetic (m2cgen exported)
5. 3 scorecards compute via Dart weighted sums
6. Output validation (NaN/bounds check per pillar)
7. Debt Band Hard Cap: if EMI/income > 0.80, P3 capped at 0.30
8. Confidence Engine adjusts: `adjusted = raw × confidence + 0.50 × (1 - confidence)`
9. Meta-Learner (Logistic Regression, 44 inputs) produces probability
10. `final_score = round(probability × 600 + 300)` → range 300-900

## THE m2cgen APPROACH (CRITICAL TO UNDERSTAND)
Models are NOT loaded as `.tflite` files at runtime. Instead:
- Python trains XGBoost/RandomForest models
- `m2cgen` library converts them to pure Dart arithmetic code
- Each model becomes a single function: `double score_pN(List<double> input)`
- These `.dart` files are committed to the Flutter project source code
- They compile into ARM machine instructions — zero runtime dependencies
- Inference time: ~2-5ms per model

## THE 8 ONBOARDING STEPS
1. **Basic Profile** — Name, DOB, phone, address, work type (4 options), income, vehicle ownership
2. **Identity Verification** — Aadhaar (front+back), PAN card, live selfie, face match
3. **Bank Verification** — Bank details, 6+ month statement PDF, optional secondary bank + UPI
4. **Utility Bills** — recommended 6 months each: electricity, gas, mobile (strongly improves confidence; not a hard scoring block if minimum gate is already met)
5. **Gig Work Proof** — Dynamic based on work type (Platform/Vendor/Tradesperson/Freelancer)
6. **Government Schemes** — eShram, PM-SYM, PMJJBY, MUDRA, PPF (all optional)
7. **Insurance** — Health, Vehicle (mandatory if owns vehicle), Life
8. **ITR & GST** — ITR Form V, Form 26AS, GSTIN, GSTR-3B returns

## KEY DESIGN DECISIONS
- **Weighted sum DELETED:** Only the LR meta-learner computes the final score
- **No Isolates needed:** Sequential execution is fast enough (~15-20ms total)
- **SHAP via binned lookup:** Not real-time SHAP — precomputed 10-percentile bins
- **Session recovery:** Encrypted profile cached for 24 hours, resume on crash
- **Offline capability:** OCR, scoring, PDF all work offline. API verification queued.
- **PaddleOCR integration:** native Android bridge (plugin/MethodChannel/FFI path), not `tflite_flutter` model loading.

## DIRECTORY STRUCTURE (PRODUCTION-GRADE)
```
gigcredit_app/
├── lib/
│   ├── main.dart
│   ├── app/                               # App-wide configuration
│   │   ├── router.dart                    # GoRouter config + auth guard
│   │   ├── theme.dart                     # Colors, text styles, gradients
│   │   └── constants.dart                 # API URLs, feature indices, pillar weights
│   ├── models/                            # Pure data classes
│   │   ├── bank_transaction.dart
│   │   ├── verified_profile.dart
│   │   ├── score_report.dart
│   │   ├── processed_document.dart
│   │   └── enums.dart                     # WorkType, TransactionTag, AuthResult, etc.
│   ├── providers/                         # Riverpod state management
│   │   ├── verified_profile_provider.dart
│   │   ├── auth_provider.dart
│   │   └── score_provider.dart
│   ├── ai/                                # Dev A owns — all TFLite + OCR
│   │   ├── ai_interfaces.dart             # Abstract classes (published Hour 2)
│   │   ├── mock_document_processor.dart   # Dev B uses until real AI is ready
│   │   ├── authenticity_detector.dart     # EfficientNet-Lite0
│   │   ├── face_verifier.dart             # MobileFaceNet
│   │   ├── ocr_engine.dart                # PaddleOCR native
│   │   ├── field_extractors.dart          # Regex parsers per document type
│   │   └── document_processor.dart        # Orchestrator pipeline
│   ├── services/                          # Dev A owns — backend communication
│   │   ├── api_client_interface.dart      # IApiClient abstract (published Hour 2)
│   │   ├── mock_api_client.dart           # Hardcoded responses for dev
│   │   ├── api_client.dart                # Real implementation
│   │   └── secure_storage_service.dart    # Session persistence
│   ├── scoring/                           # Dev B owns — scoring pipeline
│   │   ├── p1_scorer.dart                 # m2cgen auto-generated (XGBoost P1)
│   │   ├── p2_scorer.dart                 # m2cgen auto-generated (XGBoost P2)
│   │   ├── p3_scorer.dart                 # m2cgen auto-generated (XGBoost P3)
│   │   ├── p4_scorer.dart                 # m2cgen auto-generated (XGBoost P4)
│   │   ├── p6_scorer.dart                 # m2cgen auto-generated (RandomForest P6)
│   │   ├── scorecard_p5.dart              # Hand-written Dart weighted sum
│   │   ├── scorecard_p7.dart              # Hand-written Dart weighted sum
│   │   ├── scorecard_p8.dart              # Hand-written Dart weighted sum
│   │   ├── meta_learner.dart              # LR dot product + sigmoid
│   │   ├── scoring_engine.dart            # 18-step orchestrator
│   │   ├── feature_sanitizer.dart         # NaN → 0.50, clamp [0,1]
│   │   ├── pillar_validator.dart          # Output validation per pillar
│   │   ├── shap_engine.dart               # Binned SHAP lookup
│   │   └── scoring_constants.dart         # Grade cutoffs, risk bands, weights
│   ├── core/                              # Dev B owns — business logic
│   │   ├── feature_engineering.dart       # Profile → 95 normalized features
│   │   ├── confidence_engine.dart         # 8 pillar confidence values
│   │   ├── bank_parser.dart               # PDF → structured transactions
│   │   ├── transaction_tagger.dart        # 4-layer keyword tagging
│   │   └── pdf_generator.dart             # On-device PDF report
│   └── ui/                                # Dev B owns — all screens
│       ├── screens/
│       │   ├── login_screen.dart
│       │   ├── home_screen.dart
│       │   ├── guidelines_screen.dart
│       │   ├── language_select_screen.dart
│       │   ├── report_loading_screen.dart
│       │   ├── final_report_screen.dart
│       │   └── steps/
│       │       ├── step1_profile.dart
│       │       ├── step2_identity.dart
│       │       ├── step3_bank.dart
│       │       ├── step4_utilities.dart
│       │       ├── step5_work_proof.dart
│       │       ├── step6_schemes.dart
│       │       ├── step7_insurance.dart
│       │       └── step8_itr_gst.dart
│       └── widgets/                       # Reusable components
│           ├── document_upload_card.dart   # Camera/gallery picker (used 30+ times)
│           ├── score_gauge.dart            # Circular score dial
│           ├── pillar_bar.dart             # Single pillar progress bar
│           ├── step_progress_bar.dart      # Top nav showing step 1-8
│           ├── work_type_selector.dart     # The 4-card grid selector
│           └── loading_overlay.dart        # Processing state overlay
├── assets/
│   ├── models/
│   │   ├── mobilefacenet.tflite
│   │   └── efficientnet_lite0.tflite
│   └── constants/
│       ├── shap_lookup.json               # Binned SHAP values (~8-12KB)
│       ├── meta_coefficients.json         # LR 44 coefficients + intercept
│       ├── state_income_anchors.json      # 36 state median incomes
│       └── feature_means.json             # 95-feature training means
├── test/
│   ├── golden_profile_test.dart
│   ├── feature_engineering_test.dart
│   └── scoring_engine_test.dart
└── pubspec.yaml

offline_ml/                                # Python — runs once before app dev
├── data_generator.py
├── tune_models.py
├── train_final.py
├── extract_shap.py
├── train_meta_learner.py
├── export_to_dart.py
├── validate_export.py
├── data/                                  # Generated artifacts
│   ├── synthetic_profiles.csv
│   ├── best_params.json
│   ├── training_report.json
│   ├── shap_lookup.json
│   ├── meta_coefficients.json
│   ├── state_income_anchors.json
│   └── feature_means.json
└── output/                                # m2cgen .dart files
    ├── p1_scorer.dart
    ├── p2_scorer.dart
    ├── p3_scorer.dart
    ├── p4_scorer.dart
    └── p6_scorer.dart

backend/                                   # Python FastAPI — deployed to Render
├── main.py
├── database.py
├── models.py
├── auth.py
├── seed_db.py
├── requirements.txt
├── .env
├── Procfile
└── routers/
    ├── verify.py
    └── report.py

planning/                                  # This folder — planning documents
├── 0_PROJECT_CONTEXT.md
├── 1_GIGCREDIT_FULL_IMPLEMENTATION_PLAN.md
├── 2_GIGCREDIT_TEAM_WORK_SPLIT.md
└── 3_PRODUCTION_REVIEW_REPORT.md
```

## GRADE AND RISK BANDS
| Score | Grade | Risk |
|-------|-------|------|
| ≥ 850 | S (Exceptional) | Low |
| ≥ 750 | A (Excellent) | Low |
| ≥ 651 | B (Good) | Low |
| ≥ 551 | C (Average) | Medium |
| ≥ 451 | D (Below Average) | Medium |
| ≤ 450 | E (Poor) | High |

Score ≥ 651 = Low Risk | 451-650 = Medium Risk | ≤ 450 = High Risk

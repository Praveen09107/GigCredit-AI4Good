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
9. Meta-Learner (Logistic Regression, 20 inputs) produces probability
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
4. **Utility Bills** — 6 months each: electricity, gas, mobile (18 mandatory uploads)
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

## DIRECTORY STRUCTURE
```
GigCredit/
├── offline_ml/               # Python: data gen, training, m2cgen export
│   ├── data_generator.py
│   ├── tune_models.py
│   ├── train_final.py
│   ├── extract_shap.py
│   ├── train_meta_learner.py
│   ├── export_to_dart.py
│   └── validate_export.py
├── backend/                  # Python: FastAPI + MongoDB
│   ├── main.py
│   ├── database.py
│   ├── models.py
│   ├── auth.py
│   ├── seed_db.py
│   └── routers/
│       ├── verify.py
│       └── report.py
├── gigcredit_app/            # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── ai/               # TFLite, PaddleOCR, face verification
│   │   ├── core/             # Feature engineering, bank parser, confidence
│   │   ├── models/           # Data classes
│   │   ├── scoring/          # m2cgen scorers, meta-learner, explainability, scorecards
│   │   ├── services/         # API client
│   │   └── ui/               # All screens
│   ├── assets/
│   │   ├── models/           # .tflite files (FaceNet, EfficientNet)
│   │   └── constants/        # .json files (SHAP, meta coefficients)
│   └── test/
└── planning/                 # This folder — planning documents
```

## GRADE AND RISK BANDS
| Score | Grade | Risk |
|-------|-------|------|
| ≥ 800 | S (Exceptional) | Low |
| ≥ 720 | A (Excellent) | Low |
| ≥ 640 | B (Good) | Low |
| ≥ 560 | C (Average) | Medium |
| ≥ 480 | D (Below Average) | Medium |
| < 480 | E (Poor) | High |

Score ≥ 651 = Low Risk | 451-650 = Medium Risk | ≤ 450 = High Risk

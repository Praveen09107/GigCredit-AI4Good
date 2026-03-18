# ================================================================================
# GIGCREDIT — PRODUCTION-LEVEL REVIEW REPORT
# Reviewer: AI Agent | Date: 2026-03-18
# Documents Reviewed: 0_PROJECT_CONTEXT.md, 1_FULL_IMPLEMENTATION_PLAN.md, 2_TEAM_WORK_SPLIT.md
# Cross-Referenced Against: All 20 original specification files
# ================================================================================

---

## VERDICT: 🟡 CONDITIONAL GREEN LIGHT — 3 FIXES REQUIRED BEFORE IMPLEMENTATION

The planning suite is **95% production-ready**. The scoring pipeline, feature
engineering, team split, and handoff strategy are all excellent. However, I found
**3 critical issues** that will cause bugs if not fixed, and **5 structural
improvements** that will save significant debugging time during the 48-hour sprint.

---

## 🔴 CRITICAL ISSUES (MUST FIX BEFORE CODING)

### ISSUE 1: Feature Count Mismatch in P5 Scorecard (18 listed, 17 enumerated)
**Location:** `1_IMPLEMENTATION_PLAN.md` → Task 5.3, lines 570-575
**Problem:** P5 is defined as 18 features (indices 49-66), but only 17 feature names
are listed. The count is:
```
aadhaar_verified, pan_verified, face_match_score, kyc_completeness,
name_consistency_score, address_match_score, work_type_encoded (4 one-hot = 4 items),
profession_tenure_norm, age_suitability_score, platform_tenure_norm,
platform_rating_norm, dl_valid, rc_active, nsdc_certified, nsqf_level_norm,
gst_registered, trade_licence_valid
```
That's 6 + 4 + 7 = **17 features**, not 18. One feature is missing.

**Fix:** Add `vehicle_insurance_work_type_weighted` as index 66 (from the original spec), OR
recount and confirm the exact mapping. If it is genuinely 17, then P6 starts at index 66
not 67, which would cascade through ALL subsequent index slicing in the scoring engine.
This is a **pipeline-breaking** error if not fixed.

### ISSUE 2: Missing `state_income_anchors.json` in Asset Delivery (Task 1.8)
**Location:** `1_IMPLEMENTATION_PLAN.md` → Task 1.8
**Problem:** Feature P1[0] (`avg_monthly_income_norm`) uses `state_anchor` from
`state_income_anchors.json`. This file is listed in the original spec (Part 12) but
is NOT included in the Task 1.8 handoff copy list. The feature engineering code will
crash at runtime trying to load a non-existent file.

**Fix:** Add to Task 1.8:
```
state_income_anchors.json → gigcredit_app/assets/constants/state_income_anchors.json
feature_means.json → gigcredit_app/assets/constants/feature_means.json
```
Also add a script in `offline_ml/` that generates it from official state-level median
income data (or hardcodes 36 values from the spec).

### ISSUE 3: Missing API Client Module in Dev B's Dependencies
**Location:** `2_TEAM_WORK_SPLIT.md` → Directory Ownership
**Problem:** Developer B owns `lib/ui/` and `lib/core/`, and their screens call
backend verification APIs (Step 2 calls `/gov/pan/verify`, Step 3 calls `/bank/ifsc/verify`,
etc.). BUT `lib/services/` (the API client) is owned by Developer A.

Developer B will need to call these APIs starting at Hour 1 (Step 2 UI), but Dev A
may not have the API client ready until Hour 10 (backend deployment).

**Fix:** Developer A must publish `lib/services/api_client.dart` as a stub on Hour 2
(same time as the AI interfaces). The stub should have:
```dart
abstract class IApiClient {
  Future<Map<String, dynamic>> verifyPan(String pan);
  Future<Map<String, dynamic>> verifyAadhaar(String aadhaar);
  Future<Map<String, dynamic>> verifyIfsc(String ifsc);
  Future<Map<String, dynamic>> generateReport(Map<String, dynamic> payload);
  // ... all 9 endpoints
}
```
Add a `MockApiClient` returning hardcoded JSON so Dev B can build and test immediately.

---

## 🟡 STRUCTURAL IMPROVEMENTS (STRONGLY RECOMMENDED)

### IMPROVEMENT 1: Flutter Folder Structure Needs More Granularity
**Problem:** The current `lib/ui/` is flat — all 15+ screens in one folder.
The `lib/core/` mixes providers, parsers, and generators. This will become messy fast.

**Recommended Structure:**
```
gigcredit_app/lib/
├── main.dart
├── app/
│   ├── router.dart                    # GoRouter config
│   ├── theme.dart                     # Colors, text styles, gradients
│   └── constants.dart                 # API URLs, feature indices, pillar weights
├── models/
│   ├── bank_transaction.dart
│   ├── verified_profile.dart
│   ├── score_report.dart
│   ├── processed_document.dart
│   └── enums.dart                     # WorkType, TransactionTag, AuthResult, etc.
├── providers/
│   ├── verified_profile_provider.dart
│   ├── auth_provider.dart
│   └── score_provider.dart
├── ai/                                # Dev A owns
│   ├── ai_interfaces.dart             # Abstract classes (published Hour 2)
│   ├── authenticity_detector.dart
│   ├── face_verifier.dart
│   ├── ocr_engine.dart
│   ├── field_extractors.dart
│   └── document_processor.dart
├── services/                          # Dev A owns
│   ├── api_client.dart                # Interface + implementation
│   ├── mock_api_client.dart           # For Dev B to use until backend is live
│   └── secure_storage_service.dart
├── scoring/                           # Dev B owns
│   ├── p1_scorer.dart  (auto-generated)
│   ├── p2_scorer.dart  (auto-generated)
│   ├── p3_scorer.dart  (auto-generated)
│   ├── p4_scorer.dart  (auto-generated)
│   ├── p6_scorer.dart  (auto-generated)
│   ├── scorecard_p5.dart
│   ├── scorecard_p7.dart
│   ├── scorecard_p8.dart
│   ├── meta_learner.dart
│   ├── scoring_engine.dart
│   ├── feature_sanitizer.dart
│   ├── pillar_validator.dart
│   ├── shap_engine.dart
│   └── scoring_constants.dart         # Grade cutoffs, risk bands, pillar weights
├── core/                              # Dev B owns
│   ├── feature_engineering.dart
│   ├── confidence_engine.dart
│   ├── bank_parser.dart
│   ├── transaction_tagger.dart
│   └── pdf_generator.dart
├── ui/
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── home_screen.dart
│   │   ├── guidelines_screen.dart
│   │   ├── language_select_screen.dart
│   │   ├── report_loading_screen.dart
│   │   ├── final_report_screen.dart
│   │   └── steps/
│   │       ├── step1_profile.dart
│   │       ├── step2_identity.dart
│   │       ├── step3_bank.dart
│   │       ├── step4_utilities.dart
│   │       ├── step5_work_proof.dart
│   │       ├── step6_schemes.dart
│   │       ├── step7_insurance.dart
│   │       └── step8_itr_gst.dart
│   └── widgets/
│       ├── document_upload_card.dart   # Reusable upload widget
│       ├── score_gauge.dart           # Circular score dial
│       ├── pillar_bar.dart            # Single pillar progress bar
│       ├── step_progress_bar.dart     # Top nav showing 1-8 steps
│       ├── work_type_selector.dart    # The 4-card grid
│       └── loading_overlay.dart       # Processing state overlay
├── assets/
│   ├── models/
│   │   ├── mobilefacenet.tflite
│   │   └── efficientnet_lite0.tflite
│   └── constants/
│       ├── shap_lookup.json
│       ├── meta_coefficients.json
│       ├── state_income_anchors.json
│       └── feature_means.json
└── test/
    ├── golden_profile_test.dart
    ├── feature_engineering_test.dart
    └── scoring_engine_test.dart
```

**Why this is better:**
- `app/` centralizes config that both developers reference (no directory conflict)
- `providers/` is its own folder (not stuffed inside `core/`)
- `ui/widgets/` extracts reusable components (the upload card alone is used 30+ times)
- `models/` has clear data classes separate from logic
- `services/` has explicit mock for parallel development

### IMPROVEMENT 2: Missing Reusable Upload Widget
**Problem:** Steps 2-8 all need "upload a document image via camera or gallery."
That's 30+ upload slots. Without a shared widget, each step screen will have 50+
lines of duplicated camera/gallery/file-picker code.

**Fix:** Create `lib/ui/widgets/document_upload_card.dart`:
```dart
class DocumentUploadCard extends StatelessWidget {
  final String label;
  final String? hint;
  final bool required;
  final bool allowPDF;
  final bool cameraOnly;  // For selfie
  final Function(File) onFileSelected;
  final Function(ProcessedDocument)? onProcessed;  // After OCR
}
```
Dev B should build this FIRST (Hour 2), then every step screen simply composes
instances of this widget.

### IMPROVEMENT 3: Backend Needs a `requirements.txt`
**Problem:** The backend install command is manual `pip install ...`. If Dev A
adds a new package later, Dev B (or Render) won't know about it.

**Fix:** Create `backend/requirements.txt`:
```
fastapi==0.109.0
uvicorn==0.27.0
motor==3.3.2
pymongo==4.6.1
google-generativeai==0.3.2
python-dotenv==1.0.0
pydantic==2.5.3
```

### IMPROVEMENT 4: Missing `feature_means.json` Generation
**Problem:** Task 5.3 uses `feature_means.json` for NaN fallback on several features
(e.g., state_anchor normalization). This file is referenced in the original spec
(Part 12) but there is no explicit task to generate it from the training data.

**Fix:** Add to Task 1.4 or create a Task 1.4b:
```python
feature_means = X_train.mean(axis=0).tolist()
json.dump(feature_means, open('data/feature_means.json', 'w'))
```

### IMPROVEMENT 5: Team Split Doc References Non-Existent File
**Location:** `2_TEAM_WORK_SPLIT.md` line 34
**Problem:** References `planning/4_IMPLEMENTATION_PLAN_20_PHASES.md` which does not exist.
**Fix:** Either remove this line, or change it to reference `planning/1_GIGCREDIT_FULL_IMPLEMENTATION_PLAN.md`.

---

## ✅ WHAT IS EXCELLENT (NO CHANGES NEEDED)

| Area | Assessment |
|------|------------|
| **Scoring Pipeline (18 steps)** | Perfect. Matches the revised spec exactly. Feature index slicing, confidence engine, debt band cap, meta-learner all correctly sequenced. |
| **m2cgen Export Pipeline** | Correctly enforces `tree_method='exact'`, `sys.setrecursionlimit(50000)`, validation gate with `< 1e-5` tolerance. All known m2cgen pitfalls addressed. |
| **Meta-Learner 20-input design** | Correctly uses 8 pillars + 4 one-hot + 8 interaction terms. No weighted sum contradiction. |
| **HMAC-SHA256 Auth (user edit)** | Excellent security improvement. Replay protection, constant-time comparison, structured rate limiting. |
| **Team Split Strategy** | Directory ownership is clean. AI interface stubs at Hour 2 is the right pattern. Handoff checklist is explicit. |
| **Priority Cut Order** | Smart. Protects the scoring engine (core IP) while allowing graceful degradation of supporting features. |
| **Transaction Tagging Engine** | 4-layer approach with Indian-specific keywords is comprehensive. Covers all major platforms and payment types. |
| **Confidence Engine** | Correctly implements the spec's minimum data threshold and floor rules. |

---

## SUMMARY OF REQUIRED ACTIONS

| # | Severity | Action | Effort |
|---|----------|--------|--------|
| 1 | 🔴 CRITICAL | Fix P5 feature count (17 vs 18) and verify ALL subsequent index slicing | 15 min |
| 2 | 🔴 CRITICAL | Add `state_income_anchors.json` + `feature_means.json` to Task 1.8 handoff | 5 min |
| 3 | 🔴 CRITICAL | Add API client interface stub to Hour 2 handoff (alongside AI interfaces) | 10 min |
| 4 | 🟡 IMPROVE | Restructure Flutter folders as recommended above | 20 min |
| 5 | 🟡 IMPROVE | Create `DocumentUploadCard` reusable widget task | 5 min |
| 6 | 🟡 IMPROVE | Add `backend/requirements.txt` | 2 min |
| 7 | 🟡 IMPROVE | Add `feature_means.json` generation to ML pipeline | 5 min |
| 8 | 🟡 IMPROVE | Fix dead reference to `4_IMPLEMENTATION_PLAN_20_PHASES.md` | 1 min |

**After fixing items 1-3, you have a GREEN LIGHT to proceed with implementation.**

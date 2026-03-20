# Dev A Integration Guide — How to Plug Into Dev B's Frontend
**Document Type:** Integration Handoff Guide for Dev A  
**Last Updated:** 2026-03-19  
**Purpose:** Everything Dev A needs to know to integrate their ML artifacts, backend APIs, and AI services into Dev B's fully built Flutter frontend.

> **Read this before writing a single line of integration code.**  
> Dev B's architecture is designed for zero-friction plug-in. You just drop files in the right places.

---

## 1. What Dev B Has Already Built for You

Dev B's frontend is 100% ready with:

- ✅ All 9 UI step screens collecting user data
- ✅ `VerifiedProfile` state holding all verified fields
- ✅ 95-dimensional feature vector builder waiting for your scorer inputs
- ✅ `MetaLearner` wired and running (synthetic coefficients active now)
- ✅ `ShapLookupService` waiting for your real SHAP bins
- ✅ Report UI and PDF generation ready
- ✅ Adapter classes at every integration seam

---

## 2. The 3 Files You Must Deliver (ML Artifacts)

### 2.1 `p1_scorer.dart` … `p6_scorer.dart`

**Where to drop:** `gigcredit_app/lib/scoring/`

These are **m2cgen-generated** Dart scorers — one per pillar.

Expected function signature for each:

```dart
// Example: lib/scoring/p1_scorer.dart
double scoreP1(List<double> features) {
  // m2cgen generated tree/linear body
  return /* raw pillar score */;
}
```

**Feature slice ranges** (from `feature_engineering.dart`):

| Scorer | Pillar | Feature Indices (0-indexed) |
|--------|--------|-----------------------------|
| p1_scorer | Identity & KYC | 0–14 |
| p2_scorer | Bank & Transactions | 15–29 |
| p3_scorer | Utilities | 30–39 |
| p4_scorer | Work Proof | 40–49 |
| p5_scorer | Govt Schemes | 50–59 |
| p6_scorer | Insurance + Tax | 60–74 |

> Dev B will call them like this (no changes needed to pipeline):
```dart
final allFeatures = ScoringPipeline().buildSanitizedVector95(profile);
final p1 = scoreP1(allFeatures.sublist(0, 15));
final p2 = scoreP2(allFeatures.sublist(15, 30));
// ...etc
```

---

### 2.2 `meta_coefficients.json`

**Where to drop:** `gigcredit_app/assets/constants/meta_coefficients.json`

**Exact format required:**

```json
{
  "coefficients": [
    1.234, -0.567, 0.891, 0.234, -0.456, 1.678, 0.345, 0.789,
    0.123, 0.456, 0.234, -0.123, 0.567, 0.890, 0.234, 0.678,
    -0.345, 0.456, 0.789, 0.234
  ],
  "intercept": -0.312,
  "source": "dev_a_lr_v1"
}
```

- Exactly **20 floats** in `coefficients`
- One float for `intercept`
- `source` is a label string (any value)

**How Dev B loads it** (already wired in `dev_a_handoff_adapter.dart`):

```dart
// On app startup, call:
final jsonStr = await rootBundle.loadString('assets/constants/meta_coefficients.json');
final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
final coefficients = DevAHandoffAdapter.fromJsonMap(jsonMap);
// Then inject into MetaLearner
```

> After you drop the file, Dev B will replace the synthetic coefficients automatically.

---

### 2.3 `shap_lookup.json`

**Where to drop:** `gigcredit_app/assets/constants/shap_lookup.json`

**Exact format required:**

```json
{
  "bank_verified": {
    "low": -0.3,
    "medium": 0.1,
    "high": 0.6
  },
  "aadhaar_verified": {
    "low": -0.2,
    "medium": 0.0,
    "high": 0.5
  },
  "itr_verified": { "low": -0.4, "medium": 0.1, "high": 0.7 },
  "pan_verified": { "low": -0.1, "medium": 0.0, "high": 0.4 },
  "gst_verified": { "low": -0.2, "medium": 0.0, "high": 0.5 },
  "insurance_verified": { "low": -0.1, "medium": 0.0, "high": 0.3 },
  "high_dti": { "low": 0.1, "medium": -0.2, "high": -0.5 },
  "no_tax_docs": { "low": 0.0, "medium": -0.2, "high": -0.4 },
  "low_transaction_depth": { "low": 0.0, "medium": -0.1, "high": -0.3 }
}
```

Keys must match exactly what `ShapLookupService` queries:
`bank_verified`, `aadhaar_verified`, `pan_verified`, `itr_verified`, `gst_verified`, `insurance_verified`, `high_dti`, `no_tax_docs`, `low_transaction_depth`

---

## 3. Backend API Endpoints Dev B Calls

These endpoints are called from the step screens. Dev B uses **named constants** for base URL — you just update one file.

### 3.1 Update Base URL

**File:** `gigcredit_app/lib/services/backend_client.dart`

```dart
// Change this line to your deployed backend URL:
static const String baseUrl = 'https://YOUR-DOMAIN.com/api/v1';
```

---

### 3.2 Endpoint Contract — All Endpoints Dev B Hits

| Step | Method | Endpoint | Request Body | Expected Response |
|------|--------|----------|--------------|-------------------|
| Step 2 | POST | `/gov/aadhaar/verify` | `{"aadhaar_number": "XXXX"}` | `{"verified": true, "name": "..."}` |
| Step 2 | POST | `/gov/pan/verify` | `{"pan_number": "ABCDE1234F"}` | `{"verified": true, "name": "..."}` |
| Step 3 | POST | `/bank/parse` | multipart PDF file | `{"transactions": [...], "account_number": "..."}` |
| Step 4 | POST | `/utility/electricity/verify` | `{"consumer_number": "..."}` | `{"verified": true}` |
| Step 4 | POST | `/utility/lpg/verify` | `{"connection_id": "..."}` | `{"verified": true}` |
| Step 5 | POST | `/work/verify` | multipart document file | `{"verified": true, "work_type": "..."}` |
| Step 6 | POST | `/govt/svanidhi/verify` | `{"loan_number": "..."}` | `{"verified": true}` |
| Step 6 | POST | `/govt/eshram/verify` | `{"eshram_card": "..."}` | `{"verified": true}` |
| Step 7 | POST | `/insurance/verify` | `{"policy_number": "..."}` | `{"verified": true, "type": "health"}` |
| Step 8 | POST | `/tax/itr/verify` | `{"pan": "...", "assessment_year": "..."}` | `{"verified": true, "annual_income": 320000}` |
| Step 8 | POST | `/tax/gst/verify` | `{"gstin": "..."}` | `{"verified": true, "annual_turnover": 500000}` |
| Step 9 | POST | `/loan/verify` | `{"lender": "...", "emi_amount": 3500}` | `{"verified": true}` |
| Report | POST | `/report/generate` | `{"profile": {...}}` | `{"score": 750, "risk_band": "LOW", "summary": "..."}` |

---

### 3.3 Standard Response Schema

All endpoints must return:

```json
{
  "verified": true,
  "error": null
}
```

On failure:

```json
{
  "verified": false,
  "error": "Aadhaar number not found in UIDAI database"
}
```

Dev B reads `verified` and shows the error string directly if `error != null`.

---

## 4. AI Interface Implementations Dev A Must Provide

Dev B calls these abstractions from `ai_interfaces.dart`. Dev A must implement them.

### 4.1 `OcrEngine`

**Interface location:** `gigcredit_app/lib/ai/ai_interfaces.dart`

```dart
abstract class OcrEngine {
  Future<OcrResult> extractText(File imageOrPdf);
}

class OcrResult {
  final String rawText;
  final Map<String, String> fields; // e.g. {"name": "Praveen", "dob": "01-01-1996"}
}
```

**Used in:** Step 2 (KYC), Step 3 (bank), Step 5 (work proof), Steps 6-8 (documents)

---

### 4.2 `FaceVerifier`

```dart
abstract class FaceVerifier {
  Future<FaceMatchResult> matchSelfieToDocument(File selfie, File document);
}

class FaceMatchResult {
  final double matchScore; // 0.0 to 1.0
  final bool isMatch;      // true if matchScore >= 0.75 (configurable threshold)
}
```

**Used in:** Step 2 (selfie vs Aadhaar/PAN photo)

---

### 4.3 `AuthenticityDetector`

```dart
abstract class AuthenticityDetector {
  Future<AuthenticityResult> check(File document);
}

class AuthenticityResult {
  final bool isAuthentic;
  final double confidenceScore;
  final String failureReason; // null if authentic
}
```

**Used in:** Steps 2, 5, 6, 7, 8 (document fraud detection before OCR)

---

### 4.4 `DocumentProcessor`

```dart
abstract class DocumentProcessor {
  Future<ProcessedDocument> process(File file, DocumentType type);
}

enum DocumentType { aadhaar, pan, bankStatement, itr, insurance, workProof }

class ProcessedDocument {
  final bool isAuthentic;
  final OcrResult ocr;
  final Map<String, String> verifiedFields;
}
```

**Used in:** All document upload steps

---

## 5. Dependency Injection — Where to Wire Your Implementations

**File:** `gigcredit_app/lib/di.dart` (create this if not present)

```dart
// This is where you inject your concrete AI implementations:
import 'package:gigcredit_app/ai/ai_interfaces.dart';

// Your real implementations:
import 'package:gigcredit_app/ai/YOUR_ocr_impl.dart';
import 'package:gigcredit_app/ai/YOUR_face_verifier_impl.dart';

final ocrEngineProvider = Provider<OcrEngine>((ref) => YourRealOcrEngine());
final faceVerifierProvider = Provider<FaceVerifier>((ref) => YourRealFaceVerifier());
final authenticityDetectorProvider = Provider<AuthenticityDetector>((ref) => YourRealDetector());
final documentProcessorProvider = Provider<DocumentProcessor>((ref) => YourRealProcessor());
```

---

## 6. Integration Checklist — Step by Step

Follow this exact order:

```
[ ] 1. Deploy backend → get base URL
[ ] 2. Update baseUrl in backend_client.dart
[ ] 3. Drop p1_scorer.dart … p6_scorer.dart into lib/scoring/
[ ] 4. Drop meta_coefficients.json into assets/constants/
[ ] 5. Update pubspec.yaml assets list if needed:
          assets:
            - assets/constants/meta_coefficients.json
            - assets/constants/shap_lookup.json
[ ] 6. Drop shap_lookup.json into assets/constants/
[ ] 7. In dev_a_handoff_adapter.dart, load real coefficients:
          final json = await rootBundle.loadString('assets/constants/meta_coefficients.json');
          final coeffs = DevAHandoffAdapter.fromJsonMap(jsonDecode(json));
[ ] 8. In shap_lookup_service.dart, load real shap bins from asset
[ ] 9. Create lib/di.dart and inject your AI implementations
[  ] 10. In each step screen, replace stub calls with real AI providers
[ ] 11. Run: flutter test  → expect 11 tests to still pass
[ ] 12. Run on physical device end-to-end
[ ] 13. Generate real report and check PDF output
```

---

## 7. What Dev B WILL NOT Change

Dev B guarantees **backward compatibility** on all of these:

- `VerifiedProfile` model structure (Dev A can read it via `verified_profile_provider`)
- `ScoringPipeline.buildSanitizedVector95()` — stable, returns `List<double>[95]`
- `DevAHandoffAdapter.fromJsonMap()` — reads your JSON exactly
- `DevAHandoffAdapter.buildMetaInput20()` — takes pillar8 + workType
- `MetaLearner.infer()` signature — takes `List<double>[20]`
- All named routes in `app_router.dart`

---

## 8. Contact Surface Summary

```
Dev A delivers                   Dev B already has ready
─────────────────────────        ──────────────────────────
p1..p6 scorer .dart files   →   lib/scoring/ (empty slots)
meta_coefficients.json      →   DevAHandoffAdapter.fromJsonMap()
shap_lookup.json            →   ShapLookupService (reads it)
OcrEngine impl              →   ai_interfaces.dart (abstract)
FaceVerifier impl           →   ai_interfaces.dart (abstract)
AuthenticityDetector impl   →   ai_interfaces.dart (abstract)
DocumentProcessor impl      →   ai_interfaces.dart (abstract)
Backend base URL            →   backend_client.dart (one-line change)
/verify/* endpoints live    →   step screens call them
/report/generate live       →   report_provider.dart calls it
```

---

> **Dev B is ready. The moment Dev A drops their files in the correct locations and follows this checklist, the full GigCredit pipeline will be production-ready.**

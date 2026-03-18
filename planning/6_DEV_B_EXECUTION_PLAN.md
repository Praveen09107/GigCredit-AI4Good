<!-- markdownlint-disable -->

## Dev B — Full Execution Plan (On-Device App Core, UX, Scoring)

**Role summary**:  
Dev B owns the **Flutter application**: state management, session persistence, onboarding flow, bank parsing, EMI analysis, feature engineering, scoring, SHAP explainability, report UI, and PDF generation. Dev B does **not** implement backend or ML training; Dev B **consumes**:

- Backend HTTP APIs via `BackendClient`.
- On-device AI services via `ai_interfaces.dart`.
- m2cgen-generated Dart scorers + SHAP + meta coefficients from `offline_ml/`.

Authoritative references:

- `planning/4_IMPLEMENTATION_PLAN_20_PHASES.md`
- `planning/3_END_TO_END_WORKFLOW_FREEZE.md`
- `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`
- `planning/2_GIGCREDIT_TEAM_WORK_SPLIT.md`

---

## 1. Ownership and boundaries

Dev B **owns** and is the primary implementer of:

- `gigcredit_app/lib/main.dart`
- `gigcredit_app/lib/app_router.dart`
- `gigcredit_app/lib/di.dart` (when created)
- `gigcredit_app/lib/models/**`
- `gigcredit_app/lib/state/**`
- `gigcredit_app/lib/core/**`
- `gigcredit_app/lib/scoring/**`
- `gigcredit_app/lib/ui/**`
- `gigcredit_app/test/**`

Dev B **must not edit**:

- `backend/**`
- `offline_ml/**`
- `gigcredit_app/lib/ai/**` (interfaces may be read, but implementations are Dev A)
- `gigcredit_app/lib/services/backend_client.dart` (Dev A owns low-level client; Dev B can create higher-level services using it)
- `planning/**` (read-only, unless agreed spec change)

Integration surfaces Dev B uses:

1. `BackendClient` to call all `/verify/*` and `/report/generate` endpoints.
2. `OcrEngine`, `AuthenticityDetector`, `FaceVerifier`, `DocumentProcessor` from `ai_interfaces.dart` and Dev A’s implementations.
3. m2cgen scorers + SHAP + meta coefficients:
   - `lib/scoring/generated/p1_scorer.dart ... p6_scorer.dart`
   - `assets/constants/shap_lookup.json`
   - `assets/constants/meta_coefficients.json`

---

## 2. High-level implementation sequence for Dev B

Implementation order is designed so Dev B can work **independently early**, then plug in Dev A’s artifacts later.

1. **Bootstrap app + routing + base state** (Hour 0–4)
2. **Session persistence + offline queue** (Hour 4–8)
3. **Onboarding step flow skeleton (8 steps)** (Hour 4–10)
4. **Step 1 + 2 + 3 core logic (profile + KYC + bank)** (Hour 8–18)
5. **Bank parsing + tagging + EMI detection** (Hour 12–22)
6. **Feature engineering (95 features)** (Hour 18–28)
7. **Scorecards + meta-learner + score engine (with placeholder scorers)** (Hour 20–30)
8. **Integrate real scorers + SHAP + meta coefficients from Dev A** (Hour 24–32)
9. **Explainability + report UI + dynamic scoring** (Hour 26–36)
10. **PDF generation + sharing + golden tests** (Hour 32–48)

---

## 3. App shell, routing, and global state

### 3.1 Make Flutter app run (Hour 0–2)

**Files**

- `gigcredit_app/lib/main.dart`
- `gigcredit_app/lib/app_router.dart`

**Steps**

1. Update `pubspec.yaml` to include:
   - `flutter_riverpod`
   - `go_router` (or `auto_route`, choose one)
   - `http`
   - `shared_preferences` or `flutter_secure_storage`
2. Wire `ProviderScope` and router in `main.dart`:

```dart
void main() {
  runApp(const ProviderScope(child: GigCreditApp()));
}

class GigCreditApp extends ConsumerWidget {
  const GigCreditApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      routerConfig = router,
      theme: appTheme,
    );
  }
}
```

3. Define basic routes in `app_router.dart`:

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/onboarding/:step', builder: (c, s) {
        // Map step param to each step screen
      }),
      GoRoute(path: '/report', builder: (c, s) => const FinalReportScreen()),
    ],
  );
});
```

---

### 3.2 Models and state (Hour 2–4)

**Files**

- `gigcredit_app/lib/models/verified_profile.dart`
- `gigcredit_app/lib/models/enums/step_id.dart`
- `gigcredit_app/lib/models/enums/step_status.dart`
- `gigcredit_app/lib/models/score_report.dart`
- `gigcredit_app/lib/state/verified_profile_provider.dart`
- `gigcredit_app/lib/state/step_flow_provider.dart`

**Goal**: create a **single source of truth** for:

- Verified profile data (only verified fields).
- Step statuses and the current step index.
- Latest score report and score history.

Pseudocode for `StepStatus`:

```dart
enum StepStatus {
  notStarted,
  inProgress,
  ocrComplete,
  pendingVerification,
  verified,
  rejected,
}
```

`StepId` enum:

```dart
enum StepId {
  step1Profile,
  step2Kyc,
  step3Bank,
  step4Utilities,
  step5Work,
  step6Schemes,
  step7Insurance,
  step8Tax,
}
```

Create a `StepFlowState` model that maps `StepId` → `StepStatus` and keeps track of `currentStep`.

---

## 4. Session persistence and offline queue

### 4.1 Secure storage & session manager (Hour 4–8)

**Files**

- `gigcredit_app/lib/core/session/secure_storage.dart`
- `gigcredit_app/lib/core/session/session_manager.dart`

**Goals**

- Encrypt `verified_profile` on-device.
- Persist `step_progress`.
- Support session expiry (e.g., 24h) and explicit reset.

Pseudocode:

```dart
class SessionManager {
  final SecureStorage storage;

  Future<void> saveSession(VerifiedProfile profile, StepFlowState steps) async {
    final payload = jsonEncode({...});
    final encrypted = await storage.encryptAndStore('verified_profile', payload);
    await storage.writePlain('step_progress', jsonEncode(steps.toJson()));
  }

  Future<SessionSnapshot?> loadSession() async {
    final encrypted = await storage.readEncrypted('verified_profile');
    if (encrypted == null) return null;
    final decrypted = await storage.decrypt(encrypted);
    final profile = VerifiedProfile.fromJson(jsonDecode(decrypted));
    final steps = StepFlowState.fromJson(jsonDecode(await storage.readPlain('step_progress') ?? '{}'));
    // apply expiry policy
    return SessionSnapshot(profile: profile, steps: steps);
  }
}
```

---

### 4.2 Offline queue (Hour 6–10)

**Files**

- `gigcredit_app/lib/core/connectivity/network_status.dart`
- `gigcredit_app/lib/core/session/offline_queue.dart` (to be created)

**Goal**: If backend calls fail, mark steps `pendingVerification` and queue requests to replay later.

Basic design:

- `OfflineQueue` stores serialized API calls (endpoint + payload) in local storage.
- `NetworkStatus` notifies when connectivity is restored.
- A background worker replays queued calls and updates `verified_profile` and `step_state`.

---

## 5. Onboarding flow (8 steps)

### 5.1 Screen skeletons (Hour 4–10)

**Files**

- `gigcredit_app/lib/ui/onboarding/step1_profile_screen.dart`
- `... step2_kyc_screen.dart` … `step8_tax_screen.dart`
- `gigcredit_app/lib/ui/common/step_progress_bar.dart`

Each screen should:

- Read current step status from `step_flow_provider`.
- Use `StepProgressBar` to show overall onboarding progress.
- Call a **Step-specific service/controller** (in `core/`) to perform actions (not directly call AI or backend).

---

### 5.2 Step controllers (Hour 8–18)

**Files**

- `gigcredit_app/lib/core/steps/step1_profile_service.dart`
- `gigcredit_app/lib/core/steps/step2_kyc_service.dart`
- `gigcredit_app/lib/core/steps/step3_bank_service.dart`
- ...

**Example: Step 2 KYC service**

Responsibilities:

- Capture PAN + Aadhaar images.
- Call `DocumentProcessor` (Dev A) for fraud detection + OCR + field extraction.
- Cross-check OCR fields against user input.
- Call backend `/verify/pan` and `/verify/aadhaar`.
- Call `FaceVerifier` to match selfie vs ID photo.
- On success:
  - Update `VerifiedProfile.identity`.
  - Mark `STEP2_KYC` as `verified`.
  - Trigger a provisional score recompute if Step-3 is already done.

Design:

- These services orchestrate multiple calls but **do not** implement AI or networking directly.
- They depend on:
  - `BackendClient` (for HTTP).
  - `DocumentProcessor`/`FaceVerifier` (for AI).

---

## 6. Bank parsing + EMI detection

### 6.1 Bank parser (Hour 12–22)

**Files**

- `gigcredit_app/lib/core/bank/bank_parser.dart`
- `gigcredit_app/lib/core/bank/transaction_tagger.dart`
- `gigcredit_app/lib/core/bank/emi_detector.dart`

**Goal**: produce:

- `List<BankTransaction>` in memory.
- Optionally `bank_transactions.csv` for debugging or offline ML.

Steps:

1. From Step-3, get:
   - Bank statement PDF/images via `DocumentProcessor`.
   - Raw text from OCR.
2. `BankParser` converts raw text into an intermediate line representation, then `BankTransaction` objects.
3. `TransactionTagger` uses regex and keyword rules to mark:
   - Salary, rent, EMI, UPI, cash, etc.
4. `EmiDetector` identifies recurring debits that look like EMIs and computes:
   - `active_emi_count`
   - `total_monthly_emi`
   - Debt-to-income ratio (after Dev A passes income anchors or step-1 profile).

These values are written into `VerifiedProfile.emi_obligations`.

---

## 7. Feature engineering

### 7.1 FeatureEngineer (Hour 18–28)

**Files**

- `gigcredit_app/lib/scoring/feature_engineer.dart`
- `gigcredit_app/lib/scoring/feature_sanitizer.dart`

**Goal**: deterministically convert `VerifiedProfile` + `BankTransaction[]` + step-completion metadata into a **95-length feature vector**.

Process:

1. Go through spec in `Feature engineering (1).txt` and `Input_fields_final (1).txt`.
2. Define a `FeatureVector` wrapper:

```dart
class FeatureVector {
  final List<double> values;
  FeatureVector(this.values) : assert(values.length == 95);
}
```

3. `FeatureEngineer.build(VerifiedProfile profile, List<BankTransaction> txns)`:
   - Derive each engineered feature explicitly.
4. `FeatureSanitizer.sanitize(FeatureVector v)`:
   - Replace NaN/Inf with safe defaults.
   - Clamp values into valid ranges.

Unit tests:

- Golden profile → exact vector.

---

## 8. Scoring engine (with placeholders first)

### 8.1 Scorecards + meta-learner shell (Hour 20–30)

**Files**

- `gigcredit_app/lib/scoring/scorecards/scorecard_p5.dart`
- `... scorecard_p7.dart`, `scorecard_p8.dart`
- `gigcredit_app/lib/scoring/meta_learner.dart`
- `gigcredit_app/lib/scoring/score_engine.dart`

**Strategy**

- Implement **everything except** the m2cgen scorers using placeholder values.
- This lets Dev B verify full pipeline before Dev A’s scorers are ready.

Example placeholder:

```dart
double scoreP1(List<double> x) => 0.5; // replaced by generated p1_scorer.dart later
```

Meta-learner:

- Reads `meta_coefficients.json` (placeholder values initially).
- Applies LR:

```dart
double logistic(double z) => 1.0 / (1.0 + math.exp(-z));

double metaScore(Pillars p, WorkType workType) {
  // z = intercept + sum(w_i * feature_i)
  return logistic(z) * 900 + 100; // if spec uses 100–1000 band
}
```

Score engine:

```dart
class ScoreEngine {
  ScoreReport score(VerifiedProfile profile, List<BankTransaction> txns) {
    final features = sanitizer.sanitize(engineer.build(profile, txns));
    final p1 = scoreP1(features.slice(p1Start, p1End));
    ...
    final pillars = PillarScores(...);
    final score = metaLearner.finalScore(pillars, profile.workType);
    return ScoreReport(pillars: pillars, score: score);
  }
}
```

---

### 8.2 Integrate real m2cgen scorers + constants (Hour 24–32)

Once Dev A provides:

- `lib/scoring/generated/p1_scorer.dart ... p6_scorer.dart`
- `assets/constants/shap_lookup.json`
- `assets/constants/meta_coefficients.json`

Dev B must:

1. Replace placeholder `scoreP1`… with imports:

```dart
import 'generated/p1_scorer.dart' as p1;

final p1Score = p1.scoreP1(features.sublist(...));
```

2. Load `meta_coefficients.json` at app startup and inject into `MetaLearner`.
3. Load `shap_lookup.json` into `ShapEngine`.

No structural changes should be required; only wiring.

---

## 9. SHAP explainability and report UI

### 9.1 ShapEngine (Hour 26–34)

**File**

- `gigcredit_app/lib/scoring/shap_engine.dart`

**Goal**: given the final pillars and per-feature SHAP lookup, compute:

- Top 3 positive factors.
- Top 3 negative factors.

Pseudo-API:

```dart
class ShapEngine {
  ShapEngine(Map<String, dynamic> lookup);

  List<ShapFactor> topFactors(FeatureVector v, PillarScores pillars) {
    // compute approximate contributions using lookup bins
  }
}
```

---

### 9.2 Report UI + dynamic score (Hour 28–36)

**Files**

- `gigcredit_app/lib/ui/report/final_report_screen.dart`
- `gigcredit_app/lib/ui/common/score_gauge.dart`
- `gigcredit_app/lib/ui/report/report_loading_screen.dart`

**Behavior**

- After minimum gate (Steps 1–3 + bank transactions threshold), display:
  - Provisional score.
  - Pillar bar chart.
  - Key positive/negative factors.
- After all steps and final recompute:
  - Fetch LLM explanation via `ReportService` using backend.
  - Display multilingual report with explanation + suggestions.

---

## 10. PDF generation + golden tests

### 10.1 PDF generation (Hour 32–42)

**File**

- `gigcredit_app/lib/ui/report/pdf_report_generator.dart` (or `lib/report/pdf_report_generator.dart`)

**Goal**: generate a shareable PDF based on final report screen data.

Use a Flutter PDF package (e.g. `pdf` + `printing`):

- Build a layout mirroring the UI:
  - Score gauge, pillars, factors, explanation text.
- Export to file and share via standard share sheet.

---

### 10.2 Golden tests (Hour 36–48)

**Files**

- `gigcredit_app/test/unit/scoring/feature_engineer_test.dart`
- `gigcredit_app/test/unit/scoring/score_engine_test.dart`
- `gigcredit_app/test/widget/onboarding_flow_test.dart`
- `gigcredit_app/test/widget/report_screen_test.dart`

**Goals**

- Use fixed `VerifiedProfile` and `BankTransaction[]` to ensure:
  - Deterministic feature vector.
  - Deterministic score.
  - Widget tests load and show expected texts.

---

## 11. Integration responsibilities

During implementation, Dev B should:

- Treat `ai_interfaces.dart` and `BackendClient` as **black boxes**:
  - Rely only on their method signatures, not their internals.
- Coordinate with Dev A at each handoff:
  - Time when `/verify/*` endpoints are stable.
  - Time when `/report/generate` is stable and base URL is live.
  - Delivery of scorers + SHAP + meta coefficients.
- Avoid modifying generated scorers; treat `lib/scoring/generated/` as read-only.

If any friction or ambiguity arises, update this doc and the main planning docs so both developers and their agents have a single source of truth.


# ================================================================================
# GIGCREDIT — FULL END-TO-END IMPLEMENTATION PLAN (FINAL)
# Version: IMPLEMENTATION-READY (MVP/HACKATHON, Scoring via m2cgen pure-Dart) | Timeline: 48 Hours
# ================================================================================
# THIS DOCUMENT IS THE SINGLE SOURCE OF TRUTH FOR THE ENTIRE BUILD.
# Both developers and their AI coding agents must implement EXACTLY as written.
# All file paths are relative to the root of their respective project.
# ================================================================================

---

# PHASE 0: PROJECT INITIALIZATION (Hour 0–1)
**Goal:** Create the 3 isolated codebases that compose the system.

## Task 0.1: Create Flutter Mobile App
```
flutter create gigcredit_app --org com.gigcredit --platforms android
```
- After creation, delete the default counter app code from `lib/main.dart`.
- Add to `pubspec.yaml` dependencies:
  ```yaml
  dependencies:
    flutter_riverpod: ^2.4.0
    go_router: ^12.0.0
    firebase_core: ^2.24.0
    firebase_auth: ^4.15.0
    image_picker: ^1.0.5
    camera: ^0.10.5
    file_picker: ^6.1.1
    pdf: ^3.10.0
    share_plus: ^7.2.1
    http: ^1.1.0
    path_provider: ^2.1.1
    flutter_secure_storage: ^9.0.0
    syncfusion_flutter_pdf: ^23.2.0
    tflite_flutter: ^0.10.4
  ```
- **Acceptance:** `flutter run` launches the default app on emulator.

## Task 0.2: Create FastAPI Backend
```
mkdir backend && cd backend
python -m venv venv
pip install fastapi uvicorn motor pymongo google-generativeai python-dotenv pydantic
```
- Create `backend/.env` with:
  ```
  MONGO_URI=mongodb+srv://<user>:<pass>@cluster.mongodb.net/gigcredit
  GEMINI_API_KEY=<your_key>
  API_KEY=gigcredit_hackathon_2026
  ```
- **Acceptance:** `uvicorn main:app --reload` starts and returns `{"status": "GigCredit API Running"}` on `GET /`.

## Task 0.3: Create Offline ML Scripts Folder
```
mkdir offline_ml && cd offline_ml
pip install xgboost scikit-learn optuna shap m2cgen numpy pandas
```
- **Acceptance:** `python -c "import m2cgen; print(m2cgen.__version__)"` returns >= 2.8.0.

---

# PHASE 1: OFFLINE ML PIPELINE (Hour 1–8)
**Goal:** Generate synthetic data, train 5 pillar ML models (XGBoost/RF), export them as **pure Dart code** via m2cgen, and extract SHAP lookup tables. This phase runs entirely in Python and produces `.dart` scorer files + constants consumed by the Flutter app.

## Task 1.1: Synthetic Data Generator
- **File:** `offline_ml/data_generator.py`
- **Function:** `generate_profiles(n=15000) -> pd.DataFrame`
- **Logic:**
  1. Define 4 work types: `['platform_worker', 'vendor', 'tradesperson', 'freelancer']`
  2. Define 5 creditworthiness tiers: `['excellent', 'good', 'average', 'poor', 'very_poor']`
  3. Work type distribution: Platform=35%, Vendor=25%, Trades=25%, Freelancer=15%
  4. Tier distribution (same for all types): Excellent=15%, Good=25%, Average=30%, Poor=20%, VeryPoor=10%
  5. For each profile, generate 95 features using these distributions:
     - `avg_monthly_income_norm` (P1 idx 0): `np.random.lognormal(mu, sigma)` where mu/sigma vary by tier. Example: Platform+Excellent: mu=10.5, sigma=0.4. Normalized: `raw / (ANCHOR * 3)`, clamped [0,1].
     - `income_stability_cv` (P1 idx 1): `np.random.beta(a, b)`. Excellent: a=8,b=2. Poor: a=2,b=5. score = 1 - min(cv, 1).
     - `emi_to_income_ratio` (P3 idx 28): `np.random.beta(a, b)`. Excellent: a=2,b=8. Very Poor: a=6,b=3.
     - Binary insurance features (P6 idx 67-73): `np.random.binomial(1, p)`. health_insurance_active: P=0.72 (Excellent), P=0.18 (Very Poor).
     - All other features follow the exact distributions from the spec's ML workflow.
  6. Generate pillar labels used for training the ML pillars:
     - `p1_label`, `p2_label`, `p3_label`, `p4_label`, `p6_label` as float [0, 1].
  7. Generate `final_label` as float [0, 1] representing overall creditworthiness.
- **Output:** `offline_ml/data/synthetic_profiles.csv` — 15,000 rows x (95 features + 6 pillar labels + 1 final label + 1 work_type) columns.
- **Acceptance:** CSV has exactly 15,000 rows. No NaN values. All feature values in [0, 1]. Tier distribution matches spec within ±2%.

## Task 1.2: Optuna Hyperparameter Tuning
- **File:** `offline_ml/tune_models.py`
- **Functions:**
  - `create_xgb_objective(X, y, strat_labels) -> Callable`
  - `create_rf_objective(X, y, strat_labels) -> Callable`
  - `run_tuning() -> dict[str, dict]`
- **Logic:**
  1. Load `synthetic_profiles.csv`. Split 80/20 stratified by `work_type` AND `tier`.
  2. For P1, P2, P3, P4 (XGBoost): Run Optuna TPE sampler, 100 trials, 5-fold StratifiedKFold.
     - **LOCKED params (NOT in search):** `tree_method='exact'`, `random_state=42`, `objective='reg:squarederror'`
     - **Search space:** `n_estimators: [80, 150]`, `max_depth: [3, 4]`, `learning_rate: [0.01, 0.3] log`, `gamma: [0.0, 1.0]`, `min_child_weight: [5, 30]`, `subsample: [0.6, 1.0]`, `colsample_bytree: [0.5, 1.0]`, `reg_alpha: [0.0, 0.5]`, `reg_lambda: [0.0, 0.5]`
  3. For P6 (RandomForest): Same Optuna setup, 100 trials.
     - **LOCKED:** `random_state=42`
     - **Search:** `n_estimators: [80, 150]`, `max_depth: [3, 4]`, `min_samples_split: [5, 30]`, `min_samples_leaf: [5, 20]`, `max_features: ['sqrt', 'log2', 0.7, 0.8]`
  4. Metric: `neg_mean_squared_error` (minimize MSE).
- **Output:** `offline_ml/data/best_params.json` — dict of best hyperparameters per pillar.
- **Acceptance:** Each model achieves RMSE < 0.10 on validation set.

## Task 1.3: Final Model Training
- **File:** `offline_ml/train_final.py`
- **Functions:**
  - `train_pillar_model(pillar, X_train, y_train, best_params) -> model`
  - `evaluate_model(model, X_val, y_val) -> dict`
- **Logic:**
  1. For each pillar (P1-P4 XGBoost, P6 RF): Instantiate model with `best_params` + locked params. Fit on full training set (12,000 samples).
  2. Evaluate on validation set (3,000 samples). Record RMSE, MAE, R².
  3. Feature index slicing (CRITICAL — must match exactly):
     - P1: `features[0:13]` (13 features)
     - P2: `features[13:28]` (15 features)
     - P3: `features[28:37]` (9 features)
     - P4: `features[37:49]` (12 features)
     - P6: `features[67:78]` (11 features)
  4. Save models: `model_p1.pkl`, `model_p2.pkl`, `model_p3.pkl`, `model_p4.pkl`, `model_p6.pkl`
- **Output:** 5 `.pkl` model files + `training_report.json` (metrics).
- **Acceptance:** All RMSE < 0.10. P1 and P2 specifically RMSE < 0.08.

## Task 1.4: SHAP Extraction (Binned Lookup Tables)
- **File:** `offline_ml/extract_shap.py`
- **Function:** `extract_shap_lookup(model, X_data, feature_names) -> dict`
- **Logic:**
  1. For each of the 5 ML models, instantiate `shap.TreeExplainer(model)`.
  2. Compute `shap_values = explainer.shap_values(X_data)`.
  3. For each feature: compute 10 percentile bins via `np.percentile(values, range(0, 101, 10))`.
  4. For each bin: compute the average SHAP value of all samples in that bin.
  5. Store as `{ "pillar_name": { "feature_name": { "bins": [...], "shap_values": [...] } } }`.
- **Output:** `offline_ml/data/shap_lookup.json` (~8-12KB).
- **Acceptance:** JSON loads without errors. Each feature has exactly 11 bin edges and 10 SHAP values.

## Task 1.5: Meta-Learner Training
- **File:** `offline_ml/train_meta_learner.py`
- **Function:** `train_meta_learner(pillar_preds_cv, work_type_oh, final_labels) -> tuple`
- **Logic:**
  1. Use cross-validated out-of-fold predictions from Task 1.3 (NOT in-sample predictions — this prevents data leakage).
  2. For P5, P7, P8: compute scorecard values directly from features (same formula as Dart).
  3. Build meta-features (20 total):
     - `[P1, P2, P3, P4, P5, P6, P7, P8]` — 8 pillar scores
     - `[is_platform, is_vendor, is_trades, is_freelancer]` — 4 one-hot flags
     - `[P1*is_platform, P1*is_vendor, P1*is_trades, P1*is_freelancer, P2*is_platform, P2*is_vendor, P2*is_trades, P2*is_freelancer]` — 8 interaction terms
  4. Binarize `final_labels`: 1 if creditworthy (>= 0.50), 0 otherwise.
  5. Train `LogisticRegression(C=1.0, max_iter=1000, random_state=42)`.
  6. Extract: `meta_model.coef_[0]` (20 coefficients) and `meta_model.intercept_[0]`.
- **Output:** `offline_ml/data/meta_coefficients.json` — `{"coefficients": [...], "intercept": float}`
- **Acceptance:** Coefficients array length == 20. LR accuracy > 75% on validation set.

## Task 1.6: m2cgen Dart Export
- **File:** `offline_ml/export_to_dart.py`
- **Logic:**
  1. `import sys; sys.setrecursionlimit(50000)` — MANDATORY to prevent RecursionError.
  2. For each of 5 models: `dart_code = m2cgen.export_to_dart(model, function_name=f'score_{name}')`.
  3. Wrap in proper Dart file header: `// AUTO-GENERATED — DO NOT EDIT`.
  4. Save as `p1_scorer.dart`, `p2_scorer.dart`, `p3_scorer.dart`, `p4_scorer.dart`, `p6_scorer.dart`.
  5. Each file contains a single function: `double score_pN(List<double> input) { ... }`.
- **Output:** 5 `.dart` files in `offline_ml/output/`.
- **Acceptance:** Each file compiles with `dart analyze`. File size each < 500KB.

## Task 1.7: Validation Gate
- **File:** `offline_ml/validate_export.py`
- **Logic:**
  1. Take 200 random validation samples.
  2. For each sample, compute Python prediction and Dart prediction (via `dart run`).
  3. Assert `max_absolute_difference < 1e-5` for ALL 5 models.
  4. If ANY model fails: STOP. Debug before proceeding.
- **Acceptance:** All 5 models produce identical outputs in Python and Dart within tolerance.

## Task 1.8: Copy Artifacts to Flutter Project
- **Logic:** Copy the generated files to the Flutter project:
  ```
  p1_scorer.dart → gigcredit_app/lib/scoring/p1_scorer.dart
  p2_scorer.dart → gigcredit_app/lib/scoring/p2_scorer.dart
  p3_scorer.dart → gigcredit_app/lib/scoring/p3_scorer.dart
  p4_scorer.dart → gigcredit_app/lib/scoring/p4_scorer.dart
  p6_scorer.dart → gigcredit_app/lib/scoring/p6_scorer.dart
  shap_lookup.json → gigcredit_app/assets/constants/shap_lookup.json
  meta_coefficients.json → gigcredit_app/assets/constants/meta_coefficients.json
  ```
- **Acceptance:** `flutter analyze` on the app reports no errors related to the scoring files.

---

# PHASE 2: FASTAPI BACKEND SERVER (Hour 1–10)
**Goal:** Build and deploy the backend that provides mock government verification APIs and LLM report generation.

## Task 2.1: MongoDB Database Setup
- **File:** `backend/database.py`
- **Functions:**
  - `get_database() -> AsyncIOMotorDatabase`
- **Logic:** Connect to MongoDB Atlas using `motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)`. Return the `gigcredit` database.
- **Acceptance:** Connection test passes (`await db.command('ping')`).

## Task 2.2: Pydantic Models & MongoDB Schemas
- **File:** `backend/models.py`
- **Classes:**
  - `PanRecord(BaseModel)`: `pan_number: str`, `full_name: str`, `dob: str`, `status: str`
  - `AadhaarRecord(BaseModel)`: `aadhaar_last4: str`, `full_name: str`, `dob: str`, `address_state: str`, `status: str`
  - `BankAccountRecord(BaseModel)`: `account_number_hash: str`, `ifsc_code: str`, `account_holder_name: str`, `bank_name: str`, `status: str`
  - `LoanRecord(BaseModel)`: `loan_id: str`, `borrower_name: str`, `lender: str`, `loan_type: str`, `emi_amount: float`, `loan_status: str`
  - `ScoreReportRecord(BaseModel)`: `user_id: str`, `score: int`, `grade: str`, `risk_band: str`, `pillar_scores: dict`, `work_type: str`, `report_text: str`, `generated_at: datetime`
  - `VerifyRequest(BaseModel)`: generic request with `identifier: str`
  - `ReportRequest(BaseModel)`: `credit_score: int`, `pillar_scores: dict`, `top_positive: list`, `top_negative: list`, `language: str`
- **Acceptance:** All Pydantic models validate without errors.

## Task 2.3: Database Seeding Script
- **File:** `backend/seed_db.py`
- **Function:** `seed_all_collections(db) -> None`
- **Logic:** Insert 10 fake records into each collection (`pan_db`, `aadhaar_db`, `bank_accounts_db`, `loan_accounts_db`). Use realistic Indian names, PAN numbers (ABCDE1234F pattern), Aadhaar last-4 digits, IFSC codes (HDFC0001234 pattern).
- Create TTL index: `db.pan_db.create_index("created_at", expireAfterSeconds=31536000)` (365 days).
- **Acceptance:** Running the script inserts 40 total documents across 4 collections.

## Task 2.4: API Authentication Middleware
- **File:** `backend/auth.py`
- **Function:** `verify_api_key(request: Request) -> None`
- **Logic:**
  1. Read required headers: `X-API-Key`, `X-Device-ID`, `X-Timestamp`, `X-Signature`.
  2. Validate API key matches `API_KEY` from `.env`.
  3. Validate timestamp within 5 minutes (replay protection).
  4. Compute `body_hash = sha256(raw_body_bytes)` (use empty body for GET).
  5. Compute expected signature: `HMAC-SHA256(API_KEY, device_id + timestamp + body_hash)`.
  6. Compare with `X-Signature` using constant-time compare.
  7. Rate limit per device ID:
     - 60 req/min global
     - 10 req/min per endpoint
     - 5 req/sec burst
  8. On failure: return 401/429 with structured error response.
- **Acceptance:** Requests missing any required auth headers return 401. Valid signed request returns 200. Replay (old timestamp) returns 401. Rate limit returns 429 with `Retry-After`.

## Task 2.5: Verification Endpoints
- **File:** `backend/routers/verify.py`
- **Endpoints:**
  - `POST /gov/pan/verify` — Input: `{"pan": "ABCDE1234F"}`. Query `pan_db`. Return `{"status": "ACTIVE", "full_name": "...", "dob": "..."}` or `{"status": "NOT_FOUND"}`.
  - `POST /gov/aadhaar/verify` — Input: `{"aadhaar_last4": "1234"}`. Query `aadhaar_db`. Return name, state, status.
  - `POST /bank/ifsc/verify` — Input: `{"ifsc": "HDFC0001234"}`. Return bank name, branch.
  - `POST /bank/account/verify` — Input: `{"account_hash": "...", "ifsc": "..."}`. Query `bank_accounts_db`.
  - `POST /gov/vehicle/rc/verify` — Input: `{"rc_number": "TN09AB1234"}`. Return validity, vehicle class.
  - `POST /gov/insurance/verify` — Input: `{"policy_number": "..."}`. Return insurer, sum_insured, validity.
  - `POST /gov/itr/verify` — Input: `{"pan": "..."}`. Query `itr_filings_db`. Return filing status, assessment year.
  - `POST /gov/eshram/verify` — Input: `{"uan": "..."}`. Return registration status.
  - `POST /bank/loan/check` — Input: `{"borrower_name": "...", "lender": "..."}`. Query `loan_accounts_db`. Return loan details.
- Each endpoint: log the request, query the corresponding MongoDB collection, return the matched document or `{"status": "NOT_FOUND"}`.
- **Acceptance:** All 9 endpoints respond within 200ms. `NOT_FOUND` returned for non-existent records.

## Task 2.6: LLM Report Generation Endpoint
- **File:** `backend/routers/report.py`
- **Endpoint:** `POST /report/generate`
- **Input Schema:** `ReportRequest` (score, pillars, positive_factors, negative_factors, language)
- **Logic:**
  1. Initialize `genai.configure(api_key=GEMINI_API_KEY)`.
  2. Build prompt:
     ```
     You are GigCredit's financial advisor. Generate a credit report explanation.
     
     RULES:
     - Generate the ENTIRE response in {language}.
     - Do NOT change the credit score or pillar scores.
     - Explain why the score is {score} based on the pillar breakdown.
     - Provide 3-5 actionable suggestions.
     
     DATA:
     Credit Score: {score}/900
     Grade: {grade}
     Pillars: {pillar_scores}
     Strengths: {positive_factors}
     Weaknesses: {negative_factors}
     
     OUTPUT FORMAT (JSON):
     {"explanation": "...", "suggestions": ["...", "..."]}
     ```
  3. Call `model.generate_content(prompt)`.
  4. Parse JSON from response. If parsing fails, return template fallback text.
- **Acceptance:** Returns valid JSON with `explanation` and `suggestions` keys in the requested language.

## Task 2.7: Score Report Storage Endpoint
- **File:** `backend/routers/report.py`
- **Endpoint:** `POST /report/store`
- **Logic:** Accept `ScoreReportRecord`, insert into `score_reports_db` collection with compound index on `(user_id, generated_at)`.
- **Acceptance:** Document is persisted in MongoDB.

## Task 2.8: Deploy to Render
- **File:** `backend/Procfile` or `render.yaml`
- **Logic:** `uvicorn main:app --host 0.0.0.0 --port $PORT`
- **Acceptance:** The API is accessible at `https://<app-name>.onrender.com/docs` and all endpoints work.

---

# PHASE 3: FLUTTER APP — AUTHENTICATION & UI SCAFFOLD (Hour 1–12)
**Goal:** Build the app shell: Firebase Auth, navigation, the 8-step wizard UI, and global state management.

## Task 3.1: App Entry & Routing
- **File:** `lib/main.dart`
- **Logic:**
  1. Initialize `Firebase.initializeApp()`.
  2. Setup `ProviderScope` (Riverpod).
  3. Define `GoRouter` with routes:
     - `/login` → `LoginScreen`
     - `/home` → `HomeScreen`
     - `/guidelines` → `GuidelinesScreen`
     - `/onboarding/:step` → `OnboardingStepScreen(step: int)`
     - `/language-select` → `LanguageSelectScreen`
     - `/report-loading` → `ReportLoadingScreen`
     - `/report` → `FinalReportScreen`
  4. AuthGuard: if `FirebaseAuth.instance.currentUser == null`, redirect to `/login`.
- **Acceptance:** App launches. Unauthenticated users are redirected to `/login`.

## Task 3.2: Phone OTP Authentication
- **File:** `lib/ui/screens/login_screen.dart`
- **Functions:**
  - `_sendOTP(String phoneNumber) -> void`
  - `_verifyOTP(String otp) -> void`
- **Logic:**
  1. UI: GigCredit logo, tagline, phone number input (10 digits, regex `^[6-9]\d{9}$`), "Send OTP" button.
  2. On send: `FirebaseAuth.instance.verifyPhoneNumber(phoneNumber: '+91$phone', ...)`.
  3. Navigate to OTP input. On verify: `PhoneAuthProvider.credential(verificationId, otp)`.
  4. On success: navigate to `/home`. Store session in `FlutterSecureStorage`.
- **Acceptance:** User can login with valid Indian phone number and receive OTP.

## Task 3.3: Home Screen
- **File:** `lib/ui/screens/home_screen.dart`
- **Logic:**
  1. Header: Profile icon (left), Info icon (right).
  2. Hero: "Build Your Financial Trust Score" + "AI-powered verification for gig workers".
  3. 4 feature cards in 2x2 grid: Identity Verification, Bank Analysis, AI Fraud Detection, Credit Scoring.
  4. "Get Started" button → shows popup with "Continue" and "View Input Guidelines".
  5. If returning user with existing score: show last score + trend arrow.
- **Acceptance:** Screen renders without overflow. Both popup buttons navigate correctly.

## Task 3.4: Global State — VerifiedProfile Provider
- **File:** `lib/core/providers/verified_profile_provider.dart`
- **Class:** `VerifiedProfileState` (immutable via `@freezed` or manual copyWith)
- **Fields:**
  ```dart
  String fullName;
  String dob;
  String mobileNumber;
  String currentAddress;
  String permanentAddress;
  String stateOfResidence;
  String workType; // 'platform_worker' | 'vendor' | 'tradesperson' | 'freelancer'
  double selfDeclaredIncome;
  int yearsInProfession;
  int numberOfDependents;
  bool vehicleOwnership;
  // Step 2
  bool aadhaarVerified;
  bool panVerified;
  double faceMatchScore;
  // Step 3
  List<BankTransaction> bankTransactions;
  bool bankVerified;
  // Step 4-8...
  Map<String, bool> stepCompletionStatus; // step1 through step8
  int currentStep;
  ```
- **Provider:** `StateNotifierProvider<VerifiedProfileNotifier, VerifiedProfileState>`
- **Acceptance:** State persists across step navigations. Changing `workType` in Step 1 dynamically reconfigures Step 5.

## Task 3.5: Step 1 — Basic Profile Screen
- **File:** `lib/ui/screens/steps/step1_profile.dart`
- **Logic:**
  1. Section A — Personal Details: Full Name (text), DOB (date picker), Mobile Number (numeric, 10 digits), Current Address (multiline), Permanent Address (multiline), State of Residence (dropdown of 36 states/UTs).
  2. Section B — Professional Details: Work Type (4 illustrated card selector in 2x2 grid), Self-Declared Monthly Income (₹ prefix numeric), Years in Profession (stepper), Dependents (stepper), Vehicle Ownership (radio Yes/No), Secondary Income Source (optional text + ₹ amount).
  3. On "Continue": validate all mandatory fields. Update `VerifiedProfileState`. Navigate to Step 2.
- **Acceptance:** 12 input fields render. Work type selector highlights on tap. Form validation blocks empty mandatory fields.

## Task 3.6: Step 2 — Identity Verification Screen
- **File:** `lib/ui/screens/steps/step2_identity.dart`
- **Logic:**
  1. Aadhaar Section: Aadhaar number input (segmented 4-4-4), Aadhaar Front upload (camera/gallery), Aadhaar Back upload (camera/gallery).
  2. PAN Section: PAN number input (10 chars, regex `[A-Z]{5}[0-9]{4}[A-Z]`), PAN card photo upload.
  3. Selfie Section: Camera-only capture (NO gallery option). Show face guide overlay.
  4. On upload: run AI Authenticity Detection → if EDITED/AI → reject. Run OCR → extract fields. Run Face Verification (selfie vs Aadhaar photo).
  5. Call backend: `POST /gov/pan/verify`, `POST /gov/aadhaar/verify`. Cross-check API name vs OCR name.
- **Acceptance:** Face match threshold ≥ 0.75 passes. Auto-retry for 0.60-0.75 with guidance. < 0.60 rejects.

## Task 3.7: Step 3 — Bank Verification Screen
- **File:** `lib/ui/screens/steps/step3_bank.dart`
- **Logic:**
  1. Primary Bank: Bank Name (searchable dropdown), Account Holder Name, Branch Name, IFSC Code (11 chars), Account Number (9-18 digits), Bank Statement (PDF picker, min 6 months), MICR (optional).
  2. Secondary Bank: Toggle "Add Secondary Account". If enabled, show same 7 fields. Tip: "Platform workers often receive gig income in a separate account."
  3. UPI Statement: Dropdown (PhonePe/GPay/Paytm/BHIM), PDF picker. Optional.
  4. On submit: Parse PDF (see Phase 5). Call `POST /bank/ifsc/verify`. Cross-check account holder vs Aadhaar name.
- **Acceptance:** PDF picker opens. IFSC format validated client-side.

## Task 3.8: Step 4 — Utility Bills Screen
- **File:** `lib/ui/screens/steps/step4_utilities.dart`
- **Logic:**
  1. Electricity Bills: 6-slot upload grid labeled Month 1-6. Each slot accepts JPG/PNG/PDF.
  2. LPG/Gas Bills: Same 6-slot grid.
  3. Mobile Bills: Same 6-slot grid.
  4. Rent (conditional): Show only if addresses indicate renting. 3 radio options: Rental Agreement, Monthly Receipts (6 slots), or Bank Auto-Detection.
  5. Optional WiFi/Broadband, OTT receipts.
  6. OCR each bill: extract consumer number, amount, due date. Cross-check amount against bank statement debits.
- **Acceptance:** 18 mandatory upload slots visible and functional.

## Task 3.9: Step 5 — Dynamic Gig Work Proof Screen
- **File:** `lib/ui/screens/steps/step5_work_proof.dart`
- **Logic:**
  1. Read `workType` from VerifiedProfileState.
  2. If `platform_worker`: Show Layout 5A — Vehicle Reg Number, RC Book (front), DL (front+back), Vehicle Insurance, 3 platform earning screenshots (mandatory) + 2 optional.
  3. If `vendor`: Show Layout 5B — SVANidhi ID + Approval Letter, Municipal Trade Licence, optional Bank No-Due, Vendor Association, Market Allotment, GST cert.
  4. If `tradesperson`: Show Layout 5C — Skill Certificate ID + NSDC cert, Work Order Letter, optional Experience cert + additional NSDC certs + GST.
  5. If `freelancer`: Show Layout 5D — Platform Profile Screenshot (1 mandatory + 1 optional), Client Invoices (1 mandatory + 4 optional), optional Portfolio + GST.
  6. OCR all uploads. Cross-validate names with Aadhaar. Call relevant backend APIs.
- **Acceptance:** Switching workType in Step 1 causes Step 5 to show the correct layout.

## Task 3.10: Step 6 — Government Schemes Screen
- **File:** `lib/ui/screens/steps/step6_schemes.dart`
- **Logic:** 5 expandable scheme cards (all optional). eShram (UAN + card), PM-SYM (Pension account + cert), PMJJBY (insurance cert), PMMY MUDRA (loan account + receipt + no-due cert), PPF (account + passbook). Bank cross-check for contribution debits.
- **Acceptance:** All 5 cards expandable. No schemes selected = valid submit.

## Task 3.11: Step 7 — Insurance Screen
- **File:** `lib/ui/screens/steps/step7_insurance.dart`
- **Logic:** 3 cards: Health Insurance (optional), Vehicle Insurance (mandatory if vehicleOwnership==true, else optional), Life Insurance (optional). OCR extracts policy number, insurer, sum insured, validity.
- **Acceptance:** Vehicle insurance card shows "REQUIRED" badge dynamically.

## Task 3.12: Step 8 — ITR & GST Screen
- **File:** `lib/ui/screens/steps/step8_itr_gst.dart`
- **Logic:** ITR section: ITR Acknowledgement (Form V) + Form 26AS. GST section: GSTIN + up to 6 GSTR-3B returns. GST section expanded by default for Vendor/Freelancer. Call `POST /gov/itr/verify`.
- **Acceptance:** All optional. Empty submission allowed.

---

# PHASE 4: ON-DEVICE AI MODELS (Hour 8–20)
**Goal:** Integrate TFLite models for Face Verification and Fraud Detection, and PaddleOCR for text extraction.

## Task 4.1: EfficientNet-Lite0 Document Authenticity Detector
- **File:** `lib/ai/authenticity_detector.dart`
- **Class:** `AuthenticityDetector`
- **Functions:**
  - `Future<void> loadModel()` — Load `assets/models/efficientnet_lite0.tflite` via `Interpreter.fromAsset()`.
  - `Future<AuthResult> detectAuthenticity(Uint8List imageBytes)` — Preprocess (resize to 224x224, normalize [0,1]), run inference, return enum `{REAL, AI_GENERATED, EDITED}`.
- **Logic:** 3-class classifier. If output != REAL → reject document, show "This document appears to be modified. Please upload an original."
- **Acceptance:** Loads in < 500ms. Returns classification for any image input.

## Task 4.2: MobileFaceNet Face Verification
- **File:** `lib/ai/face_verifier.dart`
- **Class:** `FaceVerifier`
- **Functions:**
  - `Future<void> loadModel()` — Load `assets/models/mobilefacenet.tflite`.
  - `Future<List<double>> getEmbedding(Uint8List faceImage)` — Crop face region, resize 112x112, normalize, run inference. Returns 128-dim embedding vector.
  - `double cosineSimilarity(List<double> a, List<double> b)` — Standard cosine sim formula.
  - `Future<FaceMatchResult> verifyFace(Uint8List aadhaarPhoto, Uint8List selfie)` — Get both embeddings, compute similarity. Return `{PASS (>=0.75), RETRY (0.60-0.75), REJECT (<0.60)}`.
- **Logic for RETRY:** Show guidance: "Please retake selfie with better lighting." Max 2 retries. If all retries 0.60-0.75: Accept with `face_match_confidence = 0.65`.
- **Acceptance:** Matching faces score > 0.80. Different faces score < 0.50.

## Task 4.3: PaddleOCR Native Integration
- **File:** `lib/ai/ocr_engine.dart`
- **Class:** `OCREngine`
- **Functions:**
  - `Future<void> initialize()` — Load PaddleOCR Lite models (det, rec, cls).
  - `Future<String> extractText(Uint8List imageBytes)` — Full OCR pipeline: detection → classification → recognition. Returns raw text string.
  - `Future<Map<String, String>> extractFields(String rawText, DocumentType type)` — Apply regex parsers based on document type.
- **Document-specific regex parsers (in `lib/ai/field_extractors.dart`):**
  - `extractPanFields(String text)` → `{"pan": match [A-Z]{5}[0-9]{4}[A-Z], "name": ..., "dob": ...}`
  - `extractAadhaarFields(String text)` → `{"aadhaar": match \d{4}\s\d{4}\s\d{4}, "name": ..., "address": ...}`
  - `extractBankStatementFields(String text)` → `{"bank_name": ..., "account_holder": ..., "ifsc": match ^[A-Z]{4}0[A-Z0-9]{6}$, "transactions": [...]}`
  - `extractUtilityFields(String text)` → `{"consumer_number": ..., "amount": ..., "due_date": ...}`
- **Acceptance:** OCR returns text from a clear document photo. Regex extracts PAN number correctly from a test image.

## Task 4.4: Document Processing Pipeline Orchestrator
- **File:** `lib/ai/document_processor.dart`
- **Class:** `DocumentProcessor`
- **Function:** `Future<ProcessedDocument> processDocument(Uint8List imageBytes, DocumentType type)`
- **Logic (exact pipeline order):**
  1. If PDF → convert pages to images (use `syncfusion_flutter_pdf`).
  2. Run `AuthenticityDetector.detectAuthenticity(image)`. If != REAL → throw `DocumentRejectedError`.
  3. Run `OCREngine.extractText(image)`.
  4. Run `OCREngine.extractFields(rawText, type)`.
  5. Return `ProcessedDocument(rawText, extractedFields, authenticityScore)`.
- **Acceptance:** Full pipeline completes in < 3 seconds on a mid-range Android device.

---

# PHASE 5: FEATURE ENGINEERING & BANK PARSING (Hour 16–30)
**Goal:** Parse bank statement CSVs into structured transactions, then compute the 95 ML features.

## Task 5.1: Bank Statement PDF Parser
- **File:** `lib/core/bank_parser.dart`
- **Class:** `BankStatementParser`
- **Functions:**
  - `Future<List<BankTransaction>> parsePDF(File pdfFile)` — Extract text (try direct text first; if < 100 chars, OCR each page). Parse transaction rows.
  - `List<BankTransaction> parseTransactionTable(String text)` — Regex to identify date+description+amount+balance rows. Return list of `BankTransaction` objects.
  - `List<BankTransaction> mergeAndDeduplicate(List<BankTransaction> primary, List<BankTransaction> secondary)` — Merge two bank accounts. Dedup: same date ±1 day AND same amount ±₹5.
- **BankTransaction model:** `{DateTime date, String description, double amount, TransactionType type, double balance}`
- **Password-protected PDFs:** Show dialog: "Password is often your date of birth (DDMMYYYY) or PAN." Max 3 attempts.
- **Acceptance:** Parses a standard Indian bank statement PDF into a list of transaction objects.

## Task 5.2: Transaction Tagging Engine
- **File:** `lib/core/transaction_tagger.dart`
- **Class:** `TransactionTagger`
- **Function:** `TransactionTag tagTransaction(BankTransaction txn)`
- **Tags enum:** `GIG_INCOME, SALARY, EMI_DEBIT, UTILITY_PAYMENT, SAVINGS, P2P_TRANSFER, CASH_WITHDRAWAL, BANK_CHARGES, RENT, UNCATEGORIZED`
- **Logic (4 layers, applied in order):**
  1. **Layer 1 — Regex Keywords:**
     - GIG_INCOME: `["SWIGGY", "ZOMATO", "OLA", "UBER", "RAPIDO", "DUNZO", "PORTER", "URBAN COMPANY", "BLINKIT", "ZEPTO", "BIGBASKET", "MEESHO", "UPWORK", "FIVERR", "FREELANCER"]`
     - EMI_DEBIT: `["EMI", "LOAN EMI", "NACH EMI", "FINANCE", "BAJAJ", "CARD EMI", "BNPL"]`
     - UTILITY_PAYMENT: `["TNEB", "BESCOM", "MSEDCL", "BSES", "TATA POWER", "AIRTEL", "JIO", "VI ", "BSNL", "WATER BOARD", "GAS"]`
  2. **Layer 2 — Pattern Matching:** UPI format `UPI/P2P/{sender}/{receiver}/{id}`, NACH always = EMI or SUBSCRIPTION.
  3. **Layer 3 — Amount Heuristics:** Credits ₹200-2000 with frequency >10/month → GIG_INCOME. Identical debit monthly → EMI. Debits ₹1-100 → BANK_CHARGES.
  4. **Layer 4 — Fallback:** Everything else → UNCATEGORIZED (still counts for totals).
- **Acceptance:** Test with sample Indian bank statement descriptions. >80% accuracy on clearly tagged transactions.

## Task 5.3: Feature Engineering (95 Features)
- **File:** `lib/core/feature_engineering.dart`
- **Class:** `FeatureEngineer`
- **Function:** `List<double> engineerFeatures(VerifiedProfileState profile) -> List<double>`
- **Logic:** Returns a `List<double>` of exactly 95 values, each normalized to [0.0, 1.0].
- **Feature index mapping (MUST match offline training/export exactly):**
  ```
  P1 Income Stability [0-12] — 13 features:
    0: avg_monthly_income_norm = avg_monthly_credits / (state_anchor * 3), clamp [0,1]
    1: income_stability_cv = 1 - min(std_dev(monthly_credits) / mean(monthly_credits), 1.0)
    2: income_growth_slope = linear_regression_slope(monthly_credits) normalized
    3: income_source_diversity = unique_credit_sources / 10, clamp [0,1]
    4: gig_income_ratio = sum(GIG_INCOME credits) / total_credits
    5: salary_income_ratio = sum(SALARY credits) / total_credits
    6: peak_income_ratio = max_monthly_credit / avg_monthly_credit, normalized
    7: income_trend_score = (last_3mo_avg - first_3mo_avg) / first_3mo_avg, normalized
    8: zero_income_months = count(months with zero credits) / 6
    9: platform_earning_match = 1.0 if platform screenshot earnings ≈ bank credits (±30%), else 0.5
    10: secondary_income_ratio = secondary_income / total_income
    11: work_tenure_norm = years_in_profession / 20, clamp [0,1]
    12: declared_vs_actual_ratio = self_declared_income / avg_monthly_bank_income, clamp [0,1]

  P2 Payment Discipline [13-27] — 15 features:
    13: utility_ontime_ratio = bills_paid_before_due / total_bills
    14: utility_payment_consistency = months_with_payment / 6
    15: electricity_regularity = electricity_payments_found / 6
    16: gas_regularity = gas_payments_found / 6
    17: mobile_regularity = mobile_payments_found / 6
    18: rent_regularity = rent_payments_found / 6 (0 if not applicable)
    19: utility_bank_match_ratio = bills_confirmed_in_bank / total_bills_uploaded
    20: avg_days_before_due = average(due_date - payment_date), normalized
    21: late_payment_count_norm = 1 - (late_payments / total_payments)
    22: consistent_amount_ratio = bills_with_similar_amounts / total_bills
    23: provider_consistency_score = same_provider_across_months / 6
    24: emi_ontime_ratio = emi_paid_on_schedule / total_emi_payments
    25: nach_mandate_count_norm = nach_transactions / 10, clamp [0,1]
    26: bounced_payment_score = 1 - (bounced_count / total_payments)
    27: debit_regularity_score = std_dev(monthly_debit_count) normalized inversely

  P3 Debt Management [28-36] — 9 features:
    28: emi_to_income_ratio = total_monthly_emi / avg_monthly_income
    29: active_loan_count_norm = active_loans / 5, clamp [0,1]
    30: debt_band_score = based on emi_to_income bands (0=no risk, 1=critical)
    31: emi_consistency_score = std_dev(emi_amounts) / mean(emi_amounts), inverted
    32: no_cost_emi_ratio = no_cost_emi_count / total_emi_count
    33: loan_closure_bonus = 1.0 if any loan closed in last 6 months, else 0.0
    34: emi_growth_trend = (recent_emi - older_emi) / older_emi, inverted normalized
    35: max_single_emi_ratio = largest_single_emi / avg_monthly_income
    36: total_debt_exposure_norm = total_outstanding / (annual_income * 3)

  P4 Savings Behaviour [37-48] — 12 features:
    37: savings_ratio = (total_credits - total_debits) / total_credits
    38: balance_growth_slope = regression slope of end-of-month balances
    39: min_balance_ratio = min_monthly_balance / avg_monthly_balance
    40: balance_stability_cv = 1 - cv(monthly_end_balances)
    41: savings_transaction_ratio = savings-tagged credits / total_credits
    42: ppf_contribution_norm = annual_ppf_deposit / 150000 (PPF max)
    43: fd_rd_indicator = 1.0 if FD/RD transactions found, else 0.0
    44: avg_balance_norm = avg_daily_balance / (state_anchor * 6)
    45: emergency_fund_months = min_balance / avg_monthly_expenses
    46: spending_discipline = 1 - (discretionary_spend / total_spend)
    47: cash_withdrawal_ratio = total_ATM_withdrawals / total_debits (lower = better)
    48: balance_dip_frequency = months_with_balance_below_1000 / 6, inverted

  P5 Work & Identity [49-66] — 18 features (SCORECARD, not ML):
    49-66: aadhaar_verified, pan_verified, face_match_score, kyc_completeness,
           name_consistency_score, address_match_score, work_type_encoded (4 one-hot),
           profession_tenure_norm, age_suitability_score, platform_tenure_norm,
           platform_rating_norm, dl_valid, rc_active, nsdc_certified, nsqf_level_norm,
           gst_registered, trade_licence_valid

  P6 Financial Resilience [67-77] — 11 features:
    67: health_insurance_active (binary)
    68: vehicle_insurance_active (binary, weighted by vehicle_ownership)
    69: life_insurance_active (binary)
    70: insurance_composite_score = weighted sum of above
    71: sum_insured_to_income_ratio = total_sum_insured / annual_income
    72: insurance_premium_regularity = premium_payments_found / expected
    73: emergency_fund_adequacy = min_balance / (3 * monthly_expenses)
    74: income_diversification = number_of_income_sources / 4
    75: asset_ownership_score = (vehicle + property indicators) normalized
    76: itr_filed_binary = 1 if ITR filed, 0 otherwise
    77: declared_income_ratio = itr_annual_income / (bank_annual_credits)

  P7 Social Accountability [78-87] — 10 features (SCORECARD):
    78-87: eshram_active, pmsym_active, pmjjby_active, mudra_completed, ppf_active,
           scheme_count_norm, scheme_contribution_consistency, gst_registered_binary,
           gst_filing_consistency, community_engagement_score

  P8 Tax Compliance [88-94] — 7 features (SCORECARD):
    88-94: itr_filed_binary, itr_years_filed_norm, declared_income_accuracy,
           tds_present, form26as_match, gst_turnover_ratio, tax_compliance_composite
  ```
- **NaN Handling:** If ANY computed feature is NaN or Infinity → replace with 0.50 (neutral). Log warning.
- **Acceptance:** Returns exactly 95 doubles. No NaN. All values in [0.0, 1.0].

## Task 5.4: Confidence Engine
- **File:** `lib/core/confidence_engine.dart`
- **Class:** `ConfidenceEngine`
- **Function:** `Map<String, double> computeConfidence(VerifiedProfileState profile)`
- **Logic:** For each pillar, compute confidence [0.0 - 1.0] based on data completeness:
  - P1: Has bank statement (0.4) + has platform earnings (0.2) + ITR filed (0.2) + months of data >= 6 (0.2)
  - P2: Has utility bills (0.5) + has EMI records (0.3) + bank transaction count > 100 (0.2)
  - P3: Has bank statement (0.5) + has loan verification (0.3) + has ITR (0.2)
  - P4: Has bank statement (0.6) + has PPF/FD records (0.2) + months > 6 (0.2)
  - P5: Aadhaar verified (0.3) + PAN verified (0.3) + face match (0.2) + work docs (0.2)
  - P6: Has insurance docs (0.4) + has ITR (0.3) + has bank 6+ months (0.3)
  - P7: Each verified scheme adds 0.20 (capped at 1.0)
  - P8: ITR filed (0.5) + GST registered (0.3) + Form 26AS (0.2)
- **Minimum data check:** Steps 1, 2, 3 MUST be completed with ≥30 transactions. If not → refuse to score.
- **Floor rule:** If confidence < 0.30 → set pillar score to 0.50 neutral, show "Not enough data".
- **Acceptance:** Returns 8 confidence values. All between 0.0 and 1.0.

---

# PHASE 6: SCORING ENGINE & FINAL REPORT (Hour 24–40)
**Goal:** Execute the full scoring pipeline on-device and render the final report.

## Task 6.1: Scoring Engine Orchestrator
- **File:** `lib/scoring/scoring_engine.dart`
- **Class:** `ScoringEngine`
- **Function:** `ScoreReport computeScore(VerifiedProfileState profile)`
- **Logic (exact 18-step pipeline):**
  ```dart
  1. List<double> features = FeatureEngineer.engineerFeatures(profile);    // 95 features
  2. features = FeatureSanitizer.sanitize(features);                       // NaN → 0.50, clamp [0,1]
  3. double p1Raw = score_p1(features.sublist(0, 13));                     // m2cgen XGBoost
  4. double p2Raw = score_p2(features.sublist(13, 28));                    // m2cgen XGBoost
  5. double p3Raw = score_p3(features.sublist(28, 37));                    // m2cgen XGBoost
  6. double p4Raw = score_p4(features.sublist(37, 49));                    // m2cgen XGBoost
  7. double p5Raw = ScorecardP5.compute(features.sublist(49, 67));         // Dart scorecard
  8. double p6Raw = score_p6(features.sublist(67, 78));                    // m2cgen RandomForest
  9. double p7Raw = ScorecardP7.compute(features.sublist(78, 88));         // Dart scorecard
  10. double p8Raw = ScorecardP8.compute(features.sublist(88, 95));        // Dart scorecard
  11. var validated = PillarValidator.validateAll([p1Raw..p8Raw]);          // Clamp + NaN guard
  12. validated[2] = DebtBandCap.apply(validated[2], features[28]);        // If EMI ratio > 0.80, cap P3 at 0.30
  13. var confidences = ConfidenceEngine.computeConfidence(profile);
  14. var adjusted = ConfidenceEngine.applyAll(validated, confidences);     // adjusted = raw * conf + 0.50 * (1-conf)
  15. int finalScore = MetaLearner.compute(adjusted, profile.workType);    // LR dot product → sigmoid → 300-900
  16. String grade = GradeAssigner.assign(finalScore);                     // S/A/B/C/D/E
  17. String riskBand = RiskBandAssigner.assign(finalScore);               // Low/Medium/High
  18. var shapInsights = SHAPEngine.computeInsights(features);             // Binned lookup
  ```
- **Return:** `ScoreReport(finalScore, grade, riskBand, adjustedPillarScores, confidences, shapInsights, topPositive, topNegative)`
- **Acceptance:** Execution completes in < 20ms. Score always between 300 and 900. No NaN in output.

## Task 6.2: Meta-Learner (Dart)
- **File:** `lib/scoring/meta_learner.dart`
- **Function:** `int compute(List<double> pillarScores, String workType)`
- **Logic:**
  ```dart
  int workTypeIndex = {'platform_worker': 0, 'vendor': 1, 'tradesperson': 2, 'freelancer': 3}[workType]!;
  List<double> workTypeOH = [0, 0, 0, 0]; workTypeOH[workTypeIndex] = 1.0;
  List<double> metaInput = [
    ...pillarScores,                                                      // 8
    ...workTypeOH,                                                        // 4
    pillarScores[0]*workTypeOH[0], pillarScores[0]*workTypeOH[1],        // P1 interactions
    pillarScores[0]*workTypeOH[2], pillarScores[0]*workTypeOH[3],
    pillarScores[1]*workTypeOH[0], pillarScores[1]*workTypeOH[1],        // P2 interactions
    pillarScores[1]*workTypeOH[2], pillarScores[1]*workTypeOH[3],
  ];  // 20 total
  double logit = metaIntercept;
  for (int i = 0; i < 20; i++) logit += metaInput[i] * metaCoefficients[i];
  double probability = 1.0 / (1.0 + exp(-logit));
  return (probability * 600 + 300).round();
  ```
- **Acceptance:** Output always 300-900.

## Task 6.3: SHAP Explainability Engine
- **File:** `lib/scoring/shap_engine.dart`
- **Function:** `SHAPInsights computeInsights(List<double> features)`
- **Logic:** Load `shap_lookup.json`. For each feature, find its bin, return the precomputed SHAP value. Sort by absolute impact. Return top 3 positive factors (strengths) and top 3 negative factors (areas for improvement).

## Task 6.4: Language Selection Screen
- **File:** `lib/ui/screens/language_select_screen.dart`
- **Logic:** 5 selectable cards: English, Hindi, Tamil, Telugu, Kannada. "Generate Report" button.
- **Acceptance:** Selected language is stored and passed to backend.

## Task 6.5: Report Loading Screen
- **File:** `lib/ui/screens/report_loading_screen.dart`
- **Logic:** Show "Generating Your Credit Report..." with AI-themed animation. Call backend: `POST /report/generate` with the ScoreReport payload. Wait for Gemini response (2-5 seconds). Navigate to final report.

## Task 6.6: Final Report Screen
- **File:** `lib/ui/screens/final_report_screen.dart`
- **Logic:**
  1. Section 1: Large circular gauge showing score (e.g., "682 / 900"). Grade badge (B). Risk band (Low/Medium/High).
  2. Section 2: 8 horizontal progress bars for each pillar. Color: Green ≥70%, Amber 40-69%, Red <40%. Show "Not enough data" for confidence <0.30.
  3. Section 3: LLM-generated explanation text (from Gemini response).
  4. Section 4: Personalized suggestions (from Gemini response).
  5. "Download PDF" button → generate on-device PDF.
- **Acceptance:** All 8 pillars visible. Score gauge renders. PDF downloads.

## Task 6.7: PDF Report Generator
- **File:** `lib/core/pdf_generator.dart`
- **Function:** `Future<File> generatePDF(ScoreReport report, String llmText)`
- **Logic:**
  - Page 1: GigCredit logo + date, circular score gauge, grade badge, risk band.
  - Page 2: 8 pillar horizontal bars, top 3 strengths, top 3 weaknesses.
  - Page 3: LLM explanation + suggestions.
  - Footer: "Generated on [date] | GigCredit v1.0 | Score valid for 90 days"
  - Use `pdf` package with `pw.Document()`. Save to app documents directory. Share via `share_plus`.
- **Acceptance:** PDF is 3 pages. Opens correctly in any PDF reader.

## Task 6.8: Store Score Report to Backend
- **Logic:** After PDF generation, POST the `ScoreReport` to `POST /report/store` on the backend. Also save locally to `score_history/` for trend tracking.

---

# PHASE 7: INTEGRATION, TESTING & POLISH (Hour 36–48)
**Goal:** Connect all pipelines end-to-end and test.

## Task 7.1: Golden Profile Test
- **File:** `test/golden_profile_test.dart`
- **Logic:** Define a complete mock VerifiedProfile with ALL 95 features predefined. Run `ScoringEngine.computeScore()`. Assert the output is a specific score (e.g., 682). This test MUST produce the identical result every time.
- **Acceptance:** Test passes on every build.

## Task 7.2: End-to-End Integration Test
- Run the app on emulator. Complete all 8 steps with test data. Verify the score is generated. Verify PDF downloads. Verify backend receives the score report.

## Task 7.3: Session Recovery
- **Logic:** After each step completion, save `VerifiedProfileState` to `FlutterSecureStorage`. On app restart, check for existing session. If found (< 24 hours old), resume from last step. If > 24h, clear and restart.

## Task 7.4: Error Handling & Cleanup
- After report generation, delete: uploaded images, OCR text, bank CSVs, feature vectors.
- Keep: encrypted verified_profile (24h expiry), step_progress.json, score_history.

## Task 7.5: UI Polish
- Smooth transitions, loading animations, proper error messages, gradient buttons, consistent card design across all screens.

# DEV A INTEGRATION & ENDPOINTS GUIDE (FOR DEV B HANDOFF)

**Purpose:** This guide shows exactly what Dev A needs to provide to finish the integration with Dev B's Flutter App layout, API calls, and local inference hooks. 

---

## 1. ⚙️ AI Native Interface Integration (On-Device Models)

Dev B has wired the UI screens to standard interfaces in `gigcredit_app/lib/ai/ai_interfaces.dart`. Dev A must implement the native iOS/Android bridge in `NativeAiBridge` (`lib/ai/ai_native_bridge.dart`):

| Dev B Contract Interface | Dev B Calls this during | Dev A's Native Model Needs to Deliver |
|---|---|---|
| `OcrEngine.extractText()` | Step 2 (Aadhaar), Step 3 (Bank) | Key-value string map of extracted values. |
| `FaceVerifier.compareFaces()` | Step 2 (Selfie vs Aadhaar Image) | Match Score (float 0.0 - 1.0) via native FaceNet. |
| `AuthenticityDetector.isGenuine()` | Step 5 (Work Proof/Bills) | Confidence Score (0.0 - 1.0) via Anti-Spoofing. |

**Dev A Task:** 
Replace standard `return Future.value({...})` stubs inside `gigcredit_app/lib/ai/native_document_processor.dart` and bind to your `MethodChannel('com.gigcredit.ai/native')`.

---

## 2. 🔌 Backend API Endpoints (Verification Contracts)

Dev B's `BackendClient` (`lib/services/backend_client.dart`) expects standard REST behaviors. Dev A must deploy these endpoints:

| Request Flow | Dev B Client Expects Endpoint (`POST`) | Expected JSON Response Contract |
|---|---|---|
| Verify Aadhaar/Pan | `/verify/kyc` (Multi-part File upload) | `{"status": "SUCCESS", "extractedPan": "...", "confidence": 0.95}` |
| Verify Bank IFSC | `/verify/bank/ifsc` | `{"status": "SUCCESS", "isValid": true}` |
| Parse Emis/Income | `/verify/bank/statement` | `{"transactions": [...], "emiDetected": true}` |
| Verify Utilities | `/verify/utility` | `{"status": "SUCCESS", "verifiedAmount": 500}` |
| Verify Gov Schemes | `/verify/scheme/svanidhi` | `{"status": "SUCCESS", "isValid": true}` |
| Insurance Policy | `/verify/insurance` | `{"status": "SUCCESS", "policyActive": true}` |
| GST / ITR Validation | `/verify/tax/itr` | `{"status": "SUCCESS", "annualIncome": 550000}` |

**Dev A Task:**
Set the `GIGCREDIT_API_BASE_URL` in root `.env`.

---

## 3. 🧠 Scoring Model Integration (Offline ML)

Dev B's `ScoringPipeline` reads 95 elements from the `VerifiedProfile` state.

**Dev A Task:**
1. Drop the `p1_scorer.dart` to `p6_scorer.dart` output from `m2cgen` into `gigcredit_app/lib/scoring/generated/` folder.
2. Maintain the signature exactly: `double scoreP1(List<double> features)`
3. Ensure the Meta-Learner weights are injected into `assets/constants/meta_coefficients.json`.
4. Ensure the SHAP lookup bins are injected into `assets/constants/shap_lookup.json`.

---

## 4. 🚀 Release Ready Check

To test production mode and disable Dev B mock interfaces, you must toggle the environment variables before building the final apk:

```shell
flutter build apk --dart-define=GIGCREDIT_REQUIRE_PRODUCTION_READINESS=true
```

Dev A must ensure that the `StartupSelfCheckGate` resolves all underlying permissions before production rollout, or the app will immediately crash with a security lock.

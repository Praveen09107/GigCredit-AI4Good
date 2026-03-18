<!-- markdownlint-disable -->

## Dev A — Full Execution Plan (Backend + Offline ML + Native AI)

**Role summary**:  
Dev A owns **all server-side logic**, the **entire offline ML pipeline**, and the **native on-device AI integrations** (OCR, fraud, face) exposed via clean Dart interfaces. Dev A never edits Flutter UI or scoring logic; Dev A focuses on **APIs, models, and native AI building blocks** that Dev B can call.

Authoritative references:

- `planning/4_IMPLEMENTATION_PLAN_20_PHASES.md`
- `planning/2_GIGCREDIT_TEAM_WORK_SPLIT.md`
- `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`
- `planning/3_END_TO_END_WORKFLOW_FREEZE.md`
- `planning/2_BACKEND_HARDENING_SPEC.md`

---

## 1. Ownership and boundaries

Dev A **owns** and is the primary implementer of:

- `backend/` (all files)
- `offline_ml/` (all files)
- `gigcredit_app/lib/ai/` (all files)
- `gigcredit_app/lib/services/backend_client.dart`

Dev A **must not edit**:

- `gigcredit_app/lib/ui/**`
- `gigcredit_app/lib/core/**`
- `gigcredit_app/lib/scoring/**` (except regenerating `generated/*.dart`)
- `gigcredit_app/lib/models/**` (Dev B defines domain models)
- `planning/**` (read-only, unless team decides to change spec)

Integration surfaces Dev A provides:

1. **Backend HTTP API** (to be called by `BackendClient`):
   - `/verify/*` endpoints
   - `/report/generate`, optional `/report/store`
2. **ML artifacts**:
   - `gigcredit_app/lib/scoring/generated/p1_scorer.dart ... p6_scorer.dart`
   - `gigcredit_app/assets/constants/shap_lookup.json`
   - `gigcredit_app/assets/constants/meta_coefficients.json`
3. **AI interfaces** (Dart):
   - `OcrEngine`
   - `AuthenticityDetector`
   - `FaceVerifier`
   - `DocumentProcessor` (high-level orchestration)

---

## 2. High-level implementation sequence for Dev A

The sequence below is ordered for **max parallelism** and **early unblock** of Dev B.

1. **Backend skeleton running locally** (Hour 0–2)
2. **Backend auth + basic verify endpoints** (Hour 2–6)
3. **Deploy backend to Render** (Hour 4–8)
4. **Complete all `/verify/*` and `/report/generate` logic** (Hour 6–12)
5. **Offline ML: data generator + pipeline skeleton** (Hour 0–6, parallel)
6. **Offline ML: tune + train pillar models + SHAP + meta-learner** (Hour 6–18)
7. **Offline ML: m2cgen export to Dart + validation** (Hour 18–24)
8. **Native AI: PaddleOCR, EfficientNet, MobileFaceNet, DocumentProcessor** (Hour 6–20, parallel with ML)
9. **Polish + logging + rate limiting + seed scripts** (Hour 24–36)
10. **Support integration tests and debugging with Dev B** (Hour 36–48)

The exact hours are approximate and based on `4_IMPLEMENTATION_PLAN_20_PHASES.md`.

---

## 3. Backend — detailed implementation pipeline

### 3.1 Make backend skeleton run (Hour 0–2)

**Files**

- `backend/app/main.py`
- `backend/app/config.py`
- `backend/app/database.py`
- `backend/scripts/run_dev.py`
- `backend/requirements.txt`

**Steps**

1. **Install dependencies**:

   ```bash
   pip install -r backend/requirements.txt
   ```

2. **Wire routers into `main.py`**:

   - Import and include `routers.verify.router` and `routers.report.router`.

   Pseudocode:

   ```python
   from fastapi import FastAPI

   from .routers import verify, report

   app = FastAPI(title="GigCredit Backend")

   app.include_router(verify.router)
   app.include_router(report.router)
   ```

3. **Run locally**:

   ```bash
   python backend/scripts/run_dev.py
   ```

4. **Verify**:

   - `GET http://localhost:8000/` returns `{"status": "GigCredit API Running"}`.

---

### 3.2 Implement auth skeleton (Hour 2–3)

**Files**

- `backend/app/auth.py`
- `backend/app/utils/security.py`
- `backend/app/services/rate_limiter.py`

**Goal**: prepare the dependency wiring; full rules can be filled later.

**Steps**

1. Implement HMAC computation based on:
   - `X-API-Key`
   - `X-Device-ID`
   - `X-Timestamp` (ms)
   - `body_hash = sha256(raw_body_bytes)`
   - `message = device_id + timestamp + body_hash`

2. Implement a dependency function:

   ```python
   async def verify_api_key(request: Request) -> None:
       # parse headers
       # validate API key
       # validate timestamp window
       # recompute HMAC and compare
       # call rate_limiter.check_rate_limit(device_id, path)
   ```

3. Attach dependency to routers (already stubbed in `verify.py`, `report.py`).

---

### 3.3 Implement `/verify/*` endpoints (Hour 3–8)

**Files**

- `backend/app/routers/verify.py`
- `backend/app/models/api.py`
- `backend/app/models/records.py`
- `backend/app/services/gov_service.py`
- `backend/app/database.py`

**Verify API pattern**

Each verify endpoint should:

1. Accept `VerifyRequest` (identifier + optional extra data).
2. Look up a collection in Mongo (simulation).
3. Return `ApiResponse`:
   - `status = "FOUND" | "NOT_FOUND" | "INVALID" | "ERROR"`
   - `data` minimal record if `FOUND`
   - `error` message for `INVALID` / `ERROR`.

**Example: PAN verify**

Pseudocode for `routers/verify.py`:

```python
@router.post("/pan", response_model=ApiResponse, dependencies=[Depends(verify_api_key)])
async def verify_pan(payload: VerifyRequest) -> ApiResponse:
    return await gov_service.verify_pan(payload)
```

In `services/gov_service.py`:

```python
from motor.motor_asyncio import AsyncIOMotorDatabase
from ..database import get_database

async def verify_pan(payload: VerifyRequest) -> ApiResponse:
    db: AsyncIOMotorDatabase = get_database()
    record = await db["pan_records"].find_one({"pan": payload.identifier})
    if record is None:
        return ApiResponse(status="NOT_FOUND", data=None, error=None)
    return ApiResponse(status="FOUND", data={"pan": record["pan"]}, error=None)
```

Repeat this pattern for:

- `/verify/aadhaar`
- `/verify/bank/ifsc`
- `/verify/bank/account`
- `/verify/vehicle/rc`
- `/verify/insurance`
- `/verify/income-tax/itr`
- `/verify/eshram`
- `/verify/loan`

**Seed script**

- Use `backend/scripts/seed_db.py` to insert a few sample documents into each collection, matching the `Input_fields_final` spec.

---

### 3.4 Implement `/report/generate` (Hour 6–12)

**Files**

- `backend/app/routers/report.py`
- `backend/app/services/llm_service.py`
- `backend/app/models/api.py`

**Behavior**

- Input: `ReportRequest` with:
  - `language` (e.g. `"en"`, `"hi"`, `"ta"`)
  - `score` (final LR score)
  - `pillars` (map pillar_id → subscore)
  - `shap_factors` (top +/- factors)
- Output: `ApiResponse` with:
  - `status = "OK" | "ERROR"`
  - `data = {"explanation": str, "suggestions": [str, ...]}`
  - `error` if LLM fails

**Implementation outline**

1. Create Gemini client using `settings.gemini_api_key`.
2. Build prompt exactly per `MASTER PROMPT — MODEL OUTPUT TO EXPLAINABLE MULTILINGUAL CREDIT REPORT PIPELINE.txt` (after your edits).
3. Ensure:
   - Output is **strict JSON**.
   - Model is told **not** to change the score or pillars.
4. Parse JSON; on parse failure, fall back to a default explanation/suggestions and set `status="ERROR"` but keep `data` usable.

---

### 3.5 Deploy to Render (Hour 4–8)

Dev A should:

- Create a Render service pointing to `backend/` with `uvicorn app.main:app`.
- Configure environment:
  - `MONGO_URI` (can be a cloud Mongo or local-in-Render)
  - `API_KEY`
  - `GEMINI_API_KEY`
- Share with Dev B:
  - Base URL (e.g. `https://gigcredit-backend.onrender.com`)
  - All required headers for `BackendClient`.

---

## 4. Offline ML — detailed implementation pipeline

### 4.1 Data generator (Hour 0–4)

**File**

- `offline_ml/src/data_generator.py`

**Goal**: generate `data/synthetic_profiles.csv` with:

- 15,000 rows
- 95 features (as per `Feature engineering (1).txt`)
- target labels for each pillar + overall.

Pseudocode:

```python
def main():
    rng = np.random.default_rng(seed=42)
    n = 15000
    X = np.zeros((n, 95))
    # fill X with distributions per spec
    # y_p1, y_p2, ..., y_overall based on synthetic rules
    df = pd.DataFrame(...)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    df.to_csv(DATA_DIR / "synthetic_profiles.csv", index=False)
```

---

### 4.2 Tuning (Hour 4–8)

**File**

- `offline_ml/src/tune_models.py`

**Goal**: use Optuna to find good hyperparams with constraints:

- `tree_method='exact'`
- `max_depth <= 4`
- `n_estimators <= 150`

**Steps**

1. Load `synthetic_profiles.csv`.
2. Split into train/validation.
3. For each pillar P1/P2/P3/P4:
   - Define Optuna objective.
   - Save best hyperparams into `data/best_params.json`.

---

### 4.3 Final training (Hour 8–14)

**File**

- `offline_ml/src/train_final.py`

**Goal**: train final models per pillar and save them.

**Steps**

1. Load `synthetic_profiles.csv` and `best_params.json`.
2. Train:
   - P1–P4 → XGBoost
   - P6 → RandomForest (or XGBoost, per freeze spec)
3. Save models with `joblib` or `pickle` to `data/`.
4. Save training metrics into `data/training_report.json`.

---

### 4.4 SHAP extraction (Hour 14–18)

**File**

- `offline_ml/src/extract_shap.py`

**Goal**: compute TreeSHAP for each pillar model and bin them for on-device lookup.

**Steps**

1. Load trained models.
2. For each pillar:
   - Use `shap.TreeExplainer`.
   - Sample subset of rows.
   - Compute SHAP values.
   - Bin them by feature and quantile → produce compact table.
3. Save `data/shap_lookup.json` with structure:

```json
{
  "P1": {
    "feature_0": {"bins": [...], "values": [...]},
    ...
  },
  "P2": {...}
}
```

---

### 4.5 Meta-learner (Hour 16–20)

**File**

- `offline_ml/src/train_meta_learner.py`

**Goal**: train Logistic Regression meta-learner on pillar outputs + interactions.

**Steps**

1. Use trained models to generate pillar scores for all synthetic rows.
2. Build meta-feature matrix:
   - P1–P8
   - Interaction terms as per spec.
3. Train LR with regularization.
4. Save coefficients, intercept, and any scaling parameters into `data/meta_coefficients.json`.

---

### 4.6 Export to Dart via m2cgen (Hour 18–24)

**File**

- `offline_ml/src/export_to_dart.py`

**Goal**: generate:

- `gigcredit_app/lib/scoring/generated/p1_scorer.dart ... p6_scorer.dart`

**Constraints**

- Use m2cgen with:
  - `sys.setrecursionlimit(50000)` before export.
  - `tree_method='exact'` (in training).
  - `n_estimators <= 150`, `max_depth <= 4` to keep Dart files manageable.

**Pseudocode**

```python
import m2cgen as m2c
import sys
from pathlib import Path

sys.setrecursionlimit(50000)

OUT_DIR = Path("..") / ".." / "gigcredit_app" / "lib" / "scoring" / "generated"
OUT_DIR.mkdir(parents=True, exist_ok=True)

def export_model(model, name: str):
    code = m2c.export_to_language(model, language=m2c.Language.DART)
    (OUT_DIR / f"{name}_scorer.dart").write_text(code, encoding="utf-8")
```

---

### 4.7 Validate export (Hour 20–24)

**File**

- `offline_ml/src/validate_export.py`

**Goal**: confirm Dart function outputs match Python model to within `1e-5`.

**Steps (high level)**

1. Randomly sample 200 rows from synthetic data.
2. Compute predictions using Python model.
3. Run Dart scorers on the same inputs:
   - Can use `dart run` or a small CLI in `gigcredit_app` that prints outputs.
4. Compare; assert `max_abs_diff < 1e-5`.

This step is crucial; do not skip.

---

## 5. Native AI — detailed implementation pipeline

### 5.1 Define interfaces (Hour 2–4)

**File**

- `gigcredit_app/lib/ai/ai_interfaces.dart`

**Goal**: finalize method signatures **before** implementation so Dev B can depend on them.

Example:

```dart
abstract class OcrEngine {
  Future<String> extractText(List<int> imageBytes);
  Future<Map<String, String>> extractFields(
    String rawText,
    DocumentType type,
  );
}

abstract class AuthenticityDetector {
  Future<bool> isAuthentic(List<int> imageBytes);
}

abstract class FaceVerifier {
  Future<double> matchFaces(List<int> selfieBytes, List<int> idBytes);
}
```

Coordinate with Dev B to ensure this covers all their needs.

---

### 5.2 PaddleOCR integration (Hour 6–18)

**Targets**

- `gigcredit_app/lib/ai/ocr_engine.dart`
- Android native modules under `gigcredit_app/android/`:
  - Load PaddleOCR lite models from assets.
  - Expose a method via method channel or FFI:
    - `Future<String> recognizeText(Uint8List imageBytes)`

**Dart side pseudocode**

```dart
class PaddleOcrEngine implements OcrEngine {
  @override
  Future<String> extractText(List<int> imageBytes) async {
    // call into MethodChannel, await result
  }

  @override
  Future<Map<String, String>> extractFields(String rawText, DocumentType type) async {
    // parse raw text using regex & heuristics (Dev A can implement or share with Dev B)
  }
}
```

---

### 5.3 Fraud detection (EfficientNet-Lite0) (Hour 8–18)

**Targets**

- `gigcredit_app/lib/ai/authenticity_detector.dart`
- Android native TFLite integration.

**Behavior**

- Input: single page image bytes.
- Output: boolean `isAuthentic` (pass threshold from spec).

---

### 5.4 Face verification (MobileFaceNet) (Hour 8–18)

**Targets**

- `gigcredit_app/lib/ai/face_verifier.dart`

**Behavior**

- Input: selfie image bytes + extracted ID photo bytes.
- Output: similarity score `0.0–1.0`, with thresholds defined in spec.

---

### 5.5 DocumentProcessor orchestrator (Hour 12–20)

**Target**

- `gigcredit_app/lib/ai/document_processor.dart`

**Goal**: Provide a **single high-level call** used by Dev B’s steps:

```dart
class DocumentProcessor {
  final OcrEngine ocr;
  final AuthenticityDetector detector;

  Future<DocumentProcessingResult> process(DocumentInput input) async {
    // if PDF: split to images (Dev B may provide helper, but Dev A wires AI)
    // for each page: detector.isAuthentic(...)
    // ocr.extractText(...)
    // aggregate raw text + extractFields
  }
}
```

This hides AI complexity behind a simple API.

---

## 6. Integration responsibilities

Throughout the project, Dev A must:

- Keep **interfaces stable** once Dev B starts using them.
- Notify Dev B on every handoff:
  - Backend base URL + header rules.
  - When AI interfaces are ready to use.
  - When scorers + SHAP + meta coefficients are ready and placed in the correct paths.
- Add basic logging to backend and AI layers to help Dev B debug.

If anything in this plan conflicts with your evolving needs, update this file and the corresponding planning docs so both devs and agents stay in sync.


# Dev A Day-1 Execution Pack (Hour 0–12)

Owner: Dev A  
Date: 2026-03-18  
Goal: Deliver unblock-critical backend + ML + interface outputs by end of Day-1.

---

## 0) Day-1 Deliverables (Must Ship Today)

By Hour 12, these must be available:

1. Backend running locally and deployed (or deploy-ready) with stable endpoint contracts.
2. API/AI interface stubs + mocks published for Dev B integration.
3. Offline ML pipeline skeleton runnable end-to-end on sample data.
4. Artifact-generation path validated (even if final tuned artifacts come Day-2).
5. Clear handoff note sent to Dev B with URLs, headers, and method signatures.

---

## 1) Hour-by-Hour Plan

## Hour 0–1: Environment and Baseline

### Actions
- Verify Python environment and dependencies.
- Confirm folder baselines for `backend/`, `offline_ml/`, `gigcredit_app/lib/ai`, `gigcredit_app/lib/services`.
- Run baseline checks.

### Commands
```powershell
Set-Location "d:\Program Files\GigCredit"
python --version
pip --version
git status -sb
```

### Exit Criteria
- Python and pip available.
- Working tree status understood.

---

## Hour 1–2: Publish Unblock Interfaces (Critical)

### Actions
- Ensure these are published and compile-safe:
  - `gigcredit_app/lib/services/api_client_interface.dart`
  - `gigcredit_app/lib/services/mock_api_client.dart`
  - `gigcredit_app/lib/ai/ai_interfaces.dart`
  - `gigcredit_app/lib/ai/mock_document_processor.dart`

### Dev B Handoff Requirement
- Provide one message to Dev B with:
  - interface file paths,
  - required method names,
  - sample response JSON for each endpoint mock.

### Exit Criteria
- Dev B can continue Steps 2–8 integration without backend dependency.

---

## Hour 2–4: Backend Core Boot

### Actions
- Validate backend entrypoint and configuration.
- Ensure root health endpoint and docs work.

### Commands
```powershell
Set-Location "d:\Program Files\GigCredit\backend"
python -m pip install -r requirements.txt
python scripts/run_dev.py
```

### Quick Checks
- `GET /` returns healthy status.
- `/docs` opens and lists verification/report routes.

### Exit Criteria
- Local backend starts reliably and routers are registered.

---

## Hour 4–6: Auth + Verification Endpoint Contracts

### Actions
- Freeze and validate auth behavior:
  - API key check
  - HMAC signature check
  - timestamp replay window
  - rate limit hook
- Verify endpoint request/response schema consistency.

### Endpoint Contract Set
- `/gov/pan/verify`
- `/gov/aadhaar/verify`
- `/bank/ifsc/verify`
- `/bank/account/verify`
- `/gov/vehicle/rc/verify`
- `/gov/insurance/verify`
- `/gov/income-tax/itr/verify`
- `/gov/eshram/verify`
- `/bank/loan/check`
- `/report/generate`
- `/report/store` (optional contract)

### Exit Criteria
- Endpoint contract table frozen and shared with Dev B.

---

## Hour 6–8: Offline ML Skeleton and Reproducibility

### Actions
- Run offline ML scripts on small/sample configuration first.
- Confirm script chain executes in order:
  - data generation
  - tuning scaffold
  - model training scaffold
  - export scaffold
  - validation scaffold

### Commands (example sequence)
```powershell
Set-Location "d:\Program Files\GigCredit\offline_ml"
python src/data_generator.py
python src/tune_models.py
python src/train_final.py
python src/train_meta_learner.py
python src/export_to_dart.py
python src/validate_export.py
```

### Exit Criteria
- Pipeline executes without structural failure.
- Intermediate artifacts are produced (even if preliminary).

---

## Hour 8–10: Artifact Contract Prep (Dev B Integration)

### Actions
- Confirm required artifacts are generated/planned with exact names:
  - `p1_scorer.dart`, `p2_scorer.dart`, `p3_scorer.dart`, `p4_scorer.dart`, `p6_scorer.dart`
  - `shap_lookup.json`
  - `meta_coefficients.json`
  - `state_income_anchors.json`
  - `feature_means.json`
- Verify transport path into app is clear and documented.

### Exit Criteria
- Dev B receives a verified list with expected locations and load instructions.

---

## Hour 10–12: Deploy + Integration Note

### Actions
- Deploy backend service (or complete deployment-ready checklist).
- Publish a concise integration note for Dev B.

### Dev B Integration Note Template
- Base URL:
- Required headers:
- Endpoint path map:
- Mock-to-real switch instructions:
- Known temporary limitations:

### Exit Criteria
- Dev B can point app to backend without additional blocking questions.

---

## 2) Day-1 Acceptance Checklist

- [ ] Interface stubs + mocks published.
- [ ] Backend local server healthy.
- [ ] Verification/report endpoint contracts frozen.
- [ ] Offline ML script chain executes.
- [ ] Artifact names/paths frozen and shared.
- [ ] Deployment URL (or deployment-ready checklist) shared.
- [ ] No unresolved P0 blockers left for Day-2.

---

## 3) P0 Stop Conditions (Escalate Immediately)

1. Feature slicing ambiguity (95-map inconsistency) is detected.
2. Final score implementation path diverges from LR meta-learner contract.
3. Required artifact filenames differ between ML output and app loader.
4. Dev B remains blocked due to missing interfaces after Hour 2.

---

## 4) Day-2 Preview (for continuity)

- Tighten model quality and export parity.
- Replace mocks with real AI integrations where feasible.
- Stabilize `/report/generate` multilingual output with fallback behavior.
- Run first joint end-to-end smoke test with Dev B.

---

## 5) Operating Rule (Explicit)

Any repo push action requires explicit user confirmation in-chat before executing push.

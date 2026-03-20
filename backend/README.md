# GigCredit Backend

FastAPI + MongoDB simulation backend for GigCredit.

## MongoDB Setup (Atlas or local)

Use a `.env` file in `backend/`.

Example Atlas URI format:

```env
MONGO_URI=mongodb+srv://praveen_jey:<db_password>@cluster0.3ydbumb.mongodb.net/?appName=Cluster0
MONGO_DB_NAME=gigcredit
API_KEY=replace_with_secure_key
GEMINI_API_KEY=
VERIFICATION_LOG_RETENTION_DAYS=90
REPORT_LOG_RETENTION_DAYS=180
AUDIT_TRACE_RETENTION_DAYS=30
```

If running local MongoDB instead:

```env
MONGO_URI=mongodb://localhost:27017
MONGO_DB_NAME=gigcredit
```

## Quick start

1. Create environment file from `.env.example`.
2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Seed simulation data:

```bash
python scripts/seed_db.py
```

This creates and seeds workflow collections used by verification routes:
- `pan_records`
- `aadhaar_records`
- `bank_records`
- `scheme_records`
- `pan_db`
- `aadhaar_db`
- `ifsc_db`
- `bank_accounts_db`
- `vehicle_rc_db`
- `insurance_db`
- `itr_db`
- `gst_db`
- `eshram_db`
- `svanidhi_db`
- `fssai_db`
- `skill_cert_db`
- `pmsym_db`
- `pmjjby_db`
- `udyam_db`
- `ppf_db`
- `loan_accounts_db`
- `utility_bills_db`

4. Run server:

```bash
python scripts/run_dev.py
```

## Auth headers required

All protected endpoints require:
- `X-API-Key`
- `X-Device-ID`
- `X-Timestamp`
- `X-Signature`

Signature formula:
- `body_hash = sha256(raw_body_bytes)`
- `message = device_id + timestamp + body_hash`
- `signature = hmac_sha256(api_key, message)`

## Migration and backup policy

- See `backend/MIGRATION_AND_BACKUP_POLICY.md` for migration sequencing,
  retention defaults, backup cadence, and restore drill requirements.

## Implemented verification API routes

Core routes:
- `POST /verify/pan`
- `POST /verify/aadhaar`
- `POST /verify/bank/ifsc`
- `POST /verify/bank/account`
- `POST /verify/vehicle/rc`
- `POST /verify/insurance`
- `POST /verify/income-tax/itr`
- `POST /verify/gst`
- `POST /verify/eshram`
- `POST /verify/loan`
- `POST /verify/utility`
- `POST /verify/utility/{utility_type}`

Work/scheme routes (including legacy app compatibility aliases):
- `POST /gov/svanidhi/verify`
- `POST /verify/svanidhi`
- `POST /api/gov/svanidhi/verify`
- `POST /gov/fssai/verify`
- `POST /verify/fssai`
- `POST /api/gov/fssai/verify`
- `POST /gov/skill/verify`
- `POST /verify/skill`
- `POST /api/gov/skill/verify`
- `POST /verify/pmsym`
- `POST /verify/pmjjby`
- `POST /verify/udyam`
- `POST /verify/ppf`


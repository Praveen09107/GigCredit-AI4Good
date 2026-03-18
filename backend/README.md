# GigCredit Backend

FastAPI + MongoDB simulation backend for GigCredit.

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


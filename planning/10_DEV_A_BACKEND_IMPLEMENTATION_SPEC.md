# Dev A Backend Implementation Spec (Detailed)

Owner: Dev A  
Scope: `backend/` only  
Stage: Pre-implementation review draft  

---

## 1) Objective

Build a secure, deterministic FastAPI backend that provides:
- verification simulation APIs,
- report generation API,
- optional report storage,
- strict request auth and anti-replay.

Backend must never compute score or feature engineering.

---

## 2) Directory and file contract

Target structure (must exist):

- `backend/app/main.py`
- `backend/app/config.py`
- `backend/app/database.py`
- `backend/app/auth.py`
- `backend/app/models/api.py`
- `backend/app/models/records.py`
- `backend/app/routers/verify.py`
- `backend/app/routers/report.py`
- `backend/app/services/gov_service.py`
- `backend/app/services/llm_service.py`
- `backend/app/services/rate_limiter.py`
- `backend/app/utils/security.py`
- `backend/app/utils/logging.py`
- `backend/scripts/seed_db.py`
- `backend/scripts/run_dev.py`
- `backend/requirements.txt`
- `backend/.env.example`
- `backend/README.md`

---

## 3) Endpoint contract (frozen)

### 3.1 Verification
- `POST /gov/pan/verify`
- `POST /gov/aadhaar/verify`
- `POST /bank/ifsc/verify`
- `POST /bank/account/verify`
- `POST /gov/vehicle/rc/verify`
- `POST /gov/insurance/verify`
- `POST /gov/income-tax/itr/verify`
- `POST /gov/eshram/verify`
- `POST /bank/loan/check`

### 3.2 Report
- `POST /report/generate`
- `POST /report/store` (optional)

### 3.3 Health
- `GET /` returns service status
- `GET /health` returns health + dependency status

---

## 4) Request/response schema

## 4.1 Request envelope
- `request_id`: string (uuid)
- `identifier`: string
- `context`: object (optional)

## 4.2 Response envelope
- `status`: FOUND | NOT_FOUND | INVALID | ERROR | OK
- `data`: object | null
- `error`: string | null
- `trace_id`: string

Rule: All routes return envelope; no raw payload responses.

---

## 5) Auth and security middleware

Required headers:
- `X-API-Key`
- `X-Device-ID`
- `X-Timestamp`
- `X-Signature`

Computation:
- `body_hash = sha256(raw_body_bytes)`
- `message = device_id + timestamp + body_hash`
- `expected = hmac_sha256(api_key, message)`

Validation chain:
1. API key present and valid.
2. Timestamp within replay window (5 minutes).
3. Signature match.
4. Rate limiter pass.

Failure behavior:
- return HTTP 401 for auth failures,
- HTTP 429 for rate-limit failures,
- envelope body still provided.

---

## 6) Rate limiting rules (MVP freeze)

- per device global: 60 req/min
- per endpoint: 10 req/min
- burst: 5 req/sec

Implementation notes:
- in-memory limiter acceptable for MVP,
- abstract limiter backend so Redis can be introduced later.

---

## 7) Data model and Mongo collections

Use frozen schemas from backend hardening doc.

Minimum index setup:
- unique where specified (`pan_number`, `loan_id`),
- compound index for bank hash + IFSC,
- TTL index on `created_at` with 365 days.

Privacy constraints:
- avoid full Aadhaar in simulation store,
- avoid raw documents in DB,
- hash sensitive identifiers where possible.

---

## 8) Service-level behavior per endpoint

For each verify endpoint:
1. validate request shape,
2. normalize identifier (uppercase/trim etc.),
3. query collection,
4. map record to minimal response,
5. return envelope.

Invalid input examples:
- malformed PAN/Aadhaar format,
- missing required field.

NOT_FOUND behavior:
- must not throw server error,
- must return deterministic NOT_FOUND envelope.

---

## 9) Report generation pipeline

Input fields:
- final score,
- pillar scores,
- top positive/negative drivers,
- language.

Process:
1. construct deterministic prompt,
2. call Gemini,
3. parse strict JSON,
4. validate expected keys,
5. fallback template on parse/model error.

Guarantees:
- backend does not alter numeric scores,
- always returns usable report payload (real or fallback).

---

## 10) Logging standard

Every request log line must include:
- timestamp,
- trace_id/request_id,
- endpoint,
- status code,
- envelope status,
- latency_ms.

Never log:
- full documents,
- full Aadhaar/PAN,
- secrets/api keys,
- raw OCR text.

---

## 11) Error handling matrix (backend)

- Input validation error -> INVALID, 400
- Auth error -> ERROR, 401
- Rate limit -> ERROR, 429
- Upstream LLM error -> ERROR with fallback report payload
- DB unavailable -> ERROR, 503 (or 500 in MVP with clear message)

---

## 12) Day-1 implementation order (backend)

1. config + app startup + health routes
2. auth middleware + security utils
3. base response models
4. verify routes (all)
5. seed script and index setup
6. report route + llm service fallback
7. smoke tests
8. deploy

---

## 13) Acceptance criteria (backend)

- App boots locally and docs render.
- All 11 primary endpoints reachable.
- Auth works for good and bad signatures.
- Rate limiting enforced.
- NOT_FOUND behavior deterministic.
- Report endpoint always returns parseable payload.
- No secret leakage in logs.

---

## 14) Handoff package to Dev B

Provide:
- base URL,
- endpoint map,
- request headers required,
- sample request/response for each endpoint,
- known limitations.

Blocker rule:
If endpoint contracts change after handoff, update document and notify Dev B immediately.

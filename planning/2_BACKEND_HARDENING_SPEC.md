# GigCredit — Backend Hardening Spec (MVP Simulation, Production-Grade Patterns)

This document freezes the backend data model + auth requirements for the FastAPI + MongoDB simulation backend.

## 1) Backend scope (unchanged)
Backend responsibilities:
- Simulated verification APIs (PAN/Aadhaar/IFSC/bank/policy/RC/ITR/schemes/loans)
- LLM report generation (Gemini)
- Optional storage of final `ScoreReport`

Backend MUST NOT:
- Run OCR
- Store documents
- Run scoring/feature engineering

## 2) Privacy + retention rules (MVP)
- **Minimize PII** in MongoDB simulation datasets.
- **TTL cleanup** for simulation data: 365 days.
- App is **read-only** with respect to verification datasets (seeded by a script).

## 3) MongoDB collections (frozen schemas)

### 3.1 `pan_db`
```js
{
  _id: ObjectId,
  pan_number: String,            // UNIQUE, indexed
  full_name: String,
  dob: Date,
  status: "ACTIVE" | "INACTIVE",
  created_at: Date               // TTL: 365 days
}
```
Indexes:
- `pan_number` unique
- `created_at` TTL (31536000 seconds)

### 3.2 `aadhaar_db`
MVP stores **only last-4** digits (to avoid storing full Aadhaar in a demo DB).

```js
{
  _id: ObjectId,
  aadhaar_last4: String,         // indexed (NOT unique in the real world, but OK for simulation)
  full_name: String,
  dob: Date,
  address_state: String,
  status: "ACTIVE",
  created_at: Date               // TTL: 365 days
}
```
Indexes:
- `aadhaar_last4`
- `created_at` TTL

### 3.3 `bank_accounts_db`
Store hashed account number to minimize risk.

```js
{
  _id: ObjectId,
  account_number_hash: String,   // indexed
  ifsc_code: String,
  account_holder_name: String,
  bank_name: String,
  status: "ACTIVE" | "CLOSED",
  created_at: Date               // TTL: 365 days
}
```
Indexes:
- `(account_number_hash, ifsc_code)` compound (recommended)
- `created_at` TTL

### 3.4 `loan_accounts_db`
```js
{
  _id: ObjectId,
  loan_id: String,               // UNIQUE, indexed
  borrower_name: String,
  lender: String,
  loan_type: "Personal" | "Home" | "Vehicle" | "BNPL" | "Card",
  emi_amount: Number,
  loan_status: "Active" | "Closed",
  created_at: Date               // TTL: 365 days
}
```
Indexes:
- `loan_id` unique
- `created_at` TTL

### 3.5 `score_reports_db` (optional persistence)
```js
{
  _id: ObjectId,
  user_id: String,               // hashed phone (index)
  generated_at: Date,            // index
  score: Number,                 // 300-900
  grade: String,                 // S/A/B/C/D/E
  risk_band: String,             // Low/Medium/High
  work_type: String,
  pillar_scores: Object,         // P1..P8 (each 0..1 or display 0..100)
  report_text: String            // LLM generated
}
```
Indexes:
- `(user_id, generated_at)` compound

## 4) API authentication (frozen for MVP)
We will use **API Key + HMAC signature** (stateless) as specified in the “Comprehensive Fixes” doc:

Required headers on every request:
- `X-API-Key`
- `X-Device-ID`
- `X-Timestamp` (unix ms)
- `X-Signature` = HMAC-SHA256(api_key, device_id + timestamp + body_hash)

Backend validation:
- API key exists and matches
- signature matches
- timestamp within 5 minutes (replay protection)

Rate limiting (MVP):
- Per device: 60 req/min
- Per endpoint: 10 req/min
- Burst: 5 req/sec

## 5) Response contracts (MVP)
- Always return a consistent envelope:
  - `status`: `FOUND | NOT_FOUND | INVALID | ERROR`
  - `data`: object if found
  - `error`: optional error message

## 6) Notes on future production
In production, the “simulation datasets” would be replaced by:
- regulated KYC providers / government integrations
- strict audit logging
- stronger auth (OAuth/JWT) and device attestation


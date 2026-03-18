# Dev A On-Device AI Integration Spec (Detailed)

Owner: Dev A  
Scope: `gigcredit_app/lib/ai/` and native bridges  
Stage: Pre-implementation review draft

---

## 1) Objective

Deliver reliable on-device AI capabilities behind stable Dart interfaces so UI/business logic can consume them without coupling to native details.

Core capabilities:
- OCR
- document authenticity check
- face verification
- high-level document processing orchestrator

---

## 2) Interface-first contract

Must exist first (before real implementations):
- `ai_interfaces.dart`
- `mock_document_processor.dart`

Interface classes (minimum):
- `OcrEngine`
- `AuthenticityDetector`
- `FaceVerifier`
- `DocumentProcessor`

Rule:
- UI/business logic imports only interfaces, not concrete native classes.

---

## 3) Module responsibilities

### 3.1 OCR engine
- input: image bytes/file path,
- output: raw text + confidence + token boxes (if available),
- behavior: deterministic parse pipeline with timeout protection.

### 3.2 Authenticity detector
- classify as real/suspicious/edited,
- return confidence score,
- hard fail path if model not loaded.

### 3.3 Face verifier
- extract embeddings for two face inputs,
- compute similarity,
- threshold mapping:
  - pass,
  - retry,
  - reject.

### 3.4 Document processor
- orchestration order:
  1. authenticity check,
  2. OCR,
  3. field extraction,
  4. validation summary.

---

## 4) Native bridge strategy

Android MVP may use MethodChannel/FFI depending on current setup.

Bridge requirements:
- explicit error codes,
- bounded execution timeout,
- memory-safe handling for large images,
- no UI-thread blocking for heavy inference.

---

## 5) Error model and fallback behavior

Categories:
- model_load_failed,
- inference_failed,
- low_confidence,
- invalid_input.

Fallback rules:
- return structured failure object,
- never crash caller,
- preserve trace id for logs.

---

## 6) Threshold policy (frozen behavior)

Face verification default behavior:
- high similarity: pass,
- middle band: retry flow,
- low similarity: reject.

Authenticity policy:
- suspicious documents cannot auto-pass verification.

OCR policy:
- low-confidence OCR must be marked for user correction/re-upload.

---

## 7) Performance targets

Indicative target budgets:
- authenticity check: sub-second on target device class,
- OCR extraction: near-real-time user acceptable delay,
- face comparison: quick enough for step flow continuity,
- full document processor path: bounded to avoid UX stall.

---

## 8) Logging and privacy constraints

Log only:
- model name/version,
- latency,
- confidence,
- error codes.

Never log:
- raw image bytes,
- full OCR text containing sensitive identity data.

---

## 9) Integration test matrix (AI)

Required tests:
1. model load success/failure simulation,
2. OCR on clear vs noisy input,
3. authenticity on known good/bad examples,
4. face same-person vs different-person examples,
5. document processor end-to-end result shape validation.

---

## 10) Day-1 implementation order (AI)

1. lock interfaces,
2. deliver mocks,
3. stub concrete implementations with deterministic placeholders,
4. wire orchestrator,
5. define test fixtures.

Real model tuning/integration can continue Day-2 while Dev B remains unblocked.

---

## 11) Acceptance criteria (AI integration)

- interface package stable and consumed by app,
- mocks provide parseable realistic outputs,
- orchestrator contract does not change unexpectedly,
- failures are structured and non-crashing,
- integration tests run on representative sample inputs.

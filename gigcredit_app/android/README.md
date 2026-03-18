# Android Native AI Bridge Scaffold

This scaffold wires Flutter `MethodChannel` calls for `gigcredit/ai_native` in Android.

## Entry point
- `app/src/main/kotlin/com/gigcredit/app/MainActivity.kt`

## Implemented contract methods
- `ai.health`
- `ocr.extractText`
- `authenticity.detect`
- `face.match`

## Notes
- Handlers run on a background executor, and responses are posted back to the main thread.
- Runtime layer includes per-call timeout handling (`timeout`) and model lifecycle gating (`model_load_failed`).
- Set env var `GIGCREDIT_FORCE_MODEL_LOAD_FAIL=1` to simulate model load failure for testing.
- Current inference implementations are deterministic placeholders ready to be replaced with production ML runtime.
- No raw image bytes or full OCR text are logged.

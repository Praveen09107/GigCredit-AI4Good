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
- Native handlers enforce a 5MB input limit per image payload (`invalid_input` when exceeded).
- Native authenticity and face-match now use bitmap-based image processing and face-region extraction.
- Android OCR method currently emits `unsupported` unless an OCR engine (for example ML Kit Text Recognition) is integrated; Dart fallback handles this path.
- No raw image bytes or full OCR text are logged.

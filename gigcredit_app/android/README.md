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
- `ocr.extractText` first attempts true on-device OCR via ML Kit runtime (resolved dynamically); when unavailable, it falls back to deterministic OCR-proxy output.
- `authenticity.detect` first attempts TFLite model inference from `assets/models/efficientnet_lite0.tflite`; when unavailable, it falls back to heuristic authenticity classification.
- `face.match` first attempts MobileFaceNet-style embedding inference from `assets/models/mobilefacenet.tflite` after face crop extraction; when unavailable, it falls back to histogram-signature cosine similarity.
- `ai.health` includes runtime capability flags: `ocrRuntimeAvailable`, `tfliteRuntimeAvailable`, `authenticityModelAvailable`, and `faceModelAvailable`.
- No raw image bytes or full OCR text are logged.

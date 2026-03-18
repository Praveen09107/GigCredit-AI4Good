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
- Current implementations are deterministic prototype stubs (no external ML runtime yet).
- No raw image bytes or full OCR text are logged.

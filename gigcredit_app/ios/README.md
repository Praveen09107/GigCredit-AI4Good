# iOS Native AI Bridge Scaffold

This scaffold wires Flutter `MethodChannel` calls for `gigcredit/ai_native` in iOS.

## Entry point
- `Runner/AppDelegate.swift`

## Implemented contract methods
- `ai.health`
- `ocr.extractText`
- `authenticity.detect`
- `face.match`

## Notes
- Method handlers run on a background dispatch queue and return on main.
- Runtime layer includes per-call timeout handling (`timeout`) and model lifecycle gating (`model_load_failed`).
- Set env var `GIGCREDIT_FORCE_MODEL_LOAD_FAIL=1` to simulate model load failure for testing.
- Native handlers enforce a 5MB input limit per image payload (`invalid_input` when exceeded).
- Current inference logic is deterministic placeholder behavior, ready for replacement with production ML runtime.
- No raw image bytes or full OCR text are logged.

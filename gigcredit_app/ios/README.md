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
- Current logic is prototype-grade deterministic behavior, ready for replacement with production ML runtime.
- No raw image bytes or full OCR text are logged.

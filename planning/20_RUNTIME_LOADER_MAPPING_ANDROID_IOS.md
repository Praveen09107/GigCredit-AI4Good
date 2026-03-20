# 20) Runtime Loader Mapping (Android + iOS)

Owner: ML owner (artifact contract), Dev B (integration validation)

## 1) Artifact locations expected by runtime

- App assets directory: `gigcredit_app/assets/models/`
- Required runtime files:
  - `efficientnet_lite0.tflite`
  - `mobilefacenet.tflite`

## 2) Android runtime mapping

Source: `gigcredit_app/android/app/src/main/kotlin/com/gigcredit/app/MainActivity.kt`

- Channel: `gigcredit/ai_native`
- Authenticity model asset key: `models/efficientnet_lite0.tflite`
- Face model asset key: `models/mobilefacenet.tflite`
- Capability probes returned by `ai.health`:
  - `ocrRuntimeAvailable`
  - `tfliteRuntimeAvailable`
  - `authenticityModelAvailable`
  - `faceModelAvailable`

Android availability condition:
- `tfliteRuntimeAvailable` must be true
- Model files must exist in app bundle assets

## 3) iOS runtime mapping

Source: `gigcredit_app/ios/Runner/AppDelegate.swift`

- Channel: `gigcredit/ai_native`
- Asset lookup path root: `flutter_assets/assets/models/`
- Authenticity model lookup:
  - `assets/models/efficientnet_lite0.tflite`
- Face model lookup:
  - `assets/models/mobilefacenet.tflite`
- Capability probes returned by `ai.health`:
  - `ocrRuntimeAvailable`
  - `tfliteRuntimeAvailable`
  - `authenticityModelAvailable`
  - `faceModelAvailable`

iOS availability condition:
- TFLite runtime class present
- Files present under `flutter_assets/assets/models/`

## 4) OCR runtime strategy mapping

Current production contract: ML Kit OCR runtime path.

- Contract file: `offline_ml/data/runtime_model_contract.json`
- `runtime_strategy.ocr_runtime = mlkit_text_recognition`
- No extra OCR model artifact required under current strategy.

If OCR strategy changes to Paddle:
- Add required OCR runtime files in `gigcredit_app/assets/models/`
- Add those files to runtime contract under `artifacts`
- Pass `--require-artifact` for each OCR file in packaging step

## 5) Runtime packaging pipeline binding

- Contract input: `offline_ml/data/runtime_model_contract.json`
- Manifest target: `gigcredit_app/assets/constants/artifact_manifest.json`
- Packaging command:
  - `python -m offline_ml.src.package_runtime_models_for_app`

Outputs:
- Manifest `runtime_models` block with checksum + metadata
- Handoff report: `offline_ml/data/runtime_model_handoff_report.json`

## 6) Acceptance criteria for loader mapping closure

- Both runtimes resolve model paths exactly as above
- `ai.health` returns true for all required capability flags
- Strict mode startup passes without heuristic fallback
- Dev B smoke checks pass (OCR/authenticity/face-match)

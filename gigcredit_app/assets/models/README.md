# Model Assets

Place production model files here for native Android runtime inference.

Expected files:

- `ocr_model.tflite` (OCR model)
- `scoring_model.tflite` (on-device scoring model contract)

Optional files (not required for OCR+scoring local pipeline):

- `efficientnet_lite0.tflite` (document authenticity)
- `mobilefacenet.tflite` (face embedding for selfie vs ID match)

Current status:

- `scoring_model.tflite` is present in this folder.
- `ocr_model.tflite` is required for strict OCR model runtime.
- Face/authenticity models are optional for this local OCR+scoring prototype path.

PaddleOCR Lite conversion:

1. Prepare Paddle OCR inference folder with:
	- `inference.pdmodel`
	- `inference.pdiparams`
2. Run conversion:
	- `python -m offline_ml.src.convert_paddleocr_to_tflite --paddle-model-dir <path_to_paddle_inference_dir> --output gigcredit_app/assets/models/ocr_model.tflite`
3. If you already have a ready OCR `.tflite` file, copy it into place with:
	- `python -m offline_ml.src.convert_paddleocr_to_tflite --ocr-tflite-source <path_to_ocr_model.tflite> --output gigcredit_app/assets/models/ocr_model.tflite`
4. Rebuild app:
	- `flutter clean`
	- `flutter pub get`
	- build APK again

Dev A drop-in checklist (eta handoff):

1. Ensure required model files exist with exact names above.
2. Rebuild app assets (`flutter clean` then `flutter pub get`).
3. Run strict readiness command:
	- `flutter test test/startup_self_check_gate_test.dart test/integration_9_step_progression_test.dart test/step3_to_step9_linkage_test.dart test/scoring_engine_test.dart test/verification_validation_engine_test.dart test/generate_report_script.dart --dart-define=GIGCREDIT_REQUIRE_PRODUCTION_READINESS=true`
4. Open the in-app startup gate and confirm no blocking native runtime/model failures.

Behavior:

- If files are present and TFLite runtime is available, Android native bridge uses model inference.
- If files are missing, startup/runtime checks fail and document processing is blocked until models are available.

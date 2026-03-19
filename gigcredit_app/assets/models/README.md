# Model Assets

Place production model files here for native Android runtime inference.

Expected files:

- `efficientnet_lite0.tflite` (document authenticity)
- `mobilefacenet.tflite` (face embedding for selfie vs ID match)

Behavior:

- If files are present and TFLite runtime is available, Android native bridge uses model inference.
- If files are missing, bridge falls back to deterministic heuristic paths.

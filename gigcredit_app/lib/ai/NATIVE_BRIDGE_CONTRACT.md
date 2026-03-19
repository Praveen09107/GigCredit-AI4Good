# Native AI Bridge Contract (Dev A)

Channel name: `gigcredit/ai_native`

## Methods

### `ai.health`

Request payload:

```json
{}
```

Response payload:

```json
{
  "ready": true,
  "engineVersion": "string",
  "modelsLoaded": true,
  "ocrRuntimeAvailable": true,
  "tfliteRuntimeAvailable": true,
  "authenticityModelAvailable": true,
  "faceModelAvailable": true
}
```

Capability flags may be absent on older runtimes; Dart callers should treat absent flags as unknown and preserve backward compatibility.

### `ocr.extractText`

Request payload:

```json
{
  "imageBytes": [0, 1, 2],
  "meta": {
    "documentType": "pan|aadhaar_front|aadhaar_back|bank_statement|rc|insurance|itr|bill",
    "captureMode": "camera|gallery",
    "rotationDegrees": 0,
    "languageHint": "en",
    "byteCount": 123456,
    "meanIntensity": 128.4,
    "entropyLike": 0.24,
    "blurScore": 0.0,
    "glareScore": 0.0,
    "perspectiveScore": 0.0,
    "deviceModel": "optional-string"
  }
}
```

Response payload:

```json
{
  "rawText": "string",
  "confidence": 0.0
}
```

`meta` is optional but strongly recommended for production OCR quality tuning and diagnostics.

### `authenticity.detect`

Request payload:

```json
{
  "imageBytes": [0, 1, 2]
}
```

Response payload:

```json
{
  "label": "real|suspicious|edited",
  "confidence": 0.0
}
```

### `face.match`

Request payload:

```json
{
  "selfieBytes": [0, 1, 2],
  "idBytes": [0, 1, 2]
}
```

Response payload:

```json
{
  "similarity": 0.0,
  "passed": true
}
```

## Error codes

Method handlers should throw platform errors using these codes:

- `model_load_failed`
- `inference_failed`
- `invalid_input`
- `timeout`
- `unsupported`

## Runtime behavior expectations

- Calls must run off UI thread.
- Maximum method latency target: 6 seconds.
- Image bytes should be processed in-memory only.
- Never log raw image bytes or full OCR text.
- If native channel is unavailable, Dart fallback engines are used automatically.

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
  "modelsLoaded": true
}
```

### `ocr.extractText`
Request payload:
```json
{
  "imageBytes": [0, 1, 2]
}
```
Response payload:
```json
{
  "rawText": "string",
  "confidence": 0.0
}
```

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

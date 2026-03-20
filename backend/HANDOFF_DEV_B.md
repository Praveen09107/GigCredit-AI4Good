# Dev A Backend Handoff for Dev B

## Base URLs

- Local: `http://localhost:8000`
- Deployed: `<set-render-url-here>`

## Required Headers (Protected Endpoints)

- `X-API-Key`
- `X-Device-ID`
- `X-Timestamp` (Unix ms)
- `X-Signature`

Signature formula:

1. `body_hash = sha256(raw_body_bytes)`
2. `message = device_id + timestamp + body_hash`
3. `signature = hmac_sha256(api_key, message)`

## Endpoint Map

### Verification
- `POST /gov/pan/verify`
- `POST /gov/aadhaar/verify`
- `POST /bank/ifsc/verify`
- `POST /bank/account/verify`
- `POST /gov/vehicle/rc/verify`
- `POST /gov/insurance/verify`
- `POST /gov/income-tax/itr/verify`
- `POST /gov/eshram/verify`
- `POST /bank/loan/check`

### Report
- `POST /report/generate`
- `POST /report/store`

### Health
- `GET /`
- `GET /health`

## Request/Response Envelope

### Verify request
```json
{
  "request_id": "uuid-optional",
  "identifier": "string",
  "context": {}
}
```

### Common response envelope
```json
{
  "status": "FOUND|NOT_FOUND|INVALID|ERROR|OK",
  "data": {},
  "error": null,
  "trace_id": "uuid"
}
```

## Sample Calls

### PAN verify request
```json
{
  "identifier": "ABCDE1234F"
}
```

### PAN verify success response
```json
{
  "status": "FOUND",
  "data": {
    "pan_number": "ABCDE1234F",
    "full_name": "RAVI KUMAR",
    "status": "ACTIVE"
  },
  "error": null,
  "trace_id": "..."
}
```

### Report generate request
```json
{
  "request_id": "req-001",
  "language": "en",
  "score": 702,
  "pillars": {
    "p1": 0.8,
    "p2": 0.7,
    "p3": 0.6,
    "p4": 0.75,
    "p5": 0.65,
    "p6": 0.7,
    "p7": 0.6
  },
  "shap_factors": [
    {
      "key": "income_consistency",
      "direction": "positive",
      "value": 0.12
    }
  ]
}
```

## Known Limitations (Prototype)

- Verification uses simulation collections (not live government services).
- In-memory rate limiting resets on server restart.
- Report generation may fall back to template when LLM/API unavailable.

## Dev B Switch Checklist

- [ ] Set backend base URL in client config
- [ ] Enable signature provider in `BackendClient`
- [ ] Validate all required auth headers per request
- [ ] Test one verify endpoint + report endpoint using real backend
- [ ] Keep `MockApiClient` fallback for offline/demo mode

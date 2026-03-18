# OCR Input Capture Template (Fill This)

Date: 2026-03-19  
Owner: _______________

## 1) Required Per-Capture Fields

Use this JSON shape for each OCR submission:

```json
{
  "documentType": "pan|aadhaar_front|aadhaar_back|bank_statement|rc|insurance|itr|bill",
  "captureMode": "camera|gallery",
  "rotationDegrees": 0,
  "languageHint": "en",
  "blurScore": 0.0,
  "glareScore": 0.0,
  "perspectiveScore": 0.0,
  "deviceModel": "model_name",
  "appVersion": "x.y.z"
}
```

## 2) Field Definitions

- `documentType`: exact canonical type selected by user.
- `captureMode`: camera vs gallery import.
- `rotationDegrees`: image orientation at submission (`0|90|180|270`).
- `languageHint`: expected primary script (`en`, `hi`, etc.).
- `blurScore`: normalized blur estimate (`0.0` sharp → `1.0` severe blur).
- `glareScore`: normalized glare/overexposure estimate (`0.0` none → `1.0` severe).
- `perspectiveScore`: perspective skew estimate (`0.0` flat → `1.0` severe skew).
- `deviceModel`: device model string.
- `appVersion`: app build version.

## 3) Capture Quality Requirements (User-Facing)

- Entire document visible in frame, all 4 corners inside image.
- No finger occlusion, no heavy shadows.
- Text lines should be upright (preferred rotation 0°).
- Minimum recommended resolution: 1200px on longer side.
- Avoid compressed screenshots and forwarded images where possible.

## 4) Sample Payload You Can Send Us

```json
{
  "documentType": "pan",
  "captureMode": "camera",
  "rotationDegrees": 0,
  "languageHint": "en",
  "blurScore": 0.08,
  "glareScore": 0.11,
  "perspectiveScore": 0.06,
  "deviceModel": "Pixel 7",
  "appVersion": "1.4.2"
}
```

## 5) What We’ll Do With It

- Route OCR settings per document type.
- Use quality scores to decide retry prompts vs proceed.
- Track OCR confidence drift by device/capture mode.
- Improve thresholding and fallback behavior.

## 6) Cross-Check Extraction Field Set (from Input_fields_final)

Use this as the expected extraction target while reviewing sample inputs.

### Identity Documents

- Aadhaar Front:
  - Full Name
  - Date of Birth
  - Gender
  - Aadhaar Number
  - Photo present flag

- Aadhaar Back:
  - Address Line 1
  - Address Line 2
  - City / District
  - State
  - PIN Code

- PAN:
  - Full Name
  - Father's Name
  - Date of Birth
  - PAN Number
  - Photo present flag

### Bank Statement (Primary/Secondary)

- Header fields:
  - Bank Name
  - Account Holder Name
  - Account Number
  - IFSC Code
  - MICR Code
  - Statement From Date
  - Statement To Date
  - Account Type

- Transaction row fields:
  - Transaction Date
  - Transaction Description
  - Credit Amount
  - Debit Amount
  - Running Balance
  - Transaction Mode

- Secondary statement extra flags:
  - secondary_bank_name
  - is_jan_dhan_account

### Utility / Residence (as available in your samples)

- Electricity / LPG / Mobile / WiFi bill:
  - Consumer / Account ID
  - Bill Date
  - Due Date
  - Total Amount
  - Paid Amount (if present)
  - Address / Service Location

## 7) Manual Extraction Limits (What I may ask you to provide)

If a file is unreadable or structurally ambiguous, I’ll ask for missing values explicitly.
Typical blockers:

- Very low resolution / blur / glare
- Cropped document edges or partial pages
- Password-protected / image-only PDFs with poor scan quality
- Regional-language text with mixed scripts where OCR confidence is too low
- Multi-page statements with inconsistent table structure

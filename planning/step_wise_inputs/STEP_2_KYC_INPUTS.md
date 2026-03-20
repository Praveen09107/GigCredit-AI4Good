# Step 2 - Identity (KYC) Inputs
Source: gigcredit_app/lib/ui/screens/steps/step2_kyc_screen.dart

## Inputs Asked from User

1. Aadhaar Number (12 digits)
2. PAN Number
3. Aadhaar Card Photo upload
4. PAN Card Photo upload
5. Live Selfie capture/upload

## Key User Actions

1. Enter Aadhaar number and click Verify Aadhaar.
2. Enter PAN number and click Verify PAN.
3. Upload Aadhaar and PAN photos (unlocked only after identifier verification).
4. Capture/upload selfie and run face verification flow.
5. Submit using Continue to Step 3.

## Validation Notes

1. Aadhaar and PAN format checks are enforced.
2. Full completion requires both identifiers verified, both docs uploaded, and face verification passed.

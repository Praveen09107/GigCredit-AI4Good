# Step 7 - Insurance Inputs
Source: gigcredit_app/lib/ui/screens/steps/step7_insurance_screen.dart

## Inputs Asked from User

Insurance selection:
1. Health Insurance selected or not
2. Life Insurance selected or not
3. Vehicle Insurance selected or not (required when has_vehicle is true)

Per selected insurance type:
4. Policy Number
5. Policy Holder Name
6. Insurance proof upload

## Key User Actions

1. Select insurance types.
2. Enter policy number and holder name.
3. Upload policy proof.
4. Run OCR and then Verify.
5. Submit using Continue to Step 8.

## Validation Notes

1. Health and Life are optional.
2. Vehicle insurance is mandatory when vehicle ownership is true from Step 1.
3. Holder name is cross-checked against Step 1 normalized profile name.

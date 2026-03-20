# Step 8 - ITR/GST Inputs
Source: gigcredit_app/lib/ui/screens/steps/step8_itr_gst_screen.dart

## Inputs Asked from User

Module selection (both optional):
1. ITR selected or not
2. GST selected or not

If ITR selected:
3. PAN Number
4. Name as per document
5. Annual Income (INR)
6. ITR document upload

If GST selected:
7. PAN Number
8. Name as per document
9. Annual Income (INR)
10. GST document upload

## Key User Actions

1. Select ITR and/or GST modules.
2. Fill PAN, name, and annual income for selected module(s).
3. Upload document.
4. Run OCR and then Verify per module.
5. Submit using Continue to Step 9.

## Validation Notes

1. PAN must match Step 2 PAN.
2. Name must match Step 1 normalized name.
3. Income is validated against tolerance rules relative to Step 3 baseline.

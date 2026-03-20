# GigCredit - All Steps Input List (Step 1 to Step 9)

This document lists the user inputs for each verification step in one place.
It is compiled from the step-wise docs in planning/step_wise_inputs/ and aligned with the latest spec corrections.

## Step 1 - Basic Profile Inputs

1. Full Name
2. Date of Birth
3. Mobile Number
4. Current Address
5. Permanent Address
6. State of Residence
7. Work Type
8. Self-Declared Monthly Income (INR)
9. Years in Current Profession
10. Number of Dependents
11. Vehicle Ownership (Yes/No)
12. Secondary Income Source (optional)
13. Secondary Income Amount (optional)

## Step 2 - Identity (KYC) Inputs

1. Aadhaar Number
2. PAN Number
3. Aadhaar Card Photo upload
4. PAN Card Photo upload
5. Live Selfie capture/upload

## Step 3 - Bank Verification Inputs

### Primary Bank Account
1. Bank Name
2. Account Holder Name
3. Bank Branch Name
4. IFSC Code
5. Account Number
6. Bank Statement upload (PDF, 6 to 12 months)
7. MICR Code (optional)

### Secondary Bank Account (optional)
8. Add Secondary Bank Account toggle
9. Bank Name (secondary)
10. Account Holder Name (secondary)
11. Branch Name (secondary)
12. IFSC Code (secondary)
13. Account Number (secondary)
14. Bank Statement upload (secondary)
15. MICR Code (secondary, optional)

### Optional UPI Section
16. UPI Platform
17. UPI Statement upload

## Step 4 - Utility Bills Inputs

### Mandatory Utility Modules
1. Electricity bill uploads
2. LPG bill uploads
3. Mobile bill uploads

### Optional Utility Modules
4. Rent proof uploads
5. WiFi/Broadband proof uploads
6. OTT subscription proof uploads

## Step 5 - Work Proof Inputs (Dynamic by Work Type)

### Platform Worker
1. Vehicle Number
2. Platform proof upload

### Vendor/Seller
1. SVANidhi ID (optional)
2. FSSAI Number (optional)
3. Vendor work proof upload

### Skilled Tradesperson
1. Skill Certificate ID (optional)
2. FSSAI Number (optional)
3. Trades work proof upload

### Freelancer
1. Freelance platform profile screenshot
2. Client invoice proof upload (minimum one)
3. MSME Certificate upload
4. GST Registration Certificate (if applicable)

## Step 6 - Government Schemes Inputs

All schemes are optional. For selected schemes, IDs/reference fields and proof uploads are required.

1. PM SVANidhi reference + proof upload
2. eShram UAN + proof upload
3. PM-SYM subscriber/reference + proof upload
4. PMJJBY reference/certificate + proof upload
5. PMMY loan reference + proof upload
6. PPF account reference + proof upload
7. Udyam/MSME registration + proof upload (as applicable per spec set)

## Step 7 - Insurance Inputs

Insurance selection:
1. Health Insurance selected or not
2. Life Insurance selected or not
3. Vehicle Insurance selected or not

Per selected insurance type:
4. Policy Number
5. Policy Holder Name
6. Insurance proof upload

## Step 8 - ITR/GST Inputs

Module selection:
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

## Step 9 - EMI/Loan Behavior Inputs

1. Lender Name
2. Monthly EMI Amount (INR)
3. Previous Debit Date
4. Latest Debit Date
5. Optional loan verification API action

## Source Files

1. planning/step_wise_inputs/STEP_1_BASIC_PROFILE_INPUTS.md
2. planning/step_wise_inputs/STEP_2_KYC_INPUTS.md
3. planning/step_wise_inputs/STEP_3_BANK_VERIFICATION_INPUTS.md
4. planning/step_wise_inputs/STEP_4_UTILITIES_INPUTS.md
5. planning/step_wise_inputs/STEP_5_WORK_PROOF_INPUTS.md
6. planning/step_wise_inputs/STEP_6_SCHEMES_INPUTS.md
7. planning/step_wise_inputs/STEP_7_INSURANCE_INPUTS.md
8. planning/step_wise_inputs/STEP_8_ITR_GST_INPUTS.md
9. planning/step_wise_inputs/STEP_9_EMI_LOAN_INPUTS.md

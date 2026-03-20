# Step 3 - Bank Verification Inputs
Source: specification files/GIGCREDIT — USER INPUT COLLECTION SPECIFICATION.txt

## Inputs Asked from User (Spec-Aligned)

### Primary Bank Account
1. Bank Name
2. Account Holder Name
3. Bank Branch Name
4. IFSC Code
5. Account Number
6. Bank Statement upload (PDF, 6 to 12 months)
7. MICR Code (optional)

### Secondary Bank Account (Add Another Account)
8. Enable Secondary Account toggle (Add Secondary Bank Account)
9. Bank Name (secondary)
10. Account Holder Name (secondary)
11. Branch Name (secondary)
12. IFSC Code (secondary)
13. Account Number (secondary)
14. Bank Statement upload (secondary)
15. MICR Code (secondary, optional)

### Optional UPI Section
16. UPI Platform
17. UPI Statement upload (PDF)

## Key User Actions

1. Fill primary bank details and upload primary statement.
2. Click Add Secondary Bank Account to enable same input flow for secondary account.
3. Fill secondary bank details and upload secondary statement (optional but recommended).
4. Add optional UPI platform and UPI statement.
5. Submit for Step 3 verification.

## Validation Notes

1. Secondary account uses the same validation and processing rules as primary account.
2. Multiple uploaded account statements are merged into one transaction stream for scoring.
3. Statement parsing feeds EMI, utility, income, and repayment pattern checks.

# Step 9 - EMI/Loan Behavior Inputs
Source: gigcredit_app/lib/ui/screens/steps/step9_emi_loan_screen.dart

## Inputs Asked from User

1. Lender Name
2. Monthly EMI Amount (INR)
3. Previous Debit Date
4. Latest Debit Date

Additional user-triggered action:
5. Run Optional Loan Verification API Hook

## Key User Actions

1. Enter lender and EMI amount.
2. Select previous and latest debit dates.
3. Optionally run loan verification hook.
4. Submit using Finish 9-Step Verification.

## Validation Notes

1. Lender and EMI amount are validated.
2. Debit dates must satisfy recurring monthly interval rule.
3. DTI and EMI risk band are computed before step completion.

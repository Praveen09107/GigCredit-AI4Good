# Step 1 - Basic Profile Inputs
Source: gigcredit_app/lib/ui/screens/steps/step1_profile_screen.dart

## Inputs Asked from User

1. Full Name
2. Date of Birth (selected via calendar)
3. Mobile Number
4. Current Address
5. Permanent Address
6. State of Residence (dropdown)
7. Work Type (dropdown)
8. Self-Declared Monthly Income (INR)
9. Years in Current Profession
10. Number of Dependents
11. Vehicle Ownership (Yes/No choice chip)
12. Secondary Income Source (optional)
13. Secondary Income Amount (optional)

## Key User Actions

1. Pick date from date picker.
2. Select state and work type from dropdowns.
3. Select vehicle ownership via choice chips.
4. Submit using Continue to Step 2.

## Validation Notes

1. Field-level validation is applied for all mandatory fields.
2. Cross-address relationship validation is applied before step completion.
3. Step cannot complete unless work type, state, and vehicle ownership are selected.

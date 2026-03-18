# Sample Input Extraction Summary (Auto)

## PDF Extraction Status
- Bank Statement.pdf: text extracted
- UPI_gpay_statement.pdf: text extracted

## Parsed Bank Statement Fields (best-effort)
- bank_name: State Bank Of India
- ifsc_code: UTIB0000345
- micr_code: 
- account_number_masked: 
- statement_from_date: 19-09-2025
- statement_to_date: 19-03-2026
- bank_transaction_rows_estimated: 123

## Parsed UPI Statement Fields (best-effort)
- upi_first_date: 
- upi_last_date: 
- upi_txn_rows_estimated: 454

## Pending Manual Image Extraction
- aadhaar front.jpeg
- aadhaar back.jpeg
- pan front.jpeg
- pan back.jpeg

## Notes
- Parsed values are best-effort and need validation against source documents.
- Field-level normalization/mapping to final schema is still pending.

## KYC Image Extraction (Completed This Pass)

- Output file: `sample inputs/kyc_extracted_fields.csv`
- Tracker status updated:
	- `aadhaar front.jpeg` -> `extracted_with_review`
	- `aadhaar back.jpeg` -> `extracted_with_review`
	- `pan front.jpeg` -> `extracted_with_review`
	- `pan back.jpeg` -> `extracted_with_review`

### Confirmation Required from User

- Aadhaar:
	- `aadhaar_number`
	- `gender`
	- `address_line_1`
	- `city_district`

- PAN:
	- `pan_number`
	- `fathers_name`
	- `issuing_unit`
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
- upi_statement_period: 01 September 2025 - 28 February 2026
- upi_reported_sent_total: 79,905.99
- upi_reported_received_total: 57,197.01
- upi_txn_rows_parsed_structured: 407

## Bulk Pending-Set Extraction (Completed This Pass)

- Source set processed: all `pending` rows from tracker (34 files)
- New outputs:
	- `sample inputs/remaining_docs_extracted_fields.csv`
	- `sample inputs/remaining_docs_ocr_summary.json`
- Total extracted candidate rows: 105
- Tracker status after run:
	- `extracted_with_review`: 34
	- `partial_extracted`: 6
	- `pending`: 0

## Deep Pass Completion (Bank/UPI + Residual Partials)

- New normalized outputs:
	- `sample inputs/bank_statement_structured.csv` (123 rows)
	- `sample inputs/upi_statement_structured.csv` (407 rows)
	- `sample inputs/upi_statement_summary.csv` (statement totals + parsed row count)
- UPI parse quality fix applied:
	- removed phone-number bleed into `amount` field (e.g., `7010049092`)
	- corrected debit/credit split using `Paid to` vs `Received from` transaction details
- Residual manual-field output:
	- `sample inputs/partial_docs_manual_extracted_fields.csv`
- Tracker status after deep pass:
	- `extracted_with_review`: 39
	- `needs_user`: 1
	- `partial_extracted`: 0

## Notes
- Parsed values are best-effort and need validation against source documents.
- Remaining blocker from user side: `pm sym template card no values.jpeg` appears to be a blank template and needs a filled version.

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
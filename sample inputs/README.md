# Sample Inputs Drop Folder

Place sample OCR inputs here for manual extraction and template finalization.

## Accepted formats
- PNG/JPG/JPEG
- PDF (preferred non-password protected)

## Recommended file naming
Use this format:

`<docType>__<side_or_part>__<caseId>__<seq>.<ext>`

Examples:
- `aadhaar__front__case001__01.png`
- `aadhaar__back__case001__02.png`
- `pan__front__case001__01.jpg`
- `bank_statement__primary__case001__01.pdf`
- `electricity_bill__latest__case001__01.pdf`

## Provide manifest
Please fill `input_manifest_template.csv` in this folder with one row per file.

## Notes
- Avoid sharing unrelated sensitive pages where possible.
- Password-protected PDFs should include password in a separate secure message.
- Very low-resolution or heavily blurred images may require manual field confirmation.

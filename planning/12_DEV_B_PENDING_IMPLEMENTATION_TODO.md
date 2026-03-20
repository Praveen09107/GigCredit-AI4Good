# Dev B Pending Implementation TODO (Cross-Verified)

Date: 2026-03-18
Owner: Dev B
Purpose: Single remaining-action list after cross-checking plan vs code.

## 1) Strict Plan Pending (Section M, blocked on Dev A handoff)

- [ ] Integrate scorer files from Dev A handoff (`p1..p6 generated scorers`)
- [ ] Run scorecards (P5/P7/P8) with finalized Dev A definitions
- [ ] Apply confidence handling using Dev A scorer output metadata
- [ ] Final LR score computation (300-900) with Dev A LR coefficients

## 2) Dev B Hardening Pending (Mock-to-Real migration)

These are implemented as mock-first flows and work for prototype validation, but remain pending for production-level completion.

- [ ] Replace login OTP mock with real OTP service wiring
- [ ] Replace Step-3 parser mock output with real statement parsing pipeline
- [ ] Replace Step-4 utility verify mock checks with real verification logic/API integration
- [ ] Replace Step-6 OCR/verify mock functions with real OCR + verification integration
- [ ] Replace Step-7 OCR/verify mock functions with real OCR + verification integration
- [ ] Replace Step-8 OCR/verify mock functions with real OCR + verification integration
- [ ] Replace Step-8 monthly baseline prototype estimator with final engineered baseline logic
- [ ] Replace Step-9 optional loan API mock hook with real backend verification call
- [ ] Replace report export hook with real PDF generation and share flow
- [ ] Finalize Step-5 freelancer placeholder path into full validation module

## 3) Already Cross-Verified as Working

- [x] Steps 1-9 route flow and state progression
- [x] Upload buttons now open real file picker (Steps 2-8)
- [x] Offline queue/retry wiring is connected (online-first, offline-fallback)
- [x] Session persistence and recovery wiring
- [x] Report generation screen flow and language selection wiring
- [x] Analyzer clean on current codebase
- [x] App launched successfully on physical Android device

## 4) Acceptance Definition for "Dev B Fully Complete"

Dev B can be marked fully complete when all items in sections 1 and 2 are checked.

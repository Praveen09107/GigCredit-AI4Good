# Dev B Pending External TODO Table (2026-03-19)

This file tracks only items that cannot be fully closed by local code edits.

| ID | Area | Pending Item | Owner | Blocking For | Status | Evidence Needed |
|---|---|---|---|---|---|---|
| EXT-01 | Mobile ML Assets | Add production model binaries to `gigcredit_app/assets/models/` (`efficientnet_lite0.tflite`, `mobilefacenet.tflite`). | ML/Android | Real on-device inference in release runtime | OPEN | File checksums + app startup log showing model load success |
| EXT-02 | Backend Deploy | Deploy FastAPI backend and provide production URL for app runtime. | Backend/DevOps | Production-mode verification calls | OPEN | Live health endpoint response + deploy config snapshot |
| EXT-03 | Secrets | Configure real Mongo credentials (replace placeholder password in runtime secret store). | DevOps/Security | Persistent verification/report audit logs in production | OPEN | Secret manager entry + sanitized runtime env proof |
| EXT-04 | Device QA | Run physical-device E2E flow (Step1 -> Step9 -> Report generation) with strict mode enabled. | QA/Android | Production signoff | OPEN | Video/screenshots + logs + filled gate checklist |
| EXT-05 | Release Hardening | Resolve remaining non-blocking Flutter analyze warnings/info backlog. | App Team | Quality gate tightening | OPEN | Updated analyze report with reduced issue count |

## Notes
- All code-feasible integration tasks from the current TODO were completed and validated locally.
- This table is the remaining handoff list for infra/assets/device-release closure.

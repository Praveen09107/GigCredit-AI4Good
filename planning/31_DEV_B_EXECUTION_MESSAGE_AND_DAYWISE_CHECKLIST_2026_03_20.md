# 31) Dev B Execution Message and Day-wise Checklist (2026-03-20)

Use this message as-is for Dev B.  
Status baseline is aligned to `planning/24_DEV_A_TO_DEV_B_PRODUCTION_HANDOFF_SIGNOFF_CHECKLIST.md`.

---

## A) Ready-to-send message (copy/paste)

Subject: Dev B Execution Plan — Integration Validation + Remaining Production Closures

Hi Dev B,

Dev A handoff is now pushed to `main` and integration artifacts are ready for your pull and validation.

### Commit baseline
- `9db4391` — Dev A handoff artifacts, tooling, docs
- `aadc0f7` — repo ignore hygiene

### Current closure snapshot
- Checklist PASS: 20/29
- Remaining: 9 (BLOCKED/FAIL)
- Dev B/joint focus: B4, C4, plus post-pull runtime/deployment evidence closure

### Your immediate execution sequence
1. Pull latest main.
2. Run deterministic scoring + SHAP parity checks using handoff goldens.
3. Validate startup/runtime behavior in strict path once runtime binaries are available.
4. Attach post-pull report with evidence and blockers.
5. Update row statuses in `planning/24_DEV_A_TO_DEV_B_PRODUCTION_HANDOFF_SIGNOFF_CHECKLIST.md`.

Please follow the day-wise checklist below and report completion with: commit SHA, PASS/FAIL per item, blockers, and ETA.

Thanks.

---

## B) Day-wise checklist (owner-tagged)

## Day 0 — Pull + baseline validation

- [ ] **[Dev B]** Pull latest:
  - `git fetch origin`
  - `git checkout main`
  - `git pull --ff-only origin main`
- [ ] **[Dev B]** Record baseline SHA in report.
- [ ] **[Dev B]** Review these docs before execution:
  - `planning/22_DEV_B_RUNTIME_INTEGRATION_VALIDATION_PACK.md`
  - `planning/25_DEV_A_INTEGRATION_RELEASE_NOTES.md`
  - `planning/24_DEV_A_TO_DEV_B_PRODUCTION_HANDOFF_SIGNOFF_CHECKLIST.md`

## Day 1 — Determinism + explainability parity

- [ ] **[Dev B]** Validate scorer determinism against:
  - `offline_ml/data/golden_inference_pack.json`
  - `offline_ml/data/scoring_tolerance_policy.json`
- [ ] **[Dev B]** Validate SHAP runtime parity against:
  - `offline_ml/data/shap_golden_examples.json`
  - `offline_ml/data/shap_lookup.json`
- [ ] **[Dev B + Dev A]** Close checklist row `B4` if factor consistency is verified.
- [ ] **[Dev B + Dev A]** Close checklist row `C4` if confidence/fallback behavior matches freeze spec.

## Day 2 — Runtime readiness (strict mode path)

Dependency: runtime binaries must be delivered first:
- `gigcredit_app/assets/models/efficientnet_lite0.tflite`
- `gigcredit_app/assets/models/mobilefacenet.tflite`

- [ ] **[Dev A/ML owner]** Place required runtime binaries in `gigcredit_app/assets/models/`.
- [ ] **[Dev B]** Validate runtime files + manifest block in:
  - `gigcredit_app/assets/constants/artifact_manifest.json`
- [ ] **[Dev B]** Run:
  - `python -m offline_ml.src.check_production_readiness`
- [ ] **[Dev B]** Validate runtime health flags all true:
  - `ocrRuntimeAvailable`
  - `tfliteRuntimeAvailable`
  - `authenticityModelAvailable`
  - `faceModelAvailable`
- [ ] **[Dev B]** Attach no-fallback proof in strict mode.

## Day 3 — QA/deployment closure

Dependency: deployed backend URL and QA environment access.

- [ ] **[Release + Dev B]** Confirm deployed backend URL and set app env.
- [ ] **[Dev B + QA]** Validate deployed auth/rate-limit behavior.
- [ ] **[QA]** Execute physical-device E2E and attach evidence.
- [ ] **[QA]** Execute report-generation E2E against deployed backend and attach evidence.
- [ ] **[Release Lead]** Update checklist rows `E1`, `E3`, `F5`, `F6` with evidence links.

## Day 4 — Final signoff decision

- [ ] **[Release Lead]** Verify all checklist rows PASS.
- [ ] **[Release Lead]** Move gates `G1`→`G4` to PASS in:
  - `planning/24_DEV_A_TO_DEV_B_PRODUCTION_HANDOFF_SIGNOFF_CHECKLIST.md`
- [ ] **[Dev B]** Submit final post-pull runtime validation report.

---

## C) Dev B report template (mandatory)

```markdown
## Dev B Post-Pull Validation Report

### Pull State
- branch: main
- commit: <sha>

### Determinism
- golden inference parity: PASS/FAIL
- tolerance policy checks: PASS/FAIL

### SHAP
- golden SHAP parity: PASS/FAIL
- top-factor consistency: PASS/FAIL

### Runtime Health (strict path)
- ocrRuntimeAvailable: true/false
- tfliteRuntimeAvailable: true/false
- authenticityModelAvailable: true/false
- faceModelAvailable: true/false
- no-fallback proof attached: yes/no

### Deployed Environment
- backend base URL validated: yes/no
- auth/rate-limit in deployed env: PASS/FAIL
- physical-device E2E: PASS/FAIL
- report generation E2E: PASS/FAIL

### Checklist Rows Updated
- <row-id>: PASS/FAIL/BLOCKED (evidence)

### Blockers + ETA
- <blocker>
```

---

## D) Fast ownership map (for escalation)

- **Dev A**: artifacts/scripts/docs, model contract, evidence generation
- **Dev B**: post-pull integration validation, runtime verification, checklist updates
- **QA**: physical-device + deployed E2E evidence
- **Release Lead**: final gate decisions (G1–G4)

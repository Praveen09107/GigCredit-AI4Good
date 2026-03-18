# GigCredit — Verification of Copilot Findings vs Your Specs (Repo Truth)

This document cross-checks the issues listed by Copilot against the **actual** GigCredit specs in this repo, especially:

- `specification files/COMPREHENSIVE FIXES AND ADDITIONS — ALL IDENTIFIED ISSUES AND RESOLUTIONS.txt`
- `specification files/Input_fields_final (1).txt`
- `specification files/REVISED — SCORING ENGINE ARCHITECTURE ... v4.0` (this is aligned with the chosen **pure Dart via m2cgen** scoring deployment)

## Legend
- **Fixed (in your specs)**: already resolved and specified in your “Comprehensive Fixes” doc (or newer authoritative doc).
- **Open (needs spec freeze decision / edits)**: still contradictory across spec files and must be unified.
- **Partially fixed**: direction exists, but needs final authoritative wording + implementation detail.

---

## 1) Critical contradictions

### A) Final score computation: Logistic Regression meta-learner vs weighted sum
- **Copilot claim**: conflict exists.
- **Repo truth**: **Yes, conflict exists across older files.**
  - The report pipeline spec still describes a weighted-sum computation:
    - `specification files/MASTER PROMPT — MODEL OUTPUT TO EXPLAINABLE MULTILINGUAL CREDIT REPORT PIPELINE.txt` (see the “PHASE-2 FINAL CREDIT SCORE COMPUTATION” weighted-sum section)
  - Your “Comprehensive Fixes” doc explicitly resolves this:
    - **FIX-A1**: “Logistic Regression meta-learner is the ONLY method. Weighted sum is DELETED…”
      - `specification files/COMPREHENSIVE FIXES AND ADDITIONS — ... .txt`
- **Status**: **Open (needs propagation)** — resolution exists, but the weighted-sum text still exists in at least one master spec and must be removed/overridden by the frozen spec.

### B) Meta-learner input dimension mismatch (5 vs 20)
- **Copilot claim**: conflict exists.
- **Repo truth**: **Yes, conflict existed; your Fixes doc resolves it.**
  - **FIX-A3** defines the canonical 20-input LR (8 pillars + 4 one-hot + 8 interactions).
- **Status**: **Fixed (in your specs), but needs propagation** to any older docs still mentioning 5 inputs.

### C) Sequential vs parallel execution (isolates)
- **Copilot claim**: conflict exists.
- **Repo truth**: **Yes, conflict existed; your Fixes doc resolves it.**
  - **FIX-A2**: sequential execution; no isolate requirement.
- **Status**: **Fixed (in your specs), but needs propagation**.

### D) Pillar count 7 vs 8 in UI
- **Copilot claim**: mismatch.
- **Repo truth**: **Yes, mismatch existed; fixed.**
  - **FIX-D1**: report screen must show **8 pillars**.
- **Status**: **Fixed (in your specs)**.

### E) Step count 8 vs 9 (EMI auto-analysis)
- **Copilot claim**: mismatch.
- **Repo truth**: **Yes, mismatch existed; fixed.**
  - **FIX-A4**: 8 user-facing steps + 1 automated EMI analysis step (not in progress bar).
- **Status**: **Fixed (in your specs)**.

---

## 2) Implementation gaps

### A) PDF report generation spec missing
- **Copilot claim**: missing.
- **Repo truth**: **Was missing; now added.**
  - **FIX-B1**: on-device PDF generation using Dart `pdf` + `share_plus`.
- **Status**: **Fixed (in your specs)**.

### B) Offline mode strategy missing
- **Copilot claim**: missing.
- **Repo truth**: **Was missing; now added.**
  - **FIX-B2** defines Tier-1 offline-safe vs Tier-2 API-required steps and a pending verification state.
- **Status**: **Fixed (in your specs)**.

### C) MongoDB schema shallow
- **Copilot claim**: shallow.
- **Repo truth**: **Was shallow; your Fixes doc formalizes schemas + TTL/index ideas.**
  - **FIX-E1** defines fields + TTL guidance.
  - Additionally, your `planning/1_GIGCREDIT_FULL_IMPLEMENTATION_PLAN.md` already lists Pydantic models and TTL index creation in the backend build steps.
- **Status**: **Partially fixed** — schema direction exists; we’ll freeze final schema + PII-minimization decisions (e.g., Aadhaar last-4 vs hash) as part of `backend-hardening`.

### D) API authentication not specified
- **Copilot claim**: missing.
- **Repo truth**: **Was missing; now added.**
  - **FIX-B4**: API key + device ID + HMAC signature + replay window + rate limits.
- **Status**: **Fixed (in your specs)** (and we’ll reconcile with the simpler API-key-only approach in `planning/1_...`).

### E) Multi-language OCR not addressed
- **Copilot claim**: missing.
- **Repo truth**: **Partially addressed in Fixes.**
  - **FIX-B8**: practical approach: ship English OCR model; optionally run regional model if needed (stretch).
- **Status**: **Partially fixed** — your chosen MVP is English-first; we’ll freeze exactly what is supported in v1 and how to message limitations.

### F) Bank statement PDF parsing (password, stitching) missing
- **Copilot claim**: missing.
- **Repo truth**: **Added in Fixes.**
  - **FIX-B7**: password prompt, digital-vs-scan detection, PDF->image, deduplication.
- **Status**: **Fixed (in your specs)**.

### G) Session recovery / crash handling missing
- **Copilot claim**: missing.
- **Repo truth**: **Added in Fixes.**
  - **FIX-B3**: encrypted session persistence + resume + expiry.
- **Status**: **Fixed (in your specs)**.

### H) Model versioning / update strategy missing
- **Copilot claim**: missing OTA strategy.
- **Repo truth**: **Not fully specified**, and you confirmed **no OTA** for MVP.
- **Status**: **Open (by design for MVP)** — we will explicitly freeze: “model updates only via app update” and add version identifiers for reproducibility.

---

## 3) Logical errors / risks

### A) Confidence engine collapsing to 0.50
- **Copilot claim**: neutral score for no data is bad.
- **Repo truth**: **You already fixed this.**
  - **FIX-A7**: minimum data requirements + refuse-to-score gate + confidence floor behavior.
- **Status**: **Fixed (in your specs)**.

### B) Face verification review state undefined
- **Copilot claim**: review undefined.
- **Repo truth**: **You already fixed this.**
  - **FIX-A6**: auto-retry and reduced confidence behavior; reject threshold.
- **Status**: **Fixed (in your specs)**.

### C) “SHAP approximation” accuracy concern
- **Copilot claim**: linear approximation is inaccurate for trees.
- **Repo truth**: **Copilot is right as a *risk*, but your docs intentionally accept an approximation.**
  - Your revised approach uses **binned SHAP lookup tables** (more faithful) in the scoring v4.0 doc.
  - Some older docs describe a simpler linear formula.
- **Status**: **Open (needs freeze)** — we’ll lock the explainability mechanism to one approach and document limitations clearly.

### D) Transaction tagging underspecified
- **Copilot claim**: keyword-only is brittle.
- **Repo truth**: **Already improved in Fixes.**
  - **FIX-C1**: enhanced 4-layer tagging engine with patterns + heuristics + uncategorized fallback.
- **Status**: **Fixed (in your specs)**.

### E) Income anchor assumes single state
- **Copilot claim**: multi-state workers.
- **Repo truth**: **Already improved in Fixes.**
  - **FIX-C2**: choose anchor by work city/state evidence order; fallback to Step-1.
- **Status**: **Fixed (in your specs)**.

---

## Bottom line
Copilot identified real issues, but **your own “Comprehensive Fixes” doc already resolves the majority**. The remaining work is mainly **spec propagation + freezing one canonical scoring + explainability design**, with the final decision being **XGBoost/RF exported to pure Dart via m2cgen** (no TFLite scoring runtime).


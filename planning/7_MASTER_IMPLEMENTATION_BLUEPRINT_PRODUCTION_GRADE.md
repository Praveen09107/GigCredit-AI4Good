# GigCredit Master Implementation Blueprint (Production-Grade Draft)

Status: **Authoritative working draft**  
Date: 2026-03-18  
Audience: Core builders, reviewers, AI coding agents

---

## 1) Purpose

This document is the single execution blueprint that consolidates planning + specification files into one contradiction-resolved implementation path for hackathon delivery and production-grade architecture quality.

Use this as the **primary planning source** for implementation sequencing, freeze decisions, acceptance gates, and quality bar.

---

## 2) Canonical Source Priority (Read in this order)

1. `planning/7_MASTER_IMPLEMENTATION_BLUEPRINT_PRODUCTION_GRADE.md` (this file)
2. `planning/1_SCORING_ENGINE_SPEC_FREEZE.md`
3. `planning/3_END_TO_END_WORKFLOW_FREEZE.md`
4. `planning/2_BACKEND_HARDENING_SPEC.md`
5. `specification files/REVISED — SCORING ENGINE ARCHITECTURE (SUPERSEDES ML WORKFLOW + PHASE-2 + PHASE-3 SCORING SECTIONS).txt`

If any older file conflicts with the above order, this order wins.

---

## 3) Product Definition (Frozen)

GigCredit is an India-focused, privacy-first, alternative-credit mobile system for gig workers.

- User-facing flow: **8 steps**
- Internal flow: **1 silent step** (EMI auto-analysis after bank parsing)
- Score range: **300–900**
- Pillars: **8 pillars**
- Runtime scoring location: **on-device only**
- Backend role: **verification + report generation + optional report storage**, not score computation

---

## 4) Non-Negotiable Architecture Decisions

1. **Final score method**: logistic-regression meta-learner only (44 inputs), not weighted-sum final score.
2. **On-device scoring**: all feature engineering and scoring are local in Flutter/Dart.
3. **Model deployment**: m2cgen-generated Dart for ML pillars; no runtime model downloading.
4. **Step model**: 8 user-visible steps + 1 internal automated EMI step.
5. **Minimum scoring gate**:
   - Step 1 completed
   - Step 2 identity verified
   - Step 3 bank statement parsed with at least 30 transactions
6. **Backend trust boundary**: backend receives verified fields/identifiers for verification and reporting; raw OCR documents stay local unless explicitly required by a specific endpoint contract.

---

## 5) Scoring Contract (Frozen)

### 5.1 Pillars
- P1 Income Stability
- P2 Payment Discipline
- P3 Debt Management
- P4 Savings Behaviour
- P5 Work & Identity (scorecard)
- P6 Financial Resilience
- P7 Social Accountability (scorecard)
- P8 Tax Compliance (scorecard)

### 5.2 Feature vector
- Length: 95 normalized features in [0, 1]
- Slicing:
  - P1: [0:13]
  - P2: [13:28]
  - P3: [28:37]
  - P4: [37:49]
  - P5: [49:67]
  - P6: [67:78]
  - P7: [78:88]
  - P8: [88:95]

### 5.3 Meta-learner input (44)
- 8 adjusted pillar scores
- 4 work-type one-hot values
- 32 interaction terms (all 8 pillars × 4 work types)

### 5.4 Final score formula
- Probability: sigmoid(dot(input44, coefficients44) + intercept)
- Score: round(300 + probability × 600)
- Clamp: [300, 900]
- Risk bands:
  - 300–450 High
  - 451–650 Medium
  - 651–900 Low

---

## 6) Mandatory Artifact Handoff (Dev A → Dev B)

All files must exist before integration lock:

1. `p1_scorer.dart`
2. `p2_scorer.dart`
3. `p3_scorer.dart`
4. `p4_scorer.dart`
5. `p6_scorer.dart`
6. `shap_lookup.json`
7. `meta_coefficients.json`
8. `state_income_anchors.json`
9. `feature_means.json`

Handoff gate:
- All 9 artifacts present
- Flutter app loads all assets without runtime failure
- Score parity check passes against Python reference set

---

## 7) Failure-Handling Matrix (Condensed Freeze)

### 7.1 Step 2 (Identity)
- Face similarity below reject threshold: block step, allow retry budget, then mark unresolved if exhausted.
- PAN/Aadhaar mismatch: block scoring until resolved.

### 7.2 Step 3 (Bank)
- < 30 transactions: do not compute score, show insufficient-data action.
- Parsing failures: allow re-upload and alternate statement format route.

### 7.3 Optional steps (4–8)
- Missing optional inputs reduce confidence; should not hard-block if minimum gate is satisfied.

### 7.4 Backend unavailable
- Queue verification/report requests and retry on reconnect.
- Local state remains resumable.

---

## 8) Team Execution Blueprint (Hackathon-Optimized)

## Phase A: Foundation and interfaces (Hour 0–2)
- Dev A publishes API/AI interfaces + mock implementations.
- Dev B starts UI/state routing immediately without backend wait.
- Gate: app compiles with mocks + route skeleton complete.

## Phase B: Parallel core build (Hour 2–16)
- Dev A: backend endpoints + offline ML pipeline + artifact generation.
- Dev B: step screens, profile model, secure session, upload components, parser stubs.
- Gate: Dev B can run entire user journey with mock + partial real integrations.

## Phase C: Scoring and explainability lock (Hour 16–30)
- Dev B integrates artifacts, scoring engine, confidence engine, SHAP summaries.
- Dev A validates parity and endpoint stability.
- Gate: deterministic scoring and explainability pass golden profiles.

## Phase D: Reporting and hardening (Hour 30–42)
- LLM report generation + multilingual output + PDF generation.
- Error/fallback handling, cooldown policy, storage queue.
- Gate: full flow from onboarding to downloadable report passes without crashes.

## Phase E: Final QA and demo readiness (Hour 42–48)
- End-to-end scenario runs, edge-case validation, latency checks, demo script.
- Gate: production-grade demo confidence achieved.

---

## 9) Priority Gaps to Fix Immediately (Actionable)

### P0
1. Confirm P5 feature count and enforce fixed index map in code and docs.
2. Ensure `state_income_anchors.json` and `feature_means.json` are generated and shipped.
3. Mark outdated scoring docs as superseded to avoid wrong implementation path.
4. Freeze API/AI interface stubs at project start to prevent team blocking.

### P1
1. Freeze explainability implementation method (binned SHAP lookup only).
2. Add explicit transaction tagging rules (multi-layer with deterministic fallback).
3. Standardize failure outcomes across all steps into one table used by UI and logic.

---

## 10) Definition of Done (Hackathon + Production-Grade Prototype)

1. User can finish 8-step workflow with persistence and resume.
2. Minimum gate correctly controls score eligibility.
3. Final score generation is deterministic and bounded in [300, 900].
4. Pillar outputs and top drivers are shown coherently.
5. Multilingual report is generated and PDF is shareable.
6. Offline/online transitions do not lose state.
7. End-to-end demo run completes without crash.

---

## 11) Change Control Rule

Any future spec change must include:
- reason,
- impacted files,
- migration impact,
- freeze decision status,
- owner approval.

Without this, the change is informational only and not implementation-authoritative.

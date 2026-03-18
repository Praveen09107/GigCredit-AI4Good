# Dev A QA, Handoff, and Change-Control Plan (Detailed)

Owner: Dev A  
Scope: Cross-cutting quality gates for backend, ML, AI deliverables  
Stage: Pre-implementation review draft

---

## 1) Objective

Prevent integration regressions and planning drift by enforcing explicit quality gates, formal handoffs, and strict change control before coding divergence occurs.

---

## 2) Handoff gates

## Gate A (Hour ~2): Interface Unblock Gate
Deliver to Dev B:
- API interface + mock client
- AI interfaces + mock document processor

Pass condition:
- Dev B confirms integration compiles and can proceed with steps UI.

## Gate B (Hour ~8-12): Backend Contract Gate
Deliver:
- endpoint path map,
- auth header requirements,
- sample responses,
- base URL/local URL.

Pass condition:
- Dev B can switch from mock to real backend with minimal wiring changes.

## Gate C (Day-1 end / Day-2 start): Artifact Contract Gate
Deliver:
- finalized artifact names,
- schema definitions,
- loading paths,
- parity report status.

Pass condition:
- Dev B scorer and explainability modules can load artifacts without ambiguity.

---

## 3) QA checklist by stream

### 3.1 Backend QA
- all endpoints return standard envelope,
- auth validation tested for pass/fail/replay,
- rate limiting tested,
- report fallback tested.

### 3.2 Offline ML QA
- script chain reproducible,
- artifacts generated with deterministic names,
- parity checks recorded.

### 3.3 AI QA
- interfaces stable,
- mocks reliable,
- error paths non-crashing,
- performance within acceptable bounds.

---

## 4) Joint integration test set (Dev A + Dev B)

Minimum shared tests:
1. Step-2 verification flow with mock and real backend switches.
2. Step-3 bank verification path with response edge cases.
3. Report generation call with language variants and fallback.
4. Scorer artifact loading path verification.

Documentation rule:
- every failed integration test gets issue note with owner and target fix hour.

---

## 5) Change-control protocol

Any contract change requires:
1. changed file and symbol list,
2. impact summary,
3. migration note for Dev B,
4. approval acknowledgement.

No silent contract changes allowed on:
- endpoint paths,
- request/response envelope,
- artifact names/schema,
- interface method signatures.

---

## 6) Risk register (Dev A owned)

P0 risks:
- endpoint contract instability,
- artifact schema mismatch,
- scoring export incompatibility.

P1 risks:
- delayed deployment availability,
- LLM response schema drift.

P2 risks:
- non-critical performance regressions.

Mitigation rule:
- P0 must block release to integration branch,
- P1 must have workaround documented,
- P2 can be deferred with explicit note.

---

## 7) Daily reporting format

At end of day send one concise update with:
- completed items,
- blocked items,
- new risks,
- tomorrow priorities,
- whether integration gates remain green.

---

## 8) Definition of ready-to-implement (for your approval)

Implementation starts only when:
- all Day-1 plan docs approved,
- Gate A requirements are feasible and accepted,
- no unresolved P0 spec conflict remains,
- handoff format with Dev B agreed.

---

## 9) Definition of done (Dev A side)

Dev A done means:
- backend stable and contract-frozen,
- ML artifact pipeline reproducible,
- AI interface layer stable with mocks/real implementation path,
- QA evidence captured,
- handoff docs current and accepted by Dev B.

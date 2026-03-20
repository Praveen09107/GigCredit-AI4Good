# 32) Dev A Scoring TFLite Export and Parity Execution Plan

Last Updated: 2026-03-20  
Owner: Dev A (ML owner)  
Scope: Convert/export the main scoring model to `.tflite`, freeze runtime contracts, and deliver parity/checksum evidence for Dev B integration.

---

## 1) Objective and ownership split

## Objective
Deliver a production-ready scoring runtime artifact in TFLite format with deterministic behavior and complete handoff evidence.

## Ownership
- Dev A (ML owner): architecture decision, model export, contracts, parity evidence, release artifacts.
- Dev B: app runtime wiring, on-device integration, startup/runtime validation, post-pull evidence.
- QA/Release: deployed environment/device evidence and final signoff.

---

## 2) Architecture decision gate (must pass first)

Current repo scoring is based on generated Dart scorers (`gigcredit_app/lib/scoring/generated/`).
Before any TFLite work, Dev A must choose one architecture and freeze it:

- Path A (TFLite scoring): migrate scoring runtime to `.tflite` model inference.
- Path B (current architecture): keep generated Dart scorers and do not introduce TFLite for scoring.

## Decision output (required)
Create and publish a short decision note containing:
- chosen path,
- rationale,
- migration impact,
- rollback strategy,
- signoff names/date.

No implementation begins until this decision is approved.

---

## 3) Contract freeze (preprocessing and postprocessing)

Dev A must freeze and version two contracts before export:

## 3.1 Preprocessing contract
- canonical feature list and order (95 features),
- input tensor shape and dtype,
- missing-value policy,
- clipping/capping rules,
- scaling/normalization rules,
- categorical encoding rules,
- any default fill values.

## 3.2 Postprocessing contract
- model output schema,
- probability calibration policy,
- score mapping formula,
- risk band cutoffs,
- confidence/fallback behavior,
- strict-mode failure policy.

## Required artifacts
- `offline_ml/data/feature_contract_freeze.json` (update if scoring path changes)
- `offline_ml/data/scoring_tolerance_policy.json` (update for TFLite tolerances)
- new contract file: `offline_ml/data/scoring_tflite_contract.json`

---

## 4) Export implementation plan (Dev A)

## 4.1 Scripts to add/update
- Add: `offline_ml/src/export_scoring_to_tflite.py`
- Add: `offline_ml/src/validate_scoring_tflite_parity.py`
- Update: `offline_ml/src/package_runtime_models_for_app.py` (include scoring model packaging)
- Update: `offline_ml/src/check_production_readiness.py` (include scoring model required checks)

## 4.2 Expected scoring runtime artifact
- `gigcredit_app/assets/models/scoring_model_v1.tflite`

## 4.3 Manifest update
Update:
- `gigcredit_app/assets/constants/artifact_manifest.json`

Add metadata fields for scoring model:
- `model_name`,
- `semantic_version`,
- `sha256`,
- `input_shape`,
- `input_dtype`,
- `output_schema`,
- `preprocessing_contract_version`,
- `postprocessing_contract_version`,
- `runtime_compatibility`.

---

## 5) Parity validation plan (mandatory evidence)

## 5.1 Golden pack generation
Create/update:
- `offline_ml/data/golden_inference_pack.json`

Must include:
- deterministic feature vectors,
- expected reference outputs,
- expected mapped credit score,
- test-case IDs.

## 5.2 Parity checks
Run parity between reference scorer path and TFLite path:
- probability delta within tolerance,
- final score delta within tolerance,
- risk band match consistency,
- no systematic drift by segment.

## 5.3 Evidence artifacts
- `offline_ml/data/scoring_tflite_parity_report.json`
- `offline_ml/data/scoring_release_metadata.json` (updated for TFLite release)

Acceptance:
- parity report status PASS,
- no threshold violations,
- reproducible command log captured.

---

## 6) Integrity and release packaging

## 6.1 Checksum generation
Compute SHA256 for `scoring_model_v1.tflite` and write into:
- `gigcredit_app/assets/constants/artifact_manifest.json`
- `offline_ml/data/scoring_release_metadata.json`

## 6.2 Rollback package
Create N-1 stable fallback for scoring runtime:
- `offline_ml/data/rollback_bundle_manifest_n_minus_1.json`
- `offline_ml/data/rollback_bundle_n_minus_1/`

## 6.3 Bundle refresh
Run evidence bundling step and ensure all reports are present in:
- `offline_ml/data/production_handoff_bundle.json`

---

## 7) Dev A execution sequence (commands)

Run from repo root after environment activation.

1. Train/finalize model reference path:
- `python -m offline_ml.src.train_final`
- `python -m offline_ml.src.train_meta_learner`

2. Evaluate and baseline checks:
- `python -m offline_ml.src.evaluate_real_ready`
- `python -m offline_ml.src.validate_export`

3. Export and validate TFLite scoring path:
- `python -m offline_ml.src.export_scoring_to_tflite`
- `python -m offline_ml.src.validate_scoring_tflite_parity`

4. Package and readiness checks:
- `python -m offline_ml.src.package_runtime_models_for_app`
- `python -m offline_ml.src.check_production_readiness`
- `python -m offline_ml.src.build_handoff_evidence_bundle`

5. Optional orchestration wrapper:
- `powershell -ExecutionPolicy Bypass -File offline_ml/scripts/finalize_artifact_handoff.ps1`

---

## 8) Dev A handoff package to Dev B

Dev A must provide all of the following:

- scoring runtime model:
  - `gigcredit_app/assets/models/scoring_model_v1.tflite`
- updated manifest with checksum and schema:
  - `gigcredit_app/assets/constants/artifact_manifest.json`
- contracts:
  - `offline_ml/data/scoring_tflite_contract.json`
  - `offline_ml/data/feature_contract_freeze.json`
  - `offline_ml/data/scoring_tolerance_policy.json`
- parity evidence:
  - `offline_ml/data/scoring_tflite_parity_report.json`
  - `offline_ml/data/golden_inference_pack.json`
- release metadata:
  - `offline_ml/data/scoring_release_metadata.json`

---

## 9) Acceptance gates (must all pass)

Gate A: Architecture decision approved.  
Gate B: preprocessing/postprocessing contracts frozen and versioned.  
Gate C: scoring TFLite model exported and checksum-published.  
Gate D: parity report PASS against golden pack.  
Gate E: production readiness check PASS for strict runtime mode.  
Gate F: Dev B post-pull integration report PASS (or explicit external blocker with owner).

If any gate fails, release status remains BLOCKED.

---

## 10) Risks and mitigations

Risk 1: direct export infeasible from current non-TF model stack.  
Mitigation: architecture decision gate and explicit Path A/Path B signoff.

Risk 2: parity drift after conversion/quantization.  
Mitigation: strict parity tolerances + segment-level drift checks + rollback package.

Risk 3: app runtime mismatch (shape/dtype/normalization).  
Mitigation: contract freeze + startup health checks + Dev B integration validation pack.

---

## 11) Definition of done (Dev A)

Dev A is done only when:
- scoring `.tflite` artifact is committed in app model assets,
- contracts are frozen and versioned,
- manifest checksum and schema metadata are complete,
- parity evidence is PASS,
- rollback bundle exists,
- Dev B has complete integration handoff package.

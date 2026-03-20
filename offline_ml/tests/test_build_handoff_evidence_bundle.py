import json
import hashlib
import tempfile
import unittest
from pathlib import Path

from offline_ml.src.build_handoff_evidence_bundle import build_bundle


class BuildHandoffEvidenceBundleTests(unittest.TestCase):
    def _write_json(self, path: Path, payload: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")

    def test_builds_bundle_with_runtime_file_evidence(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            model_path = root / "models" / "efficientnet_lite0.tflite"
            model_path.parent.mkdir(parents=True, exist_ok=True)
            payload = b"runtime-model"
            model_path.write_bytes(payload)
            expected_sha = hashlib.sha256(payload).hexdigest()

            eval_report = root / "real_ready_evaluation_report.json"
            handoff_report = root / "runtime_model_handoff_report.json"
            manifest = root / "artifact_manifest.json"
            contract = root / "runtime_model_contract.json"
            output = root / "production_handoff_bundle.json"

            self._write_json(
                eval_report,
                {
                    "production_gate": {"pass": True},
                    "stress_test": {"gate": {"pass": True}},
                    "test_metrics": {"roc_auc": 0.98},
                },
            )
            self._write_json(handoff_report, {"status": "PASS"})
            self._write_json(contract, {"runtime_strategy": {"runtime_model_artifacts_required": True}})
            self._write_json(
                manifest,
                {
                    "runtime_models": {
                        "efficientnet_lite0.tflite": {
                            "target": str(model_path),
                            "sha256": expected_sha,
                            "semantic_version": "1.0.0",
                        }
                    }
                },
            )

            build_bundle(
                eval_report_path=eval_report,
                handoff_report_path=handoff_report,
                manifest_path=manifest,
                contract_path=contract,
                output_path=output,
            )

            bundle = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(bundle["status_summary"]["runtime_handoff_status"], "PASS")
            self.assertIn("efficientnet_lite0.tflite", bundle["runtime_files"])
            self.assertTrue(bundle["runtime_files"]["efficientnet_lite0.tflite"]["sha256_match"])


if __name__ == "__main__":
    unittest.main()

import json
import tempfile
import unittest
from pathlib import Path

from offline_ml.src.check_production_readiness import check_production_readiness


class ProductionReadinessGateTests(unittest.TestCase):
    def _write_json(self, path: Path, payload: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")

    def test_passes_when_all_gates_green(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            eval_path = root / "real_ready_evaluation_report.json"
            handoff_path = root / "runtime_model_handoff_report.json"
            manifest_path = root / "artifact_manifest.json"
            contract_path = root / "runtime_model_contract.json"

            self._write_json(
                eval_path,
                {
                    "production_gate": {"pass": True},
                    "stress_test": {"gate": {"pass": True}},
                },
            )
            self._write_json(handoff_path, {"status": "PASS"})
            self._write_json(contract_path, {"runtime_strategy": {"runtime_model_artifacts_required": True}})
            self._write_json(
                manifest_path,
                {
                    "runtime_models": {
                        "efficientnet_lite0.tflite": {"sha256": "a" * 64},
                        "mobilefacenet.tflite": {"sha256": "b" * 64},
                    }
                },
            )

            check_production_readiness(
                eval_report_path=eval_path,
                handoff_report_path=handoff_path,
                manifest_path=manifest_path,
                required_models=["efficientnet_lite0.tflite", "mobilefacenet.tflite"],
                contract_path=contract_path,
            )

    def test_fails_when_stress_gate_is_not_pass(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            eval_path = root / "real_ready_evaluation_report.json"
            handoff_path = root / "runtime_model_handoff_report.json"
            manifest_path = root / "artifact_manifest.json"
            contract_path = root / "runtime_model_contract.json"

            self._write_json(
                eval_path,
                {
                    "production_gate": {"pass": True},
                    "stress_test": {"gate": {"pass": False}},
                },
            )
            self._write_json(handoff_path, {"status": "PASS"})
            self._write_json(contract_path, {"runtime_strategy": {"runtime_model_artifacts_required": True}})
            self._write_json(
                manifest_path,
                {
                    "runtime_models": {
                        "efficientnet_lite0.tflite": {"sha256": "a" * 64},
                        "mobilefacenet.tflite": {"sha256": "b" * 64},
                    }
                },
            )

            with self.assertRaises(RuntimeError):
                check_production_readiness(
                    eval_report_path=eval_path,
                    handoff_report_path=handoff_path,
                    manifest_path=manifest_path,
                    required_models=["efficientnet_lite0.tflite", "mobilefacenet.tflite"],
                    contract_path=contract_path,
                )


if __name__ == "__main__":
    unittest.main()

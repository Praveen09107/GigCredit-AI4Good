import json
import tempfile
import unittest
from pathlib import Path

from offline_ml.src.package_runtime_models_for_app import package_runtime_models


class RuntimeModelPackagingTests(unittest.TestCase):
    def _write_bytes(self, path: Path, content: bytes) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    def _contract(self, include_mobilefacenet: bool = True) -> dict:
        artifacts = {
            "efficientnet_lite0.tflite": {
                "model_name": "doc_auth",
                "semantic_version": "1.2.3",
                "input_shape": [1, 224, 224, 3],
                "input_dtype": "float32",
                "output_schema": {"type": "classification"},
                "preprocessing_contract": {"normalize": "imagenet"},
                "postprocessing_thresholds": {"edited_min": 0.65},
                "runtime_compatibility": {
                    "android": "tensorflow_lite>=2.12",
                    "ios": "tensorflowlitec>=2.12",
                },
            }
        }
        if include_mobilefacenet:
            artifacts["mobilefacenet.tflite"] = {
                "model_name": "face_embed",
                "semantic_version": "1.2.3",
                "input_shape": [1, 112, 112, 3],
                "input_dtype": "float32",
                "output_schema": {"type": "embedding", "embedding_size": 128},
                "preprocessing_contract": {"normalize": "face"},
                "postprocessing_thresholds": {"match_min": 0.72},
                "runtime_compatibility": {
                    "android": "tensorflow_lite>=2.12",
                    "ios": "tensorflowlitec>=2.12",
                },
            }
        return {"artifacts": artifacts}

    def test_packages_runtime_models_and_writes_report(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            models_dir = root / "models"
            manifest_path = root / "artifact_manifest.json"
            report_path = root / "runtime_model_handoff_report.json"
            contract_path = root / "runtime_model_contract.json"

            self._write_bytes(models_dir / "efficientnet_lite0.tflite", b"effnet")
            self._write_bytes(models_dir / "mobilefacenet.tflite", b"face")
            contract_path.write_text(json.dumps(self._contract()), encoding="utf-8")

            package_runtime_models(
                contract_path=contract_path,
                models_dir=models_dir,
                manifest_path=manifest_path,
                report_path=report_path,
                required_artifacts=["efficientnet_lite0.tflite", "mobilefacenet.tflite"],
            )

            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertIn("runtime_models", manifest)
            self.assertIn("efficientnet_lite0.tflite", manifest["runtime_models"])
            self.assertIn("mobilefacenet.tflite", manifest["runtime_models"])
            self.assertIn("sha256", manifest["runtime_models"]["efficientnet_lite0.tflite"])

            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "PASS")
            self.assertEqual(report["packaged_count"], 2)

    def test_fails_when_required_artifact_missing_from_contract(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            models_dir = root / "models"
            manifest_path = root / "artifact_manifest.json"
            report_path = root / "runtime_model_handoff_report.json"
            contract_path = root / "runtime_model_contract.json"

            self._write_bytes(models_dir / "efficientnet_lite0.tflite", b"effnet")
            contract_path.write_text(
                json.dumps(self._contract(include_mobilefacenet=False)),
                encoding="utf-8",
            )

            with self.assertRaises(ValueError):
                package_runtime_models(
                    contract_path=contract_path,
                    models_dir=models_dir,
                    manifest_path=manifest_path,
                    report_path=report_path,
                    required_artifacts=["efficientnet_lite0.tflite", "mobilefacenet.tflite"],
                )


if __name__ == "__main__":
    unittest.main()

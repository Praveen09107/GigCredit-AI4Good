import hashlib
import json
import unittest
from pathlib import Path


class ArtifactHandoffSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[2]
        cls.constants_dir = cls.root / 'gigcredit_app' / 'assets' / 'constants'
        cls.scoring_dir = cls.root / 'gigcredit_app' / 'lib' / 'scoring' / 'generated'
        cls.manifest_path = cls.constants_dir / 'artifact_manifest.json'

    @staticmethod
    def _sha256_file(path: Path) -> str:
        hasher = hashlib.sha256()
        with path.open('rb') as file:
            for chunk in iter(lambda: file.read(8192), b''):
                hasher.update(chunk)
        return hasher.hexdigest()

    def test_expected_artifact_files_exist(self):
        expected_scorers = {
            'p1_scorer.dart',
            'p2_scorer.dart',
            'p3_scorer.dart',
            'p4_scorer.dart',
            'p6_scorer.dart',
        }
        expected_constants = {
            'meta_coefficients.json',
            'shap_lookup.json',
            'state_income_anchors.json',
            'feature_means.json',
            'artifact_manifest.json',
        }

        self.assertTrue(self.scoring_dir.exists(), f'Missing scoring dir: {self.scoring_dir}')
        self.assertTrue(self.constants_dir.exists(), f'Missing constants dir: {self.constants_dir}')

        scorer_files = {file.name for file in self.scoring_dir.glob('*.dart')}
        constant_files = {file.name for file in self.constants_dir.glob('*.json')}

        self.assertTrue(expected_scorers.issubset(scorer_files))
        self.assertTrue(expected_constants.issubset(constant_files))

    def test_manifest_checksums_match_artifacts(self):
        self.assertTrue(self.manifest_path.exists(), f'Missing manifest: {self.manifest_path}')
        with self.manifest_path.open('r', encoding='utf-8') as file:
            manifest = json.load(file)

        self.assertIn('generated_at', manifest)
        self.assertIn('artifacts', manifest)

        artifacts = manifest['artifacts']
        self.assertTrue(isinstance(artifacts, dict) and artifacts)

        for artifact_name, artifact_meta in artifacts.items():
            target = Path(artifact_meta['target'])
            expected_sha = artifact_meta['sha256']
            self.assertTrue(target.exists(), f'Missing artifact target for {artifact_name}: {target}')
            actual_sha = self._sha256_file(target)
            self.assertEqual(
                actual_sha,
                expected_sha,
                f'Checksum mismatch for {artifact_name}',
            )


if __name__ == '__main__':
    unittest.main()

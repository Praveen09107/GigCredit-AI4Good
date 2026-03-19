import hashlib
import hmac
import json
from pathlib import Path
import sys
import time
import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings
from app.database import close_client
from app.main import app
from app.models.api import ApiResponse


class BackendContractSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        cls.client.close()
        close_client()

    @staticmethod
    def _signed_headers(body_bytes: bytes, timestamp_ms: int | None = None) -> dict[str, str]:
        timestamp = str(timestamp_ms or int(time.time() * 1000))
        device_id = 'dev-a-smoke-device'
        api_key = settings.api_key

        body_hash = hashlib.sha256(body_bytes).hexdigest()
        message = f'{device_id}{timestamp}{body_hash}'
        signature = hmac.new(
            api_key.encode('utf-8'),
            message.encode('utf-8'),
            hashlib.sha256,
        ).hexdigest()

        return {
            'Content-Type': 'application/json',
            'X-API-Key': api_key,
            'X-Device-ID': device_id,
            'X-Timestamp': timestamp,
            'X-Signature': signature,
            'X-Request-ID': 'smoke-trace-001',
        }

    def _post_signed(self, path: str, payload: dict):
        body_bytes = json.dumps(payload, separators=(',', ':')).encode('utf-8')
        headers = self._signed_headers(body_bytes)
        return self.client.post(path, content=body_bytes, headers=headers)

    def test_root_and_health_routes(self):
        root_response = self.client.get('/')
        self.assertEqual(root_response.status_code, 200)
        self.assertIn('status', root_response.json())

        health_response = self.client.get('/health')
        self.assertEqual(health_response.status_code, 200)
        health_payload = health_response.json()
        self.assertIn('ok', health_payload)
        self.assertIn('db', health_payload)

    def test_verify_pan_rejects_missing_auth_headers(self):
        response = self.client.post('/gov/pan/verify', json={'identifier': 'ABCDE1234F'})
        self.assertEqual(response.status_code, 401)
        payload = response.json()
        self.assertEqual(payload['status'], 'ERROR')
        self.assertIn('error', payload)
        self.assertIn('trace_id', payload)

    def test_verify_pan_accepts_signed_request_and_returns_envelope(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'pan_number': 'ABCDE1234F', 'full_name': 'RAVI KUMAR'},
            error=None,
            trace_id='trace-pan-success',
        )

        with patch('app.routers.verify.gov_service.verify_pan', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/gov/pan/verify', {'identifier': 'ABCDE1234F'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_alias_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'pan_number': 'ABCDE1234F', 'full_name': 'RAVI KUMAR'},
            error=None,
            trace_id='trace-pan-alias-success',
        )

        with patch('app.routers.verify.gov_service.verify_pan', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/pan', {'identifier': 'ABCDE1234F'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_aadhaar_alias_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'aadhaar_last4': '4123', 'full_name': 'RAVI KUMAR'},
            error=None,
            trace_id='trace-aadhaar-alias-success',
        )

        with patch('app.routers.verify.gov_service.verify_aadhaar', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/aadhaar', {'identifier': 'XXXX4123'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_pan_rejects_replay_timestamp(self):
        old_timestamp = int((time.time() - 900) * 1000)
        body_bytes = json.dumps({'identifier': 'ABCDE1234F'}, separators=(',', ':')).encode('utf-8')
        headers = self._signed_headers(body_bytes, timestamp_ms=old_timestamp)

        response = self.client.post('/gov/pan/verify', content=body_bytes, headers=headers)
        self.assertEqual(response.status_code, 401)
        payload = response.json()
        self.assertEqual(payload['status'], 'ERROR')

    def test_report_generate_returns_envelope_with_signed_request(self):
        payload = {
            'request_id': 'report-001',
            'language': 'en',
            'score': 702,
            'pillars': {
                'p1': 0.8,
                'p2': 0.7,
                'p3': 0.6,
                'p4': 0.75,
                'p5': 0.65,
                'p6': 0.7,
                'p7': 0.6,
                'p8': 0.72,
            },
            'shap_factors': [
                {'key': 'income_consistency', 'direction': 'positive', 'value': 0.12},
                {'key': 'emi_ratio', 'direction': 'negative', 'value': -0.08},
            ],
        }

        response = self._post_signed('/report/generate', payload)
        self.assertEqual(response.status_code, 200)
        envelope = response.json()
        self.assertIn(envelope['status'], ['OK', 'ERROR'])
        self.assertIn('data', envelope)
        self.assertIn('trace_id', envelope)


if __name__ == '__main__':
    unittest.main()

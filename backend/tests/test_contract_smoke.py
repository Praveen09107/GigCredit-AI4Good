import hashlib
import hmac
import asyncio
import json
from pathlib import Path
import sys
import time
import unittest
from unittest.mock import AsyncMock, patch
from urllib.parse import urlparse

from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings
from app.database import close_client
from app.main import app
from app.models.api import ApiResponse
from app.models.api import VerifyRequest
from app.services import gov_service


class BackendContractSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        cls.client.close()
        close_client()

    @staticmethod
    def _signed_headers(
        body_bytes: bytes,
        timestamp_ms: int | None = None,
        device_id: str = 'dev-a-smoke-device',
    ) -> dict[str, str]:
        timestamp = str(timestamp_ms or int(time.time() * 1000))
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
        scoped_device_id = f"dev-a-smoke-{path.strip('/').replace('/', '-')}-{time.time_ns()}"
        headers = self._signed_headers(body_bytes, device_id=scoped_device_id)
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
        self.assertIn('indexes_ready', health_payload)

    def test_health_reports_db_true_when_ping_succeeds(self):
        with patch('app.main.ping_database', new=AsyncMock(return_value=True)):
            health_response = self.client.get('/health')

        self.assertEqual(health_response.status_code, 200)
        health_payload = health_response.json()
        self.assertEqual(health_payload['ok'], True)
        self.assertEqual(health_payload['db'], True)
        self.assertIn('indexes_ready', health_payload)

    def test_health_reports_index_ready_when_db_available(self):
        with patch('app.main.ping_database', new=AsyncMock(return_value=True)), patch(
            'app.main.indexes_ready',
            return_value=True,
        ):
            health_response = self.client.get('/health')

        self.assertEqual(health_response.status_code, 200)
        health_payload = health_response.json()
        self.assertEqual(health_payload['ok'], True)
        self.assertEqual(health_payload['db'], True)
        self.assertEqual(health_payload['indexes_ready'], True)

    def test_health_reports_db_false_when_ping_fails(self):
        with patch('app.main.ping_database', new=AsyncMock(return_value=False)):
            health_response = self.client.get('/health')

        self.assertEqual(health_response.status_code, 200)
        health_payload = health_response.json()
        self.assertEqual(health_payload['ok'], True)
        self.assertEqual(health_payload['db'], False)
        self.assertEqual(health_payload['indexes_ready'], False)

    def test_verify_pan_rejects_missing_auth_headers(self):
        response = self.client.post('/gov/pan/verify', json={'identifier': 'ABCDE1234F'})
        self.assertEqual(response.status_code, 401)
        payload = response.json()
        self.assertEqual(payload['status'], 'ERROR')
        self.assertIn('error', payload)
        self.assertIn('trace_id', payload)

    def test_verify_pan_rejects_invalid_signature(self):
        body_bytes = json.dumps({'identifier': 'ABCDE1234F'}, separators=(',', ':')).encode('utf-8')
        headers = self._signed_headers(body_bytes)
        headers['X-Signature'] = 'not-a-valid-signature'

        response = self.client.post('/verify/pan', content=body_bytes, headers=headers)
        self.assertEqual(response.status_code, 401)
        payload = response.json()
        self.assertEqual(payload['status'], 'ERROR')

    def test_verify_pan_rate_limit_enforced_returns_429(self):
        body_bytes = json.dumps({'identifier': 'ABCDE1234F'}, separators=(',', ':')).encode('utf-8')
        headers = self._signed_headers(body_bytes)

        with patch('app.auth.check_rate_limit', return_value=False):
            response = self.client.post('/verify/pan', content=body_bytes, headers=headers)

        self.assertEqual(response.status_code, 429)
        payload = response.json()
        self.assertEqual(payload['status'], 'ERROR')

    def test_mongo_uri_uses_non_localhost_endpoint(self):
        parsed = urlparse(settings.mongo_uri)
        host = (parsed.hostname or '').lower()
        self.assertNotIn('<db_password>', settings.mongo_uri)
        self.assertNotEqual(host, 'localhost')

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

    def test_verify_gst_alias_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'gst_identifier': '29ABCDE1234F1Z5', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-gst-alias-success',
        )

        with patch('app.routers.verify.gov_service.verify_gst', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/gst', {'identifier': '29ABCDE1234F1Z5'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_typed_utility_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'utility_type': 'ELECTRICITY', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-utility-typed-success',
        )

        with patch('app.routers.verify.gov_service.verify_utility_bill', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/utility/electricity', {'identifier': 'ignored_by_typed_route'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_svanidhi_canonical_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'application_id': 'SVAN123456', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-svanidhi-success',
        )

        with patch('app.routers.verify.gov_service.verify_svanidhi', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/svanidhi', {'application_id': 'SVAN123456'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_svanidhi_canonical_endpoint_accepts_identifier_payload(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'application_id': 'SVAN123456', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-svanidhi-identifier-success',
        )

        with patch('app.routers.verify.gov_service.verify_svanidhi', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/svanidhi', {'identifier': 'SVAN123456'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_fssai_canonical_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'license_number': '12345678901234', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-fssai-success',
        )

        with patch('app.routers.verify.gov_service.verify_fssai', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/fssai', {'license_number': '12345678901234'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_fssai_canonical_endpoint_accepts_identifier_payload(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'license_number': '12345678901234', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-fssai-identifier-success',
        )

        with patch('app.routers.verify.gov_service.verify_fssai', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/fssai', {'identifier': '12345678901234'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_skill_canonical_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'certificate_id': 'SKILL-998877', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-skill-success',
        )

        with patch('app.routers.verify.gov_service.verify_skill_certificate', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/skill', {'certificate_id': 'SKILL-998877'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_skill_canonical_endpoint_accepts_identifier_payload(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'certificate_id': 'SKILL-998877', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-skill-identifier-success',
        )

        with patch('app.routers.verify.gov_service.verify_skill_certificate', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/skill', {'identifier': 'SKILL-998877'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_svanidhi_legacy_alias_accepts_application_id_payload(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'application_id': 'SVAN123456', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-svanidhi-legacy-success',
        )

        with patch('app.routers.verify.gov_service.verify_svanidhi', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/api/gov/svanidhi/verify', {'application_id': 'SVAN123456'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_fssai_legacy_alias_accepts_license_number_payload(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'license_number': '12345678901234', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-fssai-legacy-success',
        )

        with patch('app.routers.verify.gov_service.verify_fssai', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/api/gov/fssai/verify', {'license_number': '12345678901234'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_skill_legacy_alias_accepts_certificate_id_payload(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'certificate_id': 'SKILL-998877', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-skill-legacy-success',
        )

        with patch('app.routers.verify.gov_service.verify_skill_certificate', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/api/gov/skill/verify', {'certificate_id': 'SKILL-998877'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_pmsym_canonical_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'pmsym_ref': 'PMSYM12345', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-pmsym-success',
        )

        with patch('app.routers.verify.gov_service.verify_pmsym', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/pmsym', {'identifier': 'PMSYM12345'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_pmjjby_canonical_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'pmjjby_ref': 'PMJJBY5566', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-pmjjby-success',
        )

        with patch('app.routers.verify.gov_service.verify_pmjjby', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/pmjjby', {'identifier': 'PMJJBY5566'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_udyam_canonical_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'udyam_ref': 'UDYAM-7788', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-udyam-success',
        )

        with patch('app.routers.verify.gov_service.verify_udyam', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/udyam', {'identifier': 'UDYAM-7788'})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'FOUND')
        self.assertIn('data', payload)
        self.assertIn('trace_id', payload)

    def test_verify_ppf_canonical_endpoint_accepts_signed_request(self):
        mocked = ApiResponse(
            status='FOUND',
            data={'ppf_account': 'PPF00123456', 'status': 'ACTIVE'},
            error=None,
            trace_id='trace-ppf-success',
        )

        with patch('app.routers.verify.gov_service.verify_ppf', new=AsyncMock(return_value=mocked)):
            response = self._post_signed('/verify/ppf', {'identifier': 'PPF00123456'})

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
                'p8': 0.55,
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

    def test_report_generate_keeps_score_and_pillars_immutable_in_response(self):
        payload = {
            'request_id': 'report-immutability-001',
            'language': 'en',
            'score': 711,
            'pillars': {
                'p1': 0.81,
                'p2': 0.62,
                'p3': 0.57,
                'p4': 0.74,
                'p5': 0.66,
                'p6': 0.78,
                'p7': 0.59,
                'p8': 0.64,
            },
            'shap_factors': [
                {'key': 'bank_verified', 'direction': 'positive', 'value': 0.16},
            ],
        }

        response = self._post_signed('/report/generate', payload)
        self.assertEqual(response.status_code, 200)
        envelope = response.json()
        self.assertIn(envelope['status'], ['OK', 'ERROR'])

        data = envelope.get('data', {})
        self.assertEqual(data.get('score'), payload['score'])
        self.assertEqual(data.get('pillars'), payload['pillars'])
        self.assertIn('language', data)
        self.assertIn('explanation', data)
        self.assertIn('suggestions', data)
        self.assertIsInstance(data.get('suggestions'), list)

    def test_report_generate_falls_back_unsupported_language_to_en(self):
        payload = {
            'request_id': 'report-language-fallback-001',
            'language': 'bn',
            'score': 640,
            'pillars': {
                'p1': 0.71,
                'p2': 0.52,
                'p3': 0.57,
                'p4': 0.68,
                'p5': 0.66,
                'p6': 0.58,
                'p7': 0.59,
                'p8': 0.64,
            },
            'shap_factors': [],
        }

        response = self._post_signed('/report/generate', payload)
        self.assertEqual(response.status_code, 200)
        envelope = response.json()
        self.assertIn(envelope['status'], ['OK', 'ERROR'])
        data = envelope.get('data', {})
        self.assertEqual(data.get('language'), 'en')

    def test_report_generate_rejects_missing_required_pillar(self):
        payload = {
            'request_id': 'report-invalid-pillars-001',
            'language': 'en',
            'score': 690,
            'pillars': {
                'p1': 0.71,
                'p2': 0.52,
                'p3': 0.57,
                'p4': 0.68,
                'p5': 0.66,
                'p6': 0.58,
                'p7': 0.59,
            },
            'shap_factors': [],
        }

        response = self._post_signed('/report/generate', payload)
        self.assertIn(response.status_code, [400, 422])

    def test_report_store_persists_request_and_returns_ok(self):
        users_collection = AsyncMock()
        work_profiles_collection = AsyncMock()
        reports_collection = AsyncMock()
        score_reports_collection = AsyncMock()
        report_log_collection = AsyncMock()

        def fake_get_collection(name: str):
            if name == 'users':
                return users_collection
            if name == 'work_profiles':
                return work_profiles_collection
            if name == 'reports':
                return reports_collection
            if name == 'score_reports_db':
                return score_reports_collection
            if name == 'report_api_logs':
                return report_log_collection
            raise AssertionError(f'Unexpected collection requested: {name}')

        with patch('app.routers.report.get_collection', side_effect=fake_get_collection):
            payload = {
                'request_id': 'store-req-001',
                'language': 'en',
                'score': 705,
                'pillars': {
                    'p1': 0.8,
                    'p2': 0.7,
                    'p3': 0.6,
                    'p4': 0.65,
                    'p5': 0.6,
                    'p6': 0.7,
                    'p7': 0.55,
                    'p8': 0.5,
                },
                'shap_factors': [],
            }
            response = self._post_signed('/report/store', payload)

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body['status'], 'OK')
        self.assertEqual(body['data']['stored'], True)

        self.assertEqual(users_collection.update_one.await_count, 1)
        self.assertEqual(work_profiles_collection.update_one.await_count, 1)
        self.assertEqual(reports_collection.insert_one.await_count, 1)
        self.assertEqual(score_reports_collection.insert_one.await_count, 1)
        self.assertEqual(report_log_collection.insert_one.await_count, 1)

        stored_doc = score_reports_collection.insert_one.await_args.args[0]
        self.assertEqual(stored_doc['request_id'], 'store-req-001')
        self.assertEqual(stored_doc['score'], 705)
        self.assertEqual(stored_doc['language'], 'en')
        self.assertIn('trace_id', stored_doc)

    def test_verify_service_persists_verification_event_log(self):
        pan_collection = AsyncMock()
        pan_collection.find_one = AsyncMock(
            return_value={
                'pan_number': 'ABCDE1234F',
                'full_name': 'RAVI KUMAR',
                'status': 'ACTIVE',
            }
        )
        verification_log_collection = AsyncMock()

        def fake_get_collection(name: str):
            if name == 'pan_records':
                return pan_collection
            if name == 'verification_api_logs':
                return verification_log_collection
            raise AssertionError(f'Unexpected collection requested: {name}')

        with patch('app.services.gov_service.get_collection', side_effect=fake_get_collection):
            result = asyncio.run(
                gov_service.verify_pan(
                    VerifyRequest(identifier='ABCDE1234F'),
                    trace_id='trace-verify-persist-001',
                )
            )

        self.assertEqual(result.status, 'FOUND')
        self.assertEqual(verification_log_collection.insert_one.await_count, 1)
        audit_doc = verification_log_collection.insert_one.await_args.args[0]
        self.assertEqual(audit_doc['verification_type'], 'pan')
        self.assertEqual(audit_doc['status'], 'FOUND')
        self.assertEqual(audit_doc['trace_id'], 'trace-verify-persist-001')


if __name__ == '__main__':
    unittest.main()

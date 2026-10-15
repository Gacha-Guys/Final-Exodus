import unittest
from unittest.mock import patch
import pymysql
from fastapi.testclient import TestClient
from app import app
from rate_limit import RegistrationLimiter


class RegistrationLimitTests(unittest.TestCase):
    def test_threshold_and_window(self):
        now = [0]
        limiter = RegistrationLimiter(2, 10, lambda: now[0])
        self.assertEqual(limiter.retry_after('one'), 0)
        self.assertEqual(limiter.retry_after('one'), 0)
        self.assertEqual(limiter.retry_after('one'), 10)
        self.assertEqual(limiter.retry_after('another'), 0)
        now[0] = 10
        self.assertEqual(limiter.retry_after('one'), 0)

    def test_api_limit_precedes_validation_and_hashing(self):
        with patch('app.registration_limiter', RegistrationLimiter(1, 60)), patch('app.create_account') as create:
            client = TestClient(app)
            self.assertEqual(client.post('/accounts', json={}).status_code, 422)
            blocked = client.post('/accounts', json={})
            self.assertEqual(blocked.status_code, 429)
            self.assertIn('Retry-After', blocked.headers)
            create.assert_not_called()

    def test_password_never_echoed_in_field_error(self):
        with patch('app.registration_limiter', RegistrationLimiter()):
            result = TestClient(app).post('/accounts', json=dict(email='bad', display_name='Tyler', password='secret'))
        self.assertEqual(result.status_code, 422)
        self.assertNotIn('secret', result.text)
        self.assertNotIn('input', result.json()['detail'][0])

    def test_database_failure_is_safe_and_retry_remains_possible(self):
        payload = dict(email='student@example.com', display_name='Tyler', password='a long enough password')
        with patch('app.registration_limiter', RegistrationLimiter()), patch('app.create_account', side_effect=pymysql.err.OperationalError(2003, 'private database details')):
            client = TestClient(app)
            for _ in range(2):
                result = client.post('/accounts', json=payload)
                self.assertEqual(result.status_code, 503)
                self.assertNotIn('private database details', result.text)

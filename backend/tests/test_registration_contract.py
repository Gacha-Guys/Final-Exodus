"""Registration contract tests: no server, credentials or database required."""
import unittest
from unittest.mock import patch
import pymysql
from fastapi.testclient import TestClient
from pydantic import ValidationError
from src.accounts import app, Registration
from src.rate_limit import RegistrationLimiter


class RegistrationContractTests(unittest.TestCase):
    def setUp(self):
        limiter = patch('src.accounts.registration_limiter', RegistrationLimiter())
        limiter.start()
        self.addCleanup(limiter.stop)
        self.client = TestClient(app)
        self.payload = dict(email='player@example.com', display_name='Player', password='a long demo password')

    def test_password_length_boundaries(self):
        for length in (12, 128):
            with self.subTest(length=length):
                request = Registration(**(self.payload | {'password': 'x' * length}))
                self.assertEqual(len(request.password.get_secret_value()), length)
        for length in (11, 129):
            with self.subTest(length=length), self.assertRaises(ValidationError):
                Registration(**(self.payload | {'password': 'x' * length}))

    def test_password_whitespace_is_preserved(self):
        secret = '  long password  '
        self.assertEqual(Registration(**(self.payload | {'password': secret})).password.get_secret_value(), secret)

    def test_missing_fields_rejected_before_storage(self):
        with patch('src.accounts.create_account') as create:
            for field in self.payload:
                with self.subTest(field=field):
                    payload = self.payload.copy()
                    del payload[field]
                    self.assertEqual(self.client.post('/accounts', json=payload).status_code, 422)
            create.assert_not_called()

    def test_client_cannot_assign_admin_role(self):
        with patch('src.accounts.create_account') as create:
            result = self.client.post('/accounts', json=self.payload | {'role': 'admin'})
        self.assertEqual(result.status_code, 422)
        create.assert_not_called()

    def test_duplicate_email_has_conflict_response(self):
        with patch('src.accounts.create_account', side_effect=pymysql.err.IntegrityError(1062, 'private SQL details')):
            result = self.client.post('/accounts', json=self.payload)
        self.assertEqual(result.status_code, 409)
        self.assertEqual(result.json(), {'detail': 'Email already registered'})

    def test_other_constraint_failure_is_not_reported_as_duplicate(self):
        with patch('src.accounts.create_account', side_effect=pymysql.err.IntegrityError(1452, 'private SQL details')):
            result = self.client.post('/accounts', json=self.payload)
        self.assertEqual(result.status_code, 503)
        self.assertEqual(result.json(), {'detail': 'Account creation unavailable'})

    def test_health_is_available_without_database(self):
        with patch('src.accounts.connect', side_effect=AssertionError('health must not contact database')):
            result = self.client.get('/health')
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.json()['status'], 'running')

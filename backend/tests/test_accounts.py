import unittest
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
from pydantic import ValidationError
from src.rate_limit import RegistrationLimiter
from src.accounts import Registration, create_account, password_hash, app


class AccountTests(unittest.TestCase):
    def setUp(self):
        limiter = patch('src.accounts.registration_limiter', RegistrationLimiter())
        limiter.start()
        self.addCleanup(limiter.stop)

    def request(self, **changes):
        data = dict(email='Student@Example.com', display_name=' Tyler ', password='a sufficiently long password')
        return Registration(**(data | changes))

    def connection(self):
        connection = Mock()
        cursor = Mock(lastrowid=42)
        connection.cursor.return_value.__enter__ = Mock(return_value=cursor)
        connection.cursor.return_value.__exit__ = Mock(return_value=False)
        return connection, cursor

    def test_validation(self):
        for changes in [dict(email='bad'), dict(display_name='  '), dict(password='short'), dict(password='x'*129), dict(role='admin')]:
            with self.subTest(changes=changes), self.assertRaises(ValidationError):
                self.request(**changes)

    def test_hash_and_successful_transaction(self):
        connection, cursor = self.connection()
        account = create_account(self.request(), lambda: connection)
        values = cursor.execute.call_args_list[0].args[1]
        self.assertEqual(values[:2], ('student@example.com', 'Tyler'))
        self.assertTrue(password_hash.verify('a sufficiently long password', values[2]))
        self.assertFalse(password_hash.verify('wrong password', values[2]))
        self.assertTrue(values[2].startswith('$argon2id$'))
        self.assertNotEqual(values[2], password_hash.hash('a sufficiently long password'))
        self.assertEqual(account.id, 42)
        connection.commit.assert_called_once()
        connection.rollback.assert_not_called()
        connection.close.assert_called_once()

    def test_registration_uses_shared_connection_by_default(self):
        connection, _ = self.connection()
        with patch('src.database.connect', return_value=connection) as connect:
            account = create_account(self.request())
        connect.assert_called_once_with()
        self.assertEqual(account.id, 42)
        connection.commit.assert_called_once()
        connection.close.assert_called_once()

    def test_wallet_failure_rolls_back_account(self):
        connection, cursor = self.connection()
        cursor.execute.side_effect = [1, RuntimeError('wallet failure')]
        with self.assertRaises(RuntimeError):
            create_account(self.request(), lambda: connection)
        connection.rollback.assert_called_once()
        connection.commit.assert_not_called()
        connection.close.assert_called_once()

    def test_api_never_returns_password(self):
        client = TestClient(app)
        with patch('src.accounts.create_account', return_value=dict(id=42, email='student@example.com', display_name='Tyler')):
            response = client.post('/accounts', json=dict(email='student@example.com', display_name='Tyler', password='a sufficiently long password'))
        self.assertEqual(response.status_code, 201)
        self.assertEqual(set(response.json()), {'id', 'email', 'display_name'})

    def test_invalid_api_request_rejected_before_database(self):
        with patch('src.accounts.create_account') as create:
            response = TestClient(app).post('/accounts', json=dict(email='bad', display_name='Tyler', password='short'))
        self.assertEqual(response.status_code, 422)
        create.assert_not_called()

if __name__ == '__main__':
    unittest.main()

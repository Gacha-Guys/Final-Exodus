"""Opt-in tests against the isolated local MySQL demo, never Aiven.

Run: python -m pytest demo/test_demo_integration.py -q
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import HTTPException
from fastapi.testclient import TestClient
import pytest

load_dotenv(Path(__file__).parents[1] / '.env.demo', override=True)
from src import demo, demo_accounts
from src.demo_store import transaction
from src.rate_limit import RegistrationLimiter

PASSWORD = 'LocalDemoOnly!2026'


@pytest.fixture(autouse=True)
def isolated_test_accounts(monkeypatch):
    monkeypatch.setattr(demo, 'limiter', RegistrationLimiter(limit=200))
    created = []
    yield created
    if not created:
        return
    with transaction() as cursor:
        for email in created:
            cursor.execute('DELETE FROM Users WHERE email=%s', (email,))


def register(created, client=None):
    client = client or TestClient(demo.app)
    email = f'demo-{uuid4().hex}@example.com'
    created.append(email)
    body = dict(email=email, display_name='Demo Tester', password=PASSWORD, dob='2000-01-01')
    response = client.post('/accounts', json=body)
    assert response.status_code == 201, response.text
    return client, body, response.json()


def signed_in(created):
    client, body, account = register(created)
    response = client.post('/sessions', json=dict(email=body['email'], password=PASSWORD))
    assert response.status_code == 200
    token = response.json()['access_token']
    return client, {'Authorization': 'Bearer ' + token}, account


def start(client, headers):
    response = client.post('/battles', headers=headers, json={'request_id': str(uuid4())})
    assert response.status_code == 200, response.text
    return response.json()


def test_registration_balances_hash_duplicate_and_safe_validation(isolated_test_accounts):
    client, body, account = register(isolated_test_accounts)
    assert account['level'] == 1 and account['free_currency'] == account['paid_currency'] == 0
    assert 'password' not in account and 'dob' not in account
    with transaction() as cursor:
        cursor.execute('SELECT password FROM Users WHERE id=%s', (account['id'],))
        stored = cursor.fetchone()['password']
        assert stored != PASSWORD and demo_accounts.password_hash.verify(PASSWORD, stored)
        cursor.execute('SELECT COUNT(*) AS n FROM Currency WHERE u_id=%s', (account['id'],))
        assert cursor.fetchone()['n'] == 2
    assert client.post('/accounts', json=body).status_code == 409
    bad = body | {'email': 'bad', 'password': 'sensitive-short', 'dob': '2999-01-01'}
    result = client.post('/accounts', json=bad)
    assert result.status_code == 422 and 'sensitive-short' not in result.text
    assert client.post('/accounts', json=body | {'role': 'admin'}).status_code == 422


def test_registration_rollback(isolated_test_accounts, monkeypatch):
    email = f'demo-{uuid4().hex}@example.com'; isolated_test_accounts.append(email)
    def fail(*args): raise HTTPException(503, 'Simulated read failure')
    monkeypatch.setattr(demo_accounts, 'profile', fail)
    result = TestClient(demo.app).post('/accounts', json=dict(email=email, display_name='Rollback', password=PASSWORD, dob='2000-01-01'))
    assert result.status_code == 503
    with transaction() as cursor:
        cursor.execute('SELECT id FROM Users WHERE email=%s', (email,))
        assert cursor.fetchone() is None


def test_concurrent_registration_creates_one_account(isolated_test_accounts):
    email = f'demo-{uuid4().hex}@example.com'; isolated_test_accounts.append(email)
    body = dict(email=email, display_name='Concurrent', password=PASSWORD, dob='2000-01-01')
    with ThreadPoolExecutor(2) as pool:
        codes = list(pool.map(lambda _: TestClient(demo.app).post('/accounts', json=body).status_code, range(2)))
    assert sorted(codes) == [201, 409]


def test_login_name_logout_and_session_hash(isolated_test_accounts):
    client, headers, account = signed_in(isolated_test_accounts)
    assert client.get('/me').status_code == 401
    assert client.get('/me', headers={'Authorization': 'Bearer fake-invalid-token-long'}).status_code == 401
    with transaction() as cursor:
        cursor.execute('SELECT token_hash FROM DemoSessions WHERE u_id=%s', (account['id'],))
        assert cursor.fetchone()['token_hash'] == hashlib.sha256(headers['Authorization'][7:].encode()).hexdigest()
    result = client.patch('/me', headers=headers, json={'display_name': '  Tyler Demo  '})
    assert result.json()['display_name'] == 'Tyler Demo'
    assert client.patch('/me', headers=headers, json={'display_name': ' '}).status_code == 422
    assert client.patch('/me', headers=headers, json={'display_name': 'Other', 'id': 2}).status_code == 422
    assert client.get('/me', headers=headers).json()['display_name'] == 'Tyler Demo'
    assert client.delete('/sessions/current', headers=headers).status_code == 204
    assert client.get('/me', headers=headers).status_code == 401


def test_wrong_password_expired_session_and_rate_limit(isolated_test_accounts, monkeypatch):
    client, headers, account = signed_in(isolated_test_accounts)
    with transaction() as cursor:
        cursor.execute('UPDATE DemoSessions SET expires_at=%s WHERE u_id=%s', (datetime.now()-timedelta(days=1), account['id']))
    assert client.get('/me', headers=headers).status_code == 401
    assert client.post('/sessions', json={'email':account['email'], 'password':'wrong-password'}).status_code == 401
    monkeypatch.setattr(demo, 'limiter', RegistrationLimiter(limit=1))
    assert client.post('/sessions', json={'email':account['email'], 'password':'wrong-password'}).status_code == 401
    assert client.post('/sessions', json={'email':account['email'], 'password':'wrong-password'}).status_code == 429


def test_battle_account_isolation_and_forged_damage(isolated_test_accounts):
    client, headers, account = signed_in(isolated_test_accounts)
    other, other_headers, _ = signed_in(isolated_test_accounts)
    assert other.get('/battles/current', headers=other_headers).json() is None
    state = start(client, headers)
    body = dict(request_id=str(uuid4()), actor=0, version=0)
    path = f"/battles/{state['id']}/actions"
    assert other.post(path, headers=other_headers, json=body).status_code == 404
    assert client.post(path, headers=headers, json=body | {'damage':10000}).status_code == 422
    assert client.post(path, headers=headers, json=body | {'actor':True}).status_code == 422
    assert client.post(path, headers=headers, json=body | {'actor':3}).status_code == 422
    assert client.get('/battles/current', headers=headers).json()['enemy']['hp'] == 100


def test_action_retry_stale_version_and_complete_battle(isolated_test_accounts):
    client, headers, _ = signed_in(isolated_test_accounts)
    state = start(client, headers); path = f"/battles/{state['id']}/actions"
    body = dict(request_id=str(uuid4()), actor=0, version=0)
    first = client.post(path, headers=headers, json=body)
    assert first.status_code == 200 and first.json()['enemy']['hp'] == 82
    assert client.post(path, headers=headers, json=body).json() == first.json()
    assert client.post(path, headers=headers, json=body | {'actor':1}).status_code == 409
    assert client.post(path, headers=headers, json=body | {'request_id':str(uuid4())}).status_code == 409
    state = first.json()
    while state['status'] == 'active':
        response = client.post(path, headers=headers, json=dict(request_id=str(uuid4()), actor=state['version']%3, version=state['version']))
        assert response.status_code == 200
        state = response.json()
    assert state['status'] == 'won' and state['enemy']['hp'] == 0
    assert client.get('/me', headers=headers).json()['completed_battles'] == 1
    assert client.get('/me', headers=headers).json()['free_currency'] == 0
    assert client.post(path, headers=headers, json=dict(request_id=str(uuid4()),actor=0,version=state['version'])).status_code == 409
    assert client.get('/battles/current', headers=headers).json() == state


def test_concurrent_start_and_duplicate_attack(isolated_test_accounts):
    client, headers, _ = signed_in(isolated_test_accounts)
    with ThreadPoolExecutor(2) as pool:
        states = list(pool.map(lambda _: start(TestClient(demo.app),headers), range(2)))
    assert states[0]['id'] == states[1]['id']
    state = states[0]
    body = dict(request_id=str(uuid4()), actor=0, version=0)
    path = f"/battles/{state['id']}/actions"
    with ThreadPoolExecutor(2) as pool:
        responses = list(pool.map(lambda _: TestClient(demo.app).post(path,headers=headers,json=body), range(2)))
    assert all(r.status_code == 200 for r in responses)
    assert responses[0].json() == responses[1].json()
    assert client.get('/battles/current',headers=headers).json()['version'] == 1


def test_concurrent_different_actions_do_not_double_advance(isolated_test_accounts):
    _, headers, _ = signed_in(isolated_test_accounts)
    state = start(TestClient(demo.app),headers)
    def act(actor):
        return TestClient(demo.app).post(f"/battles/{state['id']}/actions",headers=headers,json=dict(request_id=str(uuid4()),actor=actor,version=0))
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(act,range(2)))
    assert sorted(r.status_code for r in results) == [200,409]


def test_remote_database_guard_and_database_outage(monkeypatch):
    client=TestClient(demo.app)
    monkeypatch.setenv('FINAL_EXODUS_DB_HOST','remote.example.com')
    assert client.get('/health').status_code == 503
    monkeypatch.setenv('FINAL_EXODUS_DB_HOST','127.0.0.1')
    monkeypatch.setenv('FINAL_EXODUS_DB_PORT','1')
    result=client.get('/health')
    assert result.status_code == 503 and 'password' not in result.text.lower()


def test_action_and_retry_record_roll_back_together(isolated_test_accounts, monkeypatch):
    from contextlib import contextmanager
    import pymysql
    from src import demo_combat
    client, headers, _ = signed_in(isolated_test_accounts)
    saved = start(client, headers)
    body = dict(request_id=str(uuid4()), actor=0, version=0)
    path = f"/battles/{saved['id']}/actions"
    @contextmanager
    def fail_journal():
        with transaction() as cursor:
            execute = cursor.execute
            def interrupted(sql, args=None):
                if sql.startswith('INSERT INTO DemoActions'):
                    raise pymysql.err.OperationalError(2013, 'Simulated interrupted write')
                return execute(sql, args)
            cursor.execute = interrupted
            yield cursor
    monkeypatch.setattr(demo_combat, 'transaction', fail_journal)
    assert client.post(path, headers=headers, json=body).status_code == 503
    assert client.get('/battles/current', headers=headers).json() == saved
    monkeypatch.setattr(demo_combat, 'transaction', transaction)
    response = client.post(path, headers=headers, json=body)
    assert response.status_code == 200 and response.json()['version'] == 1


def test_missing_balance_is_an_error_not_a_successful_zero(isolated_test_accounts):
    client, headers, account = signed_in(isolated_test_accounts)
    with transaction() as cursor:
        cursor.execute("DELETE FROM Currency WHERE u_id=%s AND Type='paid'", (account['id'],))
    assert client.get('/me', headers=headers).status_code == 503

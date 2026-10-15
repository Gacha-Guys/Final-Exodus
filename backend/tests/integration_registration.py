"""Opt-in real development DB check; creates and removes one unique identity."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from pathlib import Path
import sys
import uuid
from unittest.mock import patch
from dotenv import dotenv_values
import pymysql
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.accounts import create_account, password_hash
from src.main import app
from fastapi.testclient import TestClient
from src.rate_limit import RegistrationLimiter


def database(values):
    return pymysql.connect(host=values['FINAL_EXODUS_DB_HOST'], port=int(values['FINAL_EXODUS_DB_PORT']),
        user=values['FINAL_EXODUS_DB_USER'], password=values['FINAL_EXODUS_DB_PASSWORD'],
        database=values.get('FINAL_EXODUS_DB', 'defaultdb'), charset='utf8mb4',
        ssl_ca=values['FINAL_EXODUS_DB_SSL_CA'], ssl_verify_cert=True, ssl_verify_identity=True,
        connect_timeout=5, read_timeout=10, write_timeout=10)


def run(settings, admin):
    for key in ('FINAL_EXODUS_DB_HOST', 'FINAL_EXODUS_DB_PORT', 'FINAL_EXODUS_DB'):
        if settings.get(key) != admin.get(key):
            raise ValueError('App and cleanup settings must target the same development database')
    email = 'integration-' + uuid.uuid4().hex + '@example.com'
    payload = dict(email=email, display_name='Integration test', password='temporary integration password')
    barrier = Barrier(2)
    cleanup = database(admin)
    try:
        def register(_):
            with TestClient(app) as client:
                barrier.wait(timeout=10)
                return client.post('/accounts', json=payload).status_code
        # Override only connection creation; execute actual transaction and HTTP handlers.
        def create(request):
            return create_account(request, lambda: database(settings))
        with patch('src.accounts.create_account', side_effect=create), patch('src.accounts.registration_limiter', RegistrationLimiter()), ThreadPoolExecutor(max_workers=2) as pool:
            statuses = list(pool.map(register, range(2)))
        assert sorted(statuses) == [201, 409], 'Expected success and duplicate rejection'
        with cleanup.cursor() as cursor:
            cursor.execute('SELECT a.password_hash,w.currency FROM accounts a JOIN wallets w ON a.id=w.account_id WHERE a.email=%s', (email,))
            rows = cursor.fetchall()
            assert len(rows) == 1 and rows[0][1] == 0
            assert password_hash.verify(payload['password'], rows[0][0])
        print('PASS: concurrent registration, one account/wallet, verified password hash')
    finally:
        with cleanup.cursor() as cursor:
            cursor.execute('DELETE FROM accounts WHERE email=%s', (email,))
        cleanup.commit()
        cleanup.close()
        print('Temporary test identity removed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app-env', required=True)
    parser.add_argument('--cleanup-env', required=True)
    args = parser.parse_args()
    try:
        run(dotenv_values(args.app_env), dotenv_values(args.cleanup_env))
    except Exception as error:
        print('Integration failed (' + type(error).__name__ + '); check development database configuration/cleanup permissions')
        raise SystemExit(1) from None

"""Rehearse persistence across two actual API processes on a separate test port."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from uuid import uuid4

from dotenv import load_dotenv
import httpx
import pymysql

BACKEND = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND / '.env.demo', override=True)
sys.path.insert(0, str(BACKEND))
from src.local_test_target import require_local_test_database
require_local_test_database()
email = f'restart-{uuid4().hex}@example.com'
process = None
report = {}


def boot(log):
    process = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'src.main:app', '--host', '127.0.0.1', '--port', '8008', '--no-proxy-headers'], cwd=BACKEND, stdout=log, stderr=log)
    for attempt in range(100):
        if process.poll() is not None:
            raise RuntimeError('Test API could not start. Is port 8008 already occupied?')
        try:
            if httpx.get('http://127.0.0.1:8008/health', timeout=0.5).status_code == 200:
                return process
        except httpx.HTTPError:
            pass
        time.sleep(0.05)
    process.terminate(); process.wait(timeout=5)
    raise RuntimeError('Test API did not become ready')


try:
    with tempfile.TemporaryFile() as log, httpx.Client(base_url='http://127.0.0.1:8008', timeout=4) as client:
        process = boot(log)
        result = client.post('/accounts', json=dict(email=email, display_name='Restart-'+email.split('@')[0][-12:], password='RestartDemo!2026', dob='2000-01-01'))
        assert result.status_code == 201
        token = client.post('/sessions', json=dict(name='Restart-'+email.split('@')[0][-12:], password='RestartDemo!2026')).json()['access_token']
        headers = {'Authorization': 'Bearer ' + token}
        battle = client.post('/battles', headers=headers, json={'request_id':str(uuid4())}).json()
        action = dict(request_id=str(uuid4()), actor=0, version=0)
        path = f"/battles/{battle['id']}/actions"
        saved = client.post(path, headers=headers, json=action).json()
        assert saved['enemy']['hp'] == 82 and saved['version'] == 1
        first_pid = process.pid
        process.terminate(); process.wait(timeout=5)
        process = boot(log)
        assert first_pid != process.pid
        assert client.get('/me', headers=headers).json()['display_name'] == 'Restart-'+email.split('@')[0][-12:]
        assert client.get('/battles/current', headers=headers).json() == saved
        assert client.post(path, headers=headers, json=action).json() == saved
        assert client.get('/battles/current', headers=headers).json()['version'] == 1
        assert client.delete('/sessions/current', headers=headers).status_code == 204
        assert client.get('/me', headers=headers).status_code == 401
        report = {'api_restarted': True, 'session_survived_restart': True,
                  'battle_survived_restart': True, 'retry_did_not_repeat_damage': True,
                  'logout_revoked_session': True}
        print(json.dumps(report, indent=2))
finally:
    if process and process.poll() is None:
        process.terminate(); process.wait(timeout=5)
    connection = pymysql.connect(host='127.0.0.1', port=int(os.environ['FINAL_EXODUS_DB_PORT']),
        user=os.environ['FINAL_EXODUS_DB_USER'], password=os.environ['FINAL_EXODUS_DB_PASSWORD'],
        database='final_exodus_tyler_demo', autocommit=True)
    with connection.cursor() as cursor:
        cursor.execute('DELETE FROM Users WHERE email=%s', (email,))
    connection.close()
    if report:
        artifact_dir = Path(os.getenv('FINAL_EXODUS_TEST_ARTIFACT_DIR', str(BACKEND.parent/'docs/review')))
        artifact_dir.mkdir(parents=True, exist_ok=True)
        (artifact_dir/'restart-result.json').write_text(json.dumps(report, indent=2)+'\n')

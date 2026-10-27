"""Rehearse Google game UI with a simulated provider, never a real Google account."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from uuid import uuid4

from dotenv import load_dotenv
import httpx

BACKEND = Path(__file__).resolve().parents[1]
load_dotenv(BACKEND / '.env.demo', override=True)
sys.path.insert(0, str(BACKEND))
from src.local_test_target import require_local_test_database
require_local_test_database()
from src.demo_store import transaction


def serve():
    import uvicorn
    from src import main as demo, demo_google
    os.environ['FINAL_EXODUS_GOOGLE_CLIENT_ID'] = 'simulated.apps.googleusercontent.com'
    os.environ['FINAL_EXODUS_GOOGLE_CLIENT_SECRET'] = 'simulated-client-secret'
    def simulated_identity(code, flow):
        if code != 'simulated-google-code':
            raise ValueError('Only the simulated test code is accepted')
        return dict(subject=os.environ['FINAL_EXODUS_TEST_SUBJECT'],email=os.environ['FINAL_EXODUS_TEST_EMAIL'],display_name='Simulated Google Player')
    demo_google.verified_identity = simulated_identity
    uvicorn.run(demo.app,host='127.0.0.1',port=8009,access_log=False)


def main():
    parser = __import__('argparse').ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    args = parser.parse_args()
    environment = os.environ | {'FINAL_EXODUS_TEST_EMAIL':f'google-ui-{uuid4().hex}@example.com',
                                 'FINAL_EXODUS_TEST_SUBJECT':uuid4().hex,
                                 'FINAL_EXODUS_API_ORIGIN':'http://127.0.0.1:8009'}
    process = None
    try:
        with tempfile.TemporaryFile() as log:
            process = subprocess.Popen([sys.executable,__file__,'--serve'],env=environment,stdout=log,stderr=log)
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError('Simulated test API did not start')
                try:
                    if httpx.get('http://127.0.0.1:8009/health',timeout=0.5).status_code == 200:
                        break
                except httpx.HTTPError:
                    pass
                time.sleep(0.05)
            else:
                raise RuntimeError('Simulated test API not ready')
            subprocess.run([str(args.godot),'--path',str(BACKEND.parent/'frontend'),
                            '--script','res://tests/google_sign_in.gd'],env=environment,check=True,timeout=45)
    finally:
        if process and process.poll() is None:
            process.terminate(); process.wait(timeout=5)
        with transaction() as cursor:
            cursor.execute('DELETE FROM Users WHERE email=%s',(environment['FINAL_EXODUS_TEST_EMAIL'],))


if __name__ == '__main__':
    if '--serve' in sys.argv:
        serve()
    else:
        main()

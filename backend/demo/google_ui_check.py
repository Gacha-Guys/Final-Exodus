"""Rehearse Google game UI with a simulated provider, never a real Google account."""
import argparse
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
sys.path.insert(0, str(BACKEND))
from src.demo_store import transaction
from src.local_test_target import require_local_test_database

GODOT_ENV_KEYS = (
    'HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'SYSTEMROOT', 'WINDIR',
    'TEMP', 'TMP', 'TMPDIR', 'PATH', 'LANG', 'LC_ALL', 'DISPLAY', 'WAYLAND_DISPLAY',
    'XAUTHORITY', 'XDG_RUNTIME_DIR', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME',
    'XDG_CACHE_HOME', 'FINAL_EXODUS_TEST_ARTIFACT_DIR',
)
TEST_ORIGIN = 'http://127.0.0.1:8009'


def configure_test_database():
    load_dotenv(BACKEND / '.env.demo', override=True)
    require_local_test_database()


def godot_environment():
    environment = {key: os.environ[key] for key in GODOT_ENV_KEYS if key in os.environ}
    environment['FINAL_EXODUS_API_ORIGIN'] = TEST_ORIGIN
    return environment


def godot_executable(parser, path):
    try:
        executable = path.resolve(strict=True)
    except (OSError, RuntimeError):
        parser.error(f'--godot path could not be resolved: {path}')
    if not executable.is_file() or not os.access(executable, os.X_OK):
        parser.error(f'--godot must point to an executable file: {executable}')
    if os.name == 'nt' and executable.suffix.lower() != '.exe':
        parser.error(f'--godot must point to a .exe file on Windows: {executable}')
    return executable


def serve():
    configure_test_database()
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--headless', action='store_true', help='Run without opening the game window')
    args = parser.parse_args()
    godot = godot_executable(parser, args.godot)
    configure_test_database()
    environment = os.environ | {
        'FINAL_EXODUS_TEST_EMAIL': f'google-ui-{uuid4().hex}@example.com',
        'FINAL_EXODUS_TEST_SUBJECT': uuid4().hex,
    }
    process = None
    try:
        with tempfile.TemporaryFile() as log:
            process = subprocess.Popen([sys.executable,__file__,'--serve'],env=environment,stdout=log,stderr=log)
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError('Simulated test API did not start')
                try:
                    if httpx.get(TEST_ORIGIN + '/health', timeout=0.5, trust_env=False).status_code == 200:
                        break
                except httpx.HTTPError:
                    pass
                time.sleep(0.05)
            else:
                raise RuntimeError('Simulated test API not ready')
            display_args = ['--headless'] if args.headless else []
            subprocess.run(
                [str(godot), *display_args, '--path', str(BACKEND.parent / 'frontend'),
                 '--script', 'res://tests/google_sign_in.gd'],
                env=godot_environment(), check=True, timeout=45, shell=False,
            )
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

"""Run the simulated Google API for the Godot UI walkthrough on loopback port 8009."""
import argparse
import os
from pathlib import Path
import sys
from uuid import uuid4

from dotenv import load_dotenv
import uvicorn

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))
from src.game_store import transaction
from src.local_test_target import require_local_test_database


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    load_dotenv(BACKEND / '.env.demo', override=True)
    require_local_test_database()

    from src import google_auth, main as server

    os.environ['FINAL_EXODUS_GOOGLE_CLIENT_ID'] = 'simulated.apps.googleusercontent.com'
    os.environ['FINAL_EXODUS_GOOGLE_CLIENT_SECRET'] = 'simulated-client-secret'
    email = f'google-ui-{uuid4().hex}@example.com'
    subject = uuid4().hex

    def simulated_identity(code, flow):
        if code != 'simulated-google-code':
            raise ValueError('Only the simulated test code is accepted')
        return dict(subject=subject, email=email, display_name='Simulated Google Player')

    google_auth.verified_identity = simulated_identity
    try:
        uvicorn.run(server.app, host='127.0.0.1', port=8009,
                    proxy_headers=False, access_log=False)
    except KeyboardInterrupt:
        pass
    finally:
        with transaction() as cursor:
            cursor.execute('DELETE FROM Users WHERE email=%s', (email,))


if __name__ == '__main__':
    main()

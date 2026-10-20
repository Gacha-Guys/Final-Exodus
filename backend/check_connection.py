"""Read-only connection check; reads configuration from an explicitly supplied env file."""
import argparse
from dotenv import load_dotenv
from src.database import connect

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", required=True)
    args = parser.parse_args()
    load_dotenv(args.env_file, override=True)
    try:
        connection = connect()
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1 FROM accounts LIMIT 1")
                cursor.fetchone()
                cursor.execute("SELECT 1 FROM wallets LIMIT 1")
                cursor.fetchone()
            print("Connected: accounts and wallets are readable.")
        finally:
            connection.close()
    except Exception as error:
        # Database exceptions can contain private connection details.
        print("Connection check failed (" + type(error).__name__ + "). Check service power, settings, certificate and access.")
        raise SystemExit(1) from None
